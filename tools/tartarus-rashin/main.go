package main

import (
	"bufio"
	"bytes"
	"context"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

//go:embed web/*
var dashboardFS embed.FS

const (
	defaultPort     = 3610
	defaultEndpoint = "http://127.0.0.1:8081/v1"
	defaultModel    = "gemma-4-E4B-it-qat-UD-Q4_K_XL"
	maxHistory      = 60
)

type Config struct {
	Enabled        bool   `json:"enabled"`
	Endpoint       string `json:"endpoint"`
	Model          string `json:"model"`
	VaultPath      string `json:"vaultPath"`
	ListenPort     int    `json:"listenPort"`
	ExternalEnable bool   `json:"externalEnabled"`
}

type HistoryEntry struct {
	At       string `json:"at"`
	Question string `json:"question"`
	Answer   string `json:"answer"`
	Model    string `json:"model"`
}

type ConversationTurn struct {
	Role    string
	Content string
}

// chatSession is deliberately kept in memory and scoped to one websocket.
// The durable history is still written separately, but short follow-ups such
// as "sí" or "hazlo" need the immediately preceding exchange to be useful.
type chatSession struct {
	mu        sync.Mutex
	turns     []ConversationTurn
	sessionID string
	resumed   bool
}

const (
	maxConversationTurns = 8
	maxConversationChars = 14000
)

func (c *chatSession) snapshot() []ConversationTurn {
	c.mu.Lock()
	defer c.mu.Unlock()
	return append([]ConversationTurn(nil), c.turns...)
}

func (c *chatSession) append(question, answer string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.turns = append(c.turns,
		ConversationTurn{Role: "Usuario", Content: question},
		ConversationTurn{Role: "Rashin", Content: answer},
	)
	if len(c.turns) > maxConversationTurns {
		c.turns = c.turns[len(c.turns)-maxConversationTurns:]
	}
}

func (c *chatSession) id() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.sessionID
}

func (c *chatSession) set(id string, turns []ConversationTurn) {
	c.mu.Lock()
	c.sessionID = id
	c.resumed = false
	c.turns = append([]ConversationTurn(nil), turns...)
	if len(c.turns) > maxConversationTurns {
		c.turns = c.turns[len(c.turns)-maxConversationTurns:]
	}
	c.mu.Unlock()
}

func (c *chatSession) markResumed() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.resumed {
		return false
	}
	c.resumed = true
	return true
}

type ChatEvent struct {
	Type      string        `json:"type"`
	State     string        `json:"state,omitempty"`
	Text      string        `json:"text,omitempty"`
	Title     string        `json:"title,omitempty"`
	ToolID    string        `json:"toolId,omitempty"`
	ToolState string        `json:"toolState,omitempty"`
	RequestID string        `json:"requestId,omitempty"`
	Options   []PermOption  `json:"options,omitempty"`
	Answer    string        `json:"answer,omitempty"`
	Entry     *HistoryEntry `json:"entry,omitempty"`
	Error     string        `json:"error,omitempty"`
	Model     string        `json:"model,omitempty"`
	Warning   string        `json:"warning,omitempty"`
	Actions   []Action      `json:"actions,omitempty"`
	QueueID   string        `json:"queueId,omitempty"`
	Position  int           `json:"position,omitempty"`
	SessionID string        `json:"sessionId,omitempty"`
	ClientID  string        `json:"clientId,omitempty"`
}

type Action struct {
	Kind  string `json:"kind"`
	Label string `json:"label"`
	Value string `json:"value"`
}

type PermOption struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Kind string `json:"kind,omitempty"`
}

type Server struct {
	cfg            Config
	store          *RashinStore
	defaultSession string

	mu              sync.Mutex
	activeCancel    context.CancelFunc
	activeRequest   string
	activeQueueID   string
	activeSessionID string
	history         []HistoryEntry
	permissions     map[string]chan bool
	clients         map[*websocket.Conn]struct{}
	lastQuestion    string
	queued          []*queuedSocketRequest
}

type queuedSocketRequest struct {
	client       *websocket.Conn
	session      *chatSession
	question     string
	forceHermes  bool
	sessionID    string
	queueID      string
	modelProfile string
	fastMode     bool
	attachments  []string
	clientID     string
}

func main() {
	cfg := loadConfig()
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "status":
			writeJSON(os.Stdout, statusPayload(cfg))
			return
		case "index":
			if err := runIndex(cfg); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return
		case "serve":
			// The user unit invokes the daemon with this explicit subcommand.
		}
	}

	server := &Server{
		cfg:         cfg,
		history:     loadHistory(),
		permissions: map[string]chan bool{},
		clients:     map[*websocket.Conn]struct{}{},
	}
	store, err := OpenRashinStore(databasePath())
	if err != nil {
		fmt.Fprintln(os.Stderr, "tartarus-rashin: no se pudo abrir la base local:", err)
		os.Exit(1)
	}
	server.store = store
	defer store.Close()
	if err := store.MigrateHistory(server.history); err != nil {
		fmt.Fprintln(os.Stderr, "tartarus-rashin: no se pudo migrar el historial:", err)
	}
	if err := store.InterruptRunningQueue(); err != nil {
		fmt.Fprintln(os.Stderr, "tartarus-rashin: no se pudo recuperar la cola:", err)
	}
	server.defaultSession, err = store.EnsureDefaults(cfg.Model)
	if err != nil {
		fmt.Fprintln(os.Stderr, "tartarus-rashin: no se pudo crear la sesión inicial:", err)
		os.Exit(1)
	}
	if err := server.serve(); err != nil {
		fmt.Fprintln(os.Stderr, "tartarus-rashin:", err)
		os.Exit(1)
	}
}

func homeDir() string {
	if value := os.Getenv("HOME"); value != "" {
		return value
	}
	value, _ := os.UserHomeDir()
	return value
}

func stateDir() string {
	if value := os.Getenv("XDG_STATE_HOME"); value != "" {
		return filepath.Join(value, "tartarus-shell")
	}
	return filepath.Join(homeDir(), ".local", "state", "tartarus-shell")
}

func configPath() string   { return filepath.Join(stateDir(), "rashin.json") }
func historyPath() string  { return filepath.Join(stateDir(), "rashin-asks.jsonl") }
func databasePath() string { return filepath.Join(stateDir(), "rashin.db") }

func loadConfig() Config {
	cfg := Config{
		Endpoint:   defaultEndpoint,
		Model:      defaultModel,
		VaultPath:  filepath.Join(homeDir(), ".local", "share", "tartarus", "rashin"),
		ListenPort: defaultPort,
	}
	data, err := os.ReadFile(configPath())
	if err == nil {
		_ = json.Unmarshal(data, &cfg)
	}
	if cfg.Endpoint == "" {
		cfg.Endpoint = defaultEndpoint
	}
	if cfg.Model == "" {
		cfg.Model = defaultModel
	}
	if cfg.VaultPath == "" {
		cfg.VaultPath = filepath.Join(homeDir(), ".local", "share", "tartarus", "rashin")
	}
	if cfg.ListenPort == 0 {
		cfg.ListenPort = defaultPort
	}
	return cfg
}

func loadHistory() []HistoryEntry {
	data, err := os.ReadFile(historyPath())
	if err != nil {
		return nil
	}
	var entries []HistoryEntry
	for _, line := range strings.Split(string(data), "\n") {
		var entry HistoryEntry
		if json.Unmarshal([]byte(line), &entry) == nil && entry.Question != "" && entry.Answer != "" {
			entries = append(entries, entry)
		}
	}
	if len(entries) > maxHistory {
		entries = entries[len(entries)-maxHistory:]
	}
	return entries
}

func (s *Server) serve() error {
	if err := os.MkdirAll(s.cfg.VaultPath, 0o700); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(s.cfg.VaultPath, "memory"), 0o700); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(s.cfg.VaultPath, "journal"), 0o700); err != nil {
		return err
	}

	mux := http.NewServeMux()
	static, err := fs.Sub(dashboardFS, "web")
	if err != nil {
		return err
	}
	mux.Handle("/", http.FileServer(http.FS(static)))
	mux.HandleFunc("GET /api/ping", func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, "ok") })
	mux.HandleFunc("GET /api/status", s.handleStatus)
	mux.HandleFunc("GET /api/workspace", s.handleWorkspace)
	mux.HandleFunc("GET /api/projects", s.handleProjects)
	mux.HandleFunc("POST /api/projects", s.handleCreateProject)
	mux.HandleFunc("POST /api/projects/{id}/update", s.handleUpdateProject)
	mux.HandleFunc("POST /api/projects/{id}/delete", s.handleDeleteProject)
	mux.HandleFunc("PATCH /api/projects/{id}", s.handleUpdateProject)
	mux.HandleFunc("DELETE /api/projects/{id}", s.handleDeleteProject)
	mux.HandleFunc("GET /api/sessions", s.handleSessions)
	mux.HandleFunc("POST /api/sessions", s.handleCreateSession)
	mux.HandleFunc("GET /api/sessions/{id}/messages", s.handleSessionMessages)
	mux.HandleFunc("POST /api/sessions/{id}/update", s.handleUpdateSession)
	mux.HandleFunc("POST /api/sessions/{id}/delete", s.handleDeleteSession)
	mux.HandleFunc("PATCH /api/sessions/{id}", s.handleUpdateSession)
	mux.HandleFunc("DELETE /api/sessions/{id}", s.handleDeleteSession)
	mux.HandleFunc("GET /api/queue", s.handleQueue)
	mux.HandleFunc("POST /api/queue/{id}/cancel", s.handleCancelQueueItem)
	mux.HandleFunc("POST /api/queue/{id}/resume", s.handleResumeQueueItem)
	mux.HandleFunc("GET /api/models", s.handleModels)
	mux.HandleFunc("GET /api/models/downloads", s.handleModelDownloads)
	mux.HandleFunc("POST /api/models/download", s.handleModelDownload)
	mux.HandleFunc("POST /api/models/delete", s.handleModelDelete)
	mux.HandleFunc("POST /api/models/refresh", s.handleModelsRefresh)
	mux.HandleFunc("POST /api/models/activate", s.handleModelActivate)
	mux.HandleFunc("POST /api/attachments", s.handleAttachmentUpload)
	mux.HandleFunc("GET /api/memory/candidates", s.handleMemoryCandidates)
	mux.HandleFunc("POST /api/memory/candidates", s.handleCreateMemoryCandidate)
	mux.HandleFunc("POST /api/memory/candidates/{id}", s.handleUpdateMemoryCandidate)
	mux.HandleFunc("GET /api/profile", s.handleUserProfile)
	mux.HandleFunc("POST /api/profile", s.handleSaveUserProfile)
	mux.HandleFunc("GET /api/vitals", s.handleVitals)
	mux.HandleFunc("GET /api/vault", s.handleVault)
	mux.HandleFunc("GET /api/vault/file", s.handleVaultFile)
	mux.HandleFunc("POST /api/index", s.handleIndex)
	mux.HandleFunc("GET /api/agents", s.handleAgents)
	mux.HandleFunc("POST /api/agents/wire", s.handleWire)
	mux.HandleFunc("POST /api/agents/unwire", s.handleUnwire)
	mux.HandleFunc("GET /api/hermes/skills", s.handleSkills)
	mux.HandleFunc("GET /api/hermes/memory", s.handleMemory)
	mux.HandleFunc("GET /api/tools", handleTools)
	mux.HandleFunc("GET /api/about", s.handleAbout)
	mux.HandleFunc("GET /api/ask/recent", s.handleRecent)
	mux.HandleFunc("POST /api/ask", s.handleAsk)
	mux.HandleFunc("POST /api/ask/resume", s.handleResume)
	mux.HandleFunc("POST /api/ask/cancel", s.handleCancel)
	mux.HandleFunc("POST /api/perm", s.handlePermission)
	mux.HandleFunc("POST /api/setup", s.handleSetup)
	mux.HandleFunc("GET /ws/chat", s.handleChatSocket)

	server := &http.Server{
		Addr:              fmt.Sprintf("127.0.0.1:%d", s.cfg.ListenPort),
		Handler:           withLocalOnly(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	fmt.Printf("tartarus-rashin: dashboard on http://%s\n", server.Addr)
	return server.ListenAndServe()
}

func withLocalOnly(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host := r.Host
		if i := strings.LastIndex(host, ":"); i > -1 {
			host = host[:i]
		}
		if host != "127.0.0.1" && host != "localhost" && host != "[::1]" && host != "::1" {
			http.Error(w, "localhost only", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w io.Writer, value any) {
	_ = json.NewEncoder(w).Encode(value)
}

func writeHTTPJSON(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	writeJSON(w, value)
}

func statusPayload(cfg Config) map[string]any {
	hermes := findLocalBinary("hermes")
	providerAvailable := probeProvider(cfg.Endpoint)
	return map[string]any{
		"enabled":           cfg.Enabled,
		"running":           true,
		"localOnly":         true,
		"endpoint":          cfg.Endpoint,
		"model":             cfg.Model,
		"modelLabel":        modelLabel(cfg.Model),
		"providerAvailable": providerAvailable,
		"vault":             cfg.VaultPath,
		"hermes": map[string]any{
			"installed":  hermes != "",
			"configured": hermes != "" && hermesConfigExists(),
			"binary":     hermes,
		},
		"port": cfg.ListenPort,
	}
}

func findLocalBinary(name string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	for _, path := range []string{
		filepath.Join(homeDir(), ".local", "bin", name),
		filepath.Join(homeDir(), ".cargo", "bin", name),
	} {
		if info, err := os.Stat(path); err == nil && !info.IsDir() && info.Mode()&0o111 != 0 {
			return path
		}
	}
	return ""
}

func probeProvider(endpoint string) bool {
	endpoint = strings.TrimRight(endpoint, "/")
	if endpoint == "" {
		return false
	}
	request, err := http.NewRequest(http.MethodGet, endpoint+"/models", nil)
	if err != nil {
		return false
	}
	client := &http.Client{Timeout: 900 * time.Millisecond}
	response, err := client.Do(request)
	if err != nil {
		return false
	}
	defer response.Body.Close()
	return response.StatusCode >= 200 && response.StatusCode < 300
}

func modelLabel(model string) string {
	lower := strings.ToLower(model)
	label := model
	if strings.Contains(lower, "gemma-4-e4b") {
		label = "Gemma 4 E4B"
		if strings.Contains(lower, "qat") {
			label += " QAT"
		}
		if strings.Contains(lower, "ud-q4_k_xl") {
			label += " · UD-Q4_K_XL"
		}
		return label
	}
	if strings.Contains(lower, "qwen3.5") && strings.Contains(lower, "9b") {
		label = "Qwen 3.5 9B"
	}
	if strings.Contains(lower, "q5_k") {
		label += " · Q5_K Medium"
	}
	return label
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	writeHTTPJSON(w, statusPayload(s.cfg))
}

func (s *Server) handleVitals(w http.ResponseWriter, r *http.Request) {
	memory := map[string]any{}
	if data, err := os.ReadFile("/proc/meminfo"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			fields := strings.Fields(line)
			if len(fields) >= 2 && (fields[0] == "MemTotal:" || fields[0] == "MemAvailable:") {
				memory[strings.TrimSuffix(fields[0], ":")] = fields[1]
			}
		}
	}
	load := ""
	if data, err := os.ReadFile("/proc/loadavg"); err == nil {
		load = strings.TrimSpace(string(data))
	}
	var stat syscall.Statfs_t
	disk := map[string]any{}
	if syscall.Statfs(homeDir(), &stat) == nil {
		total := stat.Blocks * uint64(stat.Bsize)
		free := stat.Bavail * uint64(stat.Bsize)
		disk = map[string]any{"total": total, "free": free, "used": total - free}
	}
	writeHTTPJSON(w, map[string]any{
		"cpu":     map[string]any{"cores": runtime.NumCPU(), "load": load},
		"memory":  memory,
		"disk":    disk,
		"updated": time.Now().Format(time.RFC3339),
	})
}

func (s *Server) handleVault(w http.ResponseWriter, r *http.Request) {
	type item struct {
		Path string `json:"path"`
		Size int64  `json:"size"`
		Dir  bool   `json:"dir"`
	}
	items := []item{}
	_ = filepath.Walk(s.cfg.VaultPath, func(path string, info os.FileInfo, err error) error {
		if err != nil || path == s.cfg.VaultPath {
			return nil
		}
		rel, _ := filepath.Rel(s.cfg.VaultPath, path)
		if strings.HasPrefix(rel, ".") && strings.Contains(rel, string(filepath.Separator)+".") {
			return nil
		}
		items = append(items, item{Path: filepath.ToSlash(rel), Size: info.Size(), Dir: info.IsDir()})
		return nil
	})
	writeHTTPJSON(w, map[string]any{"root": s.cfg.VaultPath, "files": items})
}

func (s *Server) safeVaultPath(value string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", errors.New("missing vault path")
	}
	path := filepath.Join(s.cfg.VaultPath, filepath.Clean(value))
	rel, err := filepath.Rel(s.cfg.VaultPath, path)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", errors.New("path outside vault")
	}
	return path, nil
}

func (s *Server) handleVaultFile(w http.ResponseWriter, r *http.Request) {
	path, err := s.safeVaultPath(r.URL.Query().Get("p"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	data, err := os.ReadFile(path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = w.Write(data)
}

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if err := runIndex(s.cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true, "updated": time.Now().Format(time.RFC3339)})
}

func runIndex(cfg Config) error {
	root := os.Getenv("TARTARUS_SHELL_ROOT")
	if root == "" {
		root = filepath.Join(homeDir(), ".config", "quickshell", "tartarus-shell")
	}
	script := filepath.Join(root, "scripts", "rashin-index.py")
	if _, err := os.Stat(script); err != nil {
		return fmt.Errorf("indexer not found: %w", err)
	}
	cmd := exec.Command("python3", script, "--vault", cfg.VaultPath, "--config-root", root)
	cmd.Env = append(os.Environ(), "PYTHONUNBUFFERED=1")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("index: %s: %w", strings.TrimSpace(string(output)), err)
	}
	return nil
}

func (s *Server) handleAgents(w http.ResponseWriter, r *http.Request) {
	type agent struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		Binary string `json:"binary,omitempty"`
		Wired  bool   `json:"wired"`
	}
	items := []agent{}
	for _, candidate := range []struct{ id, name, binary string }{
		{"hermes", "Hermes", "hermes"},
		{"codex", "Codex", "codex"},
		{"claude", "Claude", "claude"},
		{"opencode", "OpenCode", "opencode"},
	} {
		binary := findLocalBinary(candidate.binary)
		items = append(items, agent{ID: candidate.id, Name: candidate.name, Binary: binary, Wired: agentWired(candidate.id)})
	}
	writeHTTPJSON(w, items)
}

func agentWired(id string) bool {
	path := filepath.Join(homeDir(), ".config", "tartarus-shell", "agents", id+".md")
	_, err := os.Stat(path)
	return err == nil
}

func (s *Server) handleWire(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}
	if err := writeAgentPointer(id); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func (s *Server) handleUnwire(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if !regexp.MustCompile(`^[a-z0-9_-]+$`).MatchString(id) {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	path := filepath.Join(homeDir(), ".config", "tartarus-shell", "agents", id+".md")
	_ = os.Remove(path)
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func writeAgentPointer(id string) error {
	if !regexp.MustCompile(`^[a-z0-9_-]+$`).MatchString(id) {
		return errors.New("invalid agent id")
	}
	root := filepath.Join(homeDir(), ".config", "tartarus-shell", "agents")
	if err := os.MkdirAll(root, 0o700); err != nil {
		return err
	}
	content := "<!-- tartarus-rashin:begin -->\n## Tartarus Rashin\n\nRead the local Rashin vault at `~/.local/share/tartarus/rashin/AGENTS.md` before exploring this machine. It contains the generated map and reload instructions.\n<!-- tartarus-rashin:end -->\n"
	return os.WriteFile(filepath.Join(root, id+".md"), []byte(content), 0o600)
}

func (s *Server) handleSkills(w http.ResponseWriter, r *http.Request) {
	type skill struct {
		Name   string `json:"name"`
		Path   string `json:"path"`
		Origin string `json:"origin"`
	}
	items := []skill{}
	for _, root := range []struct{ path, origin string }{
		{filepath.Join(homeDir(), ".hermes", "skills"), "Hermes"},
		{filepath.Join(homeDir(), ".codex", "skills"), "Codex"},
		{filepath.Join(homeDir(), ".local", "share", "tartarus", "rashin", "skills"), "Tartarus"},
	} {
		entries, _ := os.ReadDir(root.path)
		for _, entry := range entries {
			if entry.IsDir() {
				items = append(items, skill{Name: entry.Name(), Path: filepath.Join(root.path, entry.Name()), Origin: root.origin})
			}
		}
	}
	writeHTTPJSON(w, map[string]any{"skills": items})
}

func (s *Server) handleMemory(w http.ResponseWriter, r *http.Request) {
	result := map[string]any{"vault": s.cfg.VaultPath, "files": []string{}, "hermes": hermesMemoryPath()}
	files := []string{}
	_ = filepath.Walk(filepath.Join(s.cfg.VaultPath, "memory"), func(path string, info os.FileInfo, err error) error {
		if err == nil && info != nil && !info.IsDir() {
			rel, _ := filepath.Rel(s.cfg.VaultPath, path)
			files = append(files, filepath.ToSlash(rel))
		}
		return nil
	})
	result["files"] = files
	writeHTTPJSON(w, result)
}

func hermesMemoryPath() string { return filepath.Join(homeDir(), ".hermes", "memories") }

func handleTools(w http.ResponseWriter, r *http.Request) {
	// Keep the dashboard honest: the CLI tool list is the source of truth for
	// the Hermes lane, while the local fallback remains visible when Hermes is
	// not installed yet.
	tools := []map[string]any{
		{"id": "system_query", "title": "Estado del sistema", "mode": "read-only"},
		{"id": "read_file", "title": "Leer archivo de la bóveda", "mode": "read-only"},
		{"id": "list_dir", "title": "Listar carpeta de la bóveda", "mode": "read-only"},
		{"id": "search_code", "title": "Buscar en código", "mode": "read-only"},
		{"id": "write_file", "title": "Escribir archivo", "mode": "permission"},
		{"id": "run_command", "title": "Ejecutar comando", "mode": "permission"},
	}
	if hermes := findLocalBinary("hermes"); hermes != "" {
		if output, err := exec.Command(hermes, "tools", "list").Output(); err == nil {
			parsed := parseHermesTools(string(output))
			if len(parsed) > 0 {
				tools = parsed
			}
		}
	}
	writeHTTPJSON(w, map[string]any{"tools": tools})
}

func parseHermesTools(output string) []map[string]any {
	pattern := regexp.MustCompile(`^\s*([✓✗])\s+(enabled|disabled)\s+(\S+)\s+(.+)$`)
	tools := []map[string]any{}
	for _, line := range strings.Split(output, "\n") {
		match := pattern.FindStringSubmatch(line)
		if len(match) != 5 {
			continue
		}
		mode := "disabled"
		if match[2] == "enabled" {
			mode = "enabled"
		}
		tools = append(tools, map[string]any{
			"id":    match[3],
			"title": strings.TrimSpace(match[4]),
			"mode":  mode,
		})
	}
	return tools
}

func (s *Server) handleAbout(w http.ResponseWriter, r *http.Request) {
	writeHTTPJSON(w, map[string]any{
		"name":        "Tartarus Rashin",
		"description": "Asistente local para consultar y entender el sistema.",
		"privacy":     "El daemon escucha únicamente en localhost; el proveedor local es el predeterminado.",
		"model":       modelLabel(s.cfg.Model),
	})
}

func (s *Server) handleRecent(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	entries := append([]HistoryEntry(nil), s.history...)
	s.mu.Unlock()
	writeHTTPJSON(w, entries)
}

func (s *Server) handleCancel(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	cancel := s.activeCancel
	s.mu.Unlock()
	if cancel != nil {
		cancel()
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handlePermission(w http.ResponseWriter, r *http.Request) {
	requestID := r.URL.Query().Get("id")
	allow := r.URL.Query().Get("action") == "allow"
	s.mu.Lock()
	waiter := s.permissions[requestID]
	delete(s.permissions, requestID)
	s.mu.Unlock()
	if waiter == nil {
		http.Error(w, "permission not found", http.StatusNotFound)
		return
	}
	waiter <- allow
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func (s *Server) handleSetup(w http.ResponseWriter, r *http.Request) {
	if _, err := exec.LookPath("kitty"); err != nil {
		http.Error(w, "kitty is required to run the interactive Hermes setup", http.StatusNotFound)
		return
	}
	command := `set -e; export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"; if ! command -v hermes >/dev/null 2>&1; then f=$(mktemp); curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$f"; bash "$f"; rm -f "$f"; fi; hermes setup; printf '\nSetup terminado. Pulsa Enter para cerrar.'; read -r`
	cmd := exec.Command("kitty", "--class", "tartarus-rashin-setup", "-e", "bash", "-lc", command)
	if err := cmd.Start(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true, "pid": cmd.Process.Pid})
}

func (s *Server) handleAsk(w http.ResponseWriter, r *http.Request) {
	question := strings.TrimSpace(r.URL.Query().Get("q"))
	if question == "" {
		http.Error(w, "missing q", http.StatusBadRequest)
		return
	}
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unavailable", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/x-ndjson; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	ctx, cancel := context.WithCancel(r.Context())
	if !s.beginTurn(cancel) {
		cancel()
		http.Error(w, "another Rashin turn is already running", http.StatusConflict)
		return
	}
	defer s.endTurn()
	previous := s.historySnapshot()
	sessionID := r.URL.Query().Get("sessionId")
	if sessionID == "" {
		sessionID = s.defaultSession
	}
	if s.store != nil {
		s.maybeMemoryCandidate(question, "chat")
		_, _ = s.store.AddMessage(sessionID, "user", question, s.cfg.Model, "completed", splitIDs(r.URL.Query().Get("attachments")))
	}
	s.mu.Lock()
	s.lastQuestion = question
	s.mu.Unlock()

	emit := func(event ChatEvent) {
		_ = json.NewEncoder(w).Encode(event)
		flusher.Flush()
		s.broadcast(event)
	}
	emit(ChatEvent{Type: "connected", Model: modelLabel(s.cfg.Model)})
	answer, err := s.runTurn(ctx, question, emit, r.URL.Query().Get("mode") == "hermes", previous, r.URL.Query().Get("fast") == "1" || r.URL.Query().Get("fast") == "true", splitIDs(r.URL.Query().Get("attachments")))
	if err != nil {
		if s.store != nil {
			_, _ = s.store.AddMessage(sessionID, "assistant", err.Error(), s.cfg.Model, "failed", nil)
		}
		emit(ChatEvent{Type: "error", Error: err.Error()})
		return
	}
	entry := HistoryEntry{At: time.Now().Format(time.RFC3339), Question: question, Answer: answer, Model: s.cfg.Model}
	s.saveHistory(entry)
	if s.store != nil {
		_, _ = s.store.AddMessage(sessionID, "assistant", answer, s.cfg.Model, "completed", nil)
	}
	emit(ChatEvent{Type: "done", Answer: answer, Entry: &entry, Model: modelLabel(s.cfg.Model), Actions: extractActions(answer)})
}

func (s *Server) handleResume(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	question := s.lastQuestion
	s.mu.Unlock()
	if question == "" {
		http.Error(w, "no hay una consulta cancelada para reanudar", http.StatusNotFound)
		return
	}
	copyRequest := r.Clone(r.Context())
	copyRequest.URL = &url.URL{Path: "/api/ask", RawQuery: url.Values{"q": []string{question}}.Encode()}
	s.handleAsk(w, copyRequest)
}

func (s *Server) beginTurn(cancel context.CancelFunc) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.activeCancel != nil {
		return false
	}
	s.activeCancel = cancel
	s.activeRequest = strconv.FormatInt(time.Now().UnixNano(), 10)
	return true
}

func (s *Server) endTurn() {
	s.finishSocketTurn()
}

func (s *Server) saveHistory(entry HistoryEntry) {
	s.mu.Lock()
	s.history = append(s.history, entry)
	if len(s.history) > maxHistory {
		s.history = s.history[len(s.history)-maxHistory:]
	}
	entries := append([]HistoryEntry(nil), s.history...)
	s.mu.Unlock()
	_ = os.MkdirAll(stateDir(), 0o700)
	var buffer bytes.Buffer
	for _, item := range entries {
		data, _ := json.Marshal(item)
		buffer.Write(data)
		buffer.WriteByte('\n')
	}
	_ = os.WriteFile(historyPath(), buffer.Bytes(), 0o600)
}

func (s *Server) historySnapshot() []ConversationTurn {
	s.mu.Lock()
	defer s.mu.Unlock()
	start := len(s.history) - maxConversationTurns/2
	if start < 0 {
		start = 0
	}
	turns := make([]ConversationTurn, 0, (len(s.history)-start)*2)
	for _, entry := range s.history[start:] {
		turns = append(turns,
			ConversationTurn{Role: "Usuario", Content: entry.Question},
			ConversationTurn{Role: "Rashin", Content: entry.Answer},
		)
	}
	return turns
}

func conversationPrompt(question string, previous []ConversationTurn) string {
	question = strings.TrimSpace(question)
	if len(previous) == 0 {
		return question
	}
	var b strings.Builder
	b.WriteString("CONVERSACIÓN PREVIA DE ESTA SESIÓN (úsala para resolver referencias como ‘sí’, ‘eso’ o ‘hazlo’):\n")
	used := 0
	for _, turn := range previous {
		content := strings.TrimSpace(turn.Content)
		if content == "" {
			continue
		}
		if len(content) > 3500 {
			content = content[:3500] + "…"
		}
		line := turn.Role + ": " + content + "\n"
		if used+len(line) > maxConversationChars {
			break
		}
		b.WriteString(line)
		used += len(line)
	}
	b.WriteString("\nMENSAJE ACTUAL DEL USUARIO:\n")
	b.WriteString(question)
	return b.String()
}

func (s *Server) runTurn(ctx context.Context, question string, emit func(ChatEvent), forceHermes bool, previous []ConversationTurn, fastMode bool, attachments []string) (string, error) {
	question = s.withAttachmentContext(question, attachments)
	if forceHermes || needsSession(question, previous) || needsWebTools(question) {
		if findLocalBinary("hermes") == "" {
			return "", errors.New("esta consulta requiere Hermes; abre Rashin y pulsa Configurar Hermes local")
		}
		prompt := conversationPrompt(question, previous)
		if needsWebTools(question) {
			prompt = webToolsPrompt(prompt)
			emit(ChatEvent{Type: "working", Text: "Buscando fuentes con Hermes…"})
		}
		return s.runHermes(ctx, prompt, emit)
	}
	return s.runFast(ctx, question, previous, emit, fastMode)
}

func (s *Server) withAttachmentContext(question string, ids []string) string {
	if len(ids) == 0 || s.store == nil {
		return question
	}
	var parts []string
	for _, id := range ids {
		var name, mime, text string
		if err := s.store.db.QueryRow("SELECT name,mime,text_content FROM attachments WHERE id=?", id).Scan(&name, &mime, &text); err != nil {
			continue
		}
		part := "ADJUNTO: " + name + " (" + mime + ")"
		if text != "" {
			part += "\n" + text[:min(len(text), 2<<20)]
		} else {
			part += "\n[archivo binario guardado localmente; usa una herramienta de visión si está disponible]"
		}
		parts = append(parts, part)
	}
	if len(parts) == 0 {
		return question
	}
	return question + "\n\n--- ARCHIVOS ADJUNTOS LOCALES ---\n" + strings.Join(parts, "\n\n")
}

func needsSession(question string, previous []ConversationTurn) bool {
	lower := strings.ToLower(question)
	for _, word := range []string{"instala", "instalar", "ejecuta", "ejecutar", "modifica", "modificar", "escribe", "crear", "crea", "borra", "borrar", "desinstala", "desinstalar", "configura", "configurar", "hazlo", "haz eso", "adelante", "procede", "sí, hazlo", "si, hazlo", "ejecútalo", "ejecutalo", "instálalo", "instalalo", "sudo", "apaga", "reinicia", "install", "execute", "modify", "write", "create", "delete", "configure", "uninstall", "shutdown", "reboot"} {
		if strings.Contains(lower, word) {
			return true
		}
	}
	// A short confirmation is an action request only when the previous answer
	// actually offered or described an action. This keeps ordinary "sí" answers
	// on the fast lane while allowing confirmations to reach Hermes/tools.
	compact := strings.Trim(strings.TrimSpace(lower), ".!¡¿? ")
	if compact == "si" || compact == "sí" || compact == "ok" || compact == "vale" || compact == "adelante" {
		for i := len(previous) - 1; i >= 0; i-- {
			if previous[i].Role != "Rashin" {
				continue
			}
			last := strings.ToLower(previous[i].Content)
			for _, word := range []string{"¿quieres", "quieres", "puedo", "instalar", "ejecutar", "ejecuta", "comando", "instale", "instalar y ejecutar"} {
				if strings.Contains(last, word) {
					return true
				}
			}
			break
		}
	}
	return false
}

// needsWebTools keeps questions about changing outside information out of the
// fast local lane.  The local model must not answer a current-events question
// by pretending that its training data is live.  Hermes has both DDGS search
// and the local browser available, so it can search and open sources without
// adding a cloud API key to Rashin.
func needsWebTools(question string) bool {
	lower := strings.ToLower(strings.TrimSpace(question))
	markers := []string{
		"wikipedia", "wiki", "internet", "en la web", "en internet", "web search",
		"busca en", "buscar en", "búscame", "buscame", "búsqueda", "busqueda",
		"noticias", "fuentes", "fuente", "enlace", "link", "url", "online",
		"actual", "actualmente", "de hoy", "hoy", "últimas", "ultimas", "reciente",
		"presidente actual", "quién es el actual", "quien es el actual", "qué pasó",
		"que paso", "latest", "current", "today", "news", "search the web",
	}
	for _, marker := range markers {
		if strings.Contains(lower, marker) {
			return true
		}
	}
	return false
}

func webToolsPrompt(prompt string) string {
	return "Esta consulta pide información externa o actual. Usa las herramientas web de Hermes: primero web_search para encontrar fuentes y después browser para abrir y comprobar las páginas relevantes. Si web_extract no está disponible, continúa con browser y no respondas que no tienes internet mientras browser esté disponible. Distingue hechos verificados de inferencias, incluye enlaces o nombres de las fuentes y fecha de consulta cuando sea relevante. No inventes resultados.\n\n" + prompt
}

func (s *Server) runFast(ctx context.Context, question string, previous []ConversationTurn, emit func(ChatEvent), fastMode bool) (string, error) {
	if fastMode {
		emit(ChatEvent{Type: "working", Text: "Modo turbo · usando más recursos locales"})
	}
	toolContext := s.readOnlyContext(ctx, question, emit)
	system := "Eres Rashin, el asistente local de Tartarus. Responde en español salvo que el usuario use otro idioma. Sé breve y práctico. No ejecutes acciones ni inventes estados. Si falta información, dilo. Para hardware, los resultados de las herramientas de solo lectura y el mapa local tienen prioridad absoluta sobre tu conocimiento general: no sustituyas una GPU detectada por una GPU integrada genérica, no inventes que falta una GPU y no confundas el fabricante con el modelo. Si la herramienta devuelve una identidad concreta, repítela con precisión. Todo el siguiente contexto procede de la máquina local y es solo de lectura:\n\n" + s.vaultContext() + "\n\n" + toolContext
	payload := map[string]any{
		"model":    s.cfg.Model,
		"stream":   true,
		"messages": []map[string]string{{"role": "system", "content": system}, {"role": "user", "content": conversationPrompt(question, previous)}},
	}
	if fastMode {
		// llama-server accepts these OpenAI-compatible generation hints.  Turbo
		// is intentionally a per-request profile: it does not start a second
		// model or compete with the active 96K context.
		payload["max_tokens"] = 1024
		payload["cache_prompt"] = true
	} else {
		payload["max_tokens"] = 512
	}
	data, _ := json.Marshal(payload)
	endpoint := strings.TrimRight(s.cfg.Endpoint, "/") + "/chat/completions"
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := (&http.Client{Timeout: 5 * time.Minute}).Do(request)
	if err != nil {
		return "", fmt.Errorf("no se pudo contactar con el modelo local: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1000))
		return "", fmt.Errorf("el modelo local respondió HTTP %d: %s", response.StatusCode, strings.TrimSpace(string(body)))
	}

	var answer strings.Builder
	scanner := bufio.NewScanner(response.Body)
	scanner.Buffer(make([]byte, 4096), 2<<20)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || !strings.HasPrefix(line, "data:") {
			continue
		}
		value := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if value == "[DONE]" {
			break
		}
		var event struct {
			Choices []struct {
				Delta struct {
					Content string `json:"content"`
				} `json:"delta"`
			} `json:"choices"`
		}
		if json.Unmarshal([]byte(value), &event) != nil || len(event.Choices) == 0 {
			continue
		}
		fragment := event.Choices[0].Delta.Content
		if fragment == "" {
			continue
		}
		answer.WriteString(fragment)
		emit(ChatEvent{Type: "delta", Text: fragment})
	}
	if err := scanner.Err(); err != nil && !errors.Is(err, context.Canceled) {
		return "", err
	}
	result := strings.TrimSpace(answer.String())
	if result == "" {
		return "", errors.New("el modelo local no devolvió una respuesta")
	}
	return result, nil
}

func (s *Server) vaultContext() string {
	var parts []string
	for _, name := range []string{"AGENTS.md", "system.md", "desktop.md", "packages.md", "user.md"} {
		data, err := os.ReadFile(filepath.Join(s.cfg.VaultPath, name))
		if err == nil {
			parts = append(parts, "## "+name+"\n"+string(data[:min(len(data), 4500)]))
		}
	}
	if len(parts) == 0 {
		parts = append(parts, "No hay contexto indexado todavía.")
	}
	if s.store != nil {
		if profile, err := s.store.UserProfile(); err == nil && strings.TrimSpace(profile) != "" {
			parts = append(parts, "## perfil-local\n"+profile[:min(len(profile), 10000)])
		}
		if memories, err := s.store.MemoryCandidates("approved"); err == nil && len(memories) > 0 {
			var approved []string
			for _, memory := range memories {
				approved = append(approved, "- "+memory.Content)
			}
			parts = append(parts, "## memoria-aprobada\n"+strings.Join(approved, "\n"))
		}
	}
	return strings.Join(parts, "\n\n")
}

func (s *Server) readOnlyContext(ctx context.Context, question string, emit func(ChatEvent)) string {
	lower := strings.ToLower(question)
	var output []string
	tool := func(id, title string, filter func(string) string, command ...string) {
		emit(ChatEvent{Type: "tool", ToolID: id, Title: title, ToolState: "running"})
		commandCtx, cancel := context.WithTimeout(ctx, 4*time.Second)
		defer cancel()
		result := exec.CommandContext(commandCtx, command[0], command[1:]...)
		result.Env = append(os.Environ(), "LC_ALL=C")
		data, err := result.Output()
		text := strings.TrimSpace(string(data))
		if filter != nil {
			text = filter(text)
		}
		state := "done"
		if err != nil || text == "" {
			state = "failed"
			text = "No disponible: la consulta no devolvió datos. No deduzcas el hardware a partir de este resultado."
		}
		output = append(output, "## "+title+"\n"+text[:min(len(text), 8000)])
		emit(ChatEvent{Type: "tool", ToolID: id, Title: title, ToolState: state})
	}
	if strings.Contains(lower, "monitor") || strings.Contains(lower, "pantalla") || strings.Contains(lower, "display") {
		tool("system_query", "Consultando monitores", nil, "hyprctl", "monitors", "-j")
	}
	if strings.Contains(lower, "gpu") || strings.Contains(lower, "gráfica") || strings.Contains(lower, "grafica") || strings.Contains(lower, "graphics") || strings.Contains(lower, "hardware") {
		// Fixed, read-only command: never execute a command proposed by the LLM.
		tool("gpu_query", "GPU detectada (SDevice identifica el modelo de la tarjeta; Driver indica el controlador)", gpuPCIContext, "lspci", "-vmm", "-nn", "-k")
	}
	if strings.Contains(lower, "hardware") || strings.Contains(lower, "cpu") || strings.Contains(lower, "gpu") || strings.Contains(lower, "ram") || strings.Contains(lower, "memoria") || strings.Contains(lower, "disco") {
		tool("system_query", "Consultando recursos del sistema", nil, "sh", "-c", "free -h; printf '\\n'; df -h /home; printf '\\n'; cat /proc/loadavg")
	}
	if strings.Contains(lower, "proceso") || strings.Contains(lower, "consume") {
		tool("system_query", "Consultando procesos", nil, "ps", "-eo", "pid,comm,%cpu,%mem", "--sort=-%cpu")
	}
	return strings.Join(output, "\n\n")
}

func gpuPCIContext(output string) string {
	var devices []string
	for _, block := range strings.Split(strings.ReplaceAll(output, "\r\n", "\n"), "\n\n") {
		for _, line := range strings.Split(block, "\n") {
			// lspci -nn identifies display-class devices with PCI class 03xx,
			// including VGA, 3D and other display controllers.
			if strings.HasPrefix(line, "Class:") && strings.Contains(line, "[03") {
				devices = append(devices, strings.TrimSpace(block))
				break
			}
		}
	}
	return strings.Join(devices, "\n\n")
}

func (s *Server) broadcast(event ChatEvent) {
	s.mu.Lock()
	clients := make([]*websocket.Conn, 0, len(s.clients))
	for client := range s.clients {
		clients = append(clients, client)
	}
	s.mu.Unlock()
	for _, client := range clients {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		_ = wsjson.Write(ctx, client, event)
		cancel()
	}
}

func (s *Server) handleChatSocket(w http.ResponseWriter, r *http.Request) {
	client, err := websocket.Accept(w, r, &websocket.AcceptOptions{InsecureSkipVerify: true})
	if err != nil {
		return
	}
	defer client.Close(websocket.StatusNormalClosure, "")
	s.mu.Lock()
	s.clients[client] = struct{}{}
	s.mu.Unlock()
	s.resumeDurableQueue(client)
	defer func() {
		s.mu.Lock()
		delete(s.clients, client)
		s.mu.Unlock()
	}()

	for {
		var message struct {
			Type         string   `json:"type"`
			Text         string   `json:"text"`
			Mode         string   `json:"mode"`
			SessionID    string   `json:"sessionId"`
			ModelProfile string   `json:"modelProfile"`
			FastMode     bool     `json:"fastMode"`
			Attachments  []string `json:"attachmentIds"`
			ClientID     string   `json:"clientId"`
			QueueID      string   `json:"queueId"`
		}
		if err := wsjson.Read(context.Background(), client, &message); err != nil {
			return
		}
		if message.Type == "resume" {
			s.resumeSocketQueue(client, message.QueueID, message.ClientID)
			continue
		}
		if message.Type != "prompt" || strings.TrimSpace(message.Text) == "" {
			continue
		}
		sessionID := strings.TrimSpace(message.SessionID)
		if sessionID == "" {
			sessionID, _ = s.defaultSessionID()
		}
		s.enqueueSocketTurn(&queuedSocketRequest{
			client: client, question: strings.TrimSpace(message.Text),
			forceHermes: message.Mode == "hermes", sessionID: sessionID,
			modelProfile: message.ModelProfile, fastMode: message.FastMode,
			attachments: message.Attachments, clientID: message.ClientID,
		})
	}
}

func (s *Server) resumeSocketQueue(client *websocket.Conn, queueID, clientID string) {
	if s.store == nil || strings.TrimSpace(queueID) == "" {
		return
	}
	items, err := s.store.Queue("")
	if err != nil {
		return
	}
	for _, item := range items {
		if item.ID != queueID || item.Status != "queued" {
			continue
		}
		_ = s.store.SetQueueStatus(item.ID, "queued", "")
		s.enqueueSocketTurn(&queuedSocketRequest{client: client, question: item.Prompt, forceHermes: item.Mode == "hermes", sessionID: item.SessionID, queueID: item.ID, modelProfile: item.ModelProfile, fastMode: item.FastMode, attachments: item.AttachmentIDs, clientID: clientID})
		return
	}
}

func (s *Server) setChatSession(session *chatSession, sessionID string) {
	turns := []ConversationTurn{}
	if s.store != nil {
		if messages, err := s.store.Messages(sessionID, maxConversationTurns); err == nil {
			for _, message := range messages {
				role := "Rashin"
				if message.Role == "user" {
					role = "Usuario"
				}
				turns = append(turns, ConversationTurn{Role: role, Content: message.Content})
			}
		}
	}
	session.set(sessionID, turns)
}

func (s *Server) enqueueSocketTurn(request *queuedSocketRequest) {
	s.mu.Lock()
	if s.queuedLocked(request.queueID) {
		s.mu.Unlock()
		return
	}
	if s.store != nil && !s.store.SessionExists(request.sessionID) {
		s.mu.Unlock()
		socketWrite(request.client, ChatEvent{Type: "error", ClientID: request.clientID, SessionID: request.sessionID, Error: "La sesión ya no existe"})
		return
	}
	if err := s.validateAttachments(request.sessionID, request.attachments); err != nil {
		s.mu.Unlock()
		socketWrite(request.client, ChatEvent{Type: "error", ClientID: request.clientID, SessionID: request.sessionID, Error: err.Error()})
		return
	}
	if s.store != nil && request.queueID == "" {
		item, err := s.store.Enqueue(request.sessionID, request.question, map[bool]string{true: "hermes", false: "auto"}[request.forceHermes], request.modelProfile, request.fastMode, request.attachments)
		if err != nil {
			s.mu.Unlock()
			socketWrite(request.client, ChatEvent{Type: "error", ClientID: request.clientID, SessionID: request.sessionID, Error: err.Error()})
			return
		}
		request.queueID = item.ID
	}
	busy := s.activeCancel != nil || len(s.queued) > 0
	if busy {
		s.queued = append(s.queued, request)
		position := len(s.queued)
		s.mu.Unlock()
		s.queueEvent(request, ChatEvent{Type: "queued", Position: position, Text: "En cola"})
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.activeCancel = cancel
	s.activeRequest = strconv.FormatInt(time.Now().UnixNano(), 10)
	s.activeQueueID = request.queueID
	s.activeSessionID = request.sessionID
	s.mu.Unlock()
	go s.runSocketTurn(request, ctx)
}

func (s *Server) resumeDurableQueue(client *websocket.Conn) {
	if s.store == nil {
		return
	}
	items, err := s.store.Queue("")
	if err != nil {
		return
	}
	for _, item := range items {
		if item.Status != "queued" && item.Status != "interrupted" {
			continue
		}
		_ = s.store.SetQueueStatus(item.ID, "queued", "")
		s.enqueueSocketTurn(&queuedSocketRequest{client: client, question: item.Prompt, forceHermes: item.Mode == "hermes", sessionID: item.SessionID, queueID: item.ID, modelProfile: item.ModelProfile, fastMode: item.FastMode, attachments: item.AttachmentIDs})
	}
}

func (s *Server) runSocketTurn(request *queuedSocketRequest, ctx context.Context) {
	defer s.finishSocketTurn()
	question := request.question
	if ctx.Err() != nil {
		return
	}
	if s.store != nil && !s.store.SessionExists(request.sessionID) {
		return
	}
	if s.store != nil && request.queueID != "" {
		_ = s.store.SetQueueStatus(request.queueID, "running", "")
	}
	previous := s.sessionConversation(request.sessionID, request.queueID)
	s.mu.Lock()
	s.lastQuestion = question
	s.mu.Unlock()
	if s.store != nil {
		s.maybeMemoryCandidate(question, "chat")
		if err := s.store.AddTurnMessage(request.sessionID, request.queueID, "user", question, s.cfg.Model, "completed", request.attachments); err != nil {
			_ = s.store.SetQueueStatus(request.queueID, "failed", err.Error())
			s.queueEvent(request, ChatEvent{Type: "error", Error: "No se pudo guardar el mensaje"})
			return
		}
	}
	s.queueEvent(request, ChatEvent{Type: "connected", Model: modelLabel(s.cfg.Model), Text: question})
	emit := func(event ChatEvent) {
		s.queueEvent(request, event)
	}
	answer, err := s.runTurn(ctx, question, emit, request.forceHermes, previous, request.fastMode, request.attachments)
	if ctx.Err() != nil {
		err = ctx.Err()
	}
	if err != nil {
		cancelled := ctx.Err() != nil
		if s.store != nil && request.queueID != "" && s.store.QueueStatus(request.queueID) == "cancelled" {
			cancelled = true
		}
		message := err.Error()
		if cancelled {
			message = "Consulta cancelada"
		}
		if s.store != nil && request.queueID != "" {
			status := "failed"
			if cancelled {
				status = "cancelled"
			}
			_ = s.store.SetQueueStatus(request.queueID, status, message)
		}
		if s.store != nil && !cancelled {
			_ = s.store.AddTurnMessage(request.sessionID, request.queueID, "assistant", message, s.cfg.Model, "failed", nil)
		}
		if cancelled {
			emit(ChatEvent{Type: "cancelled", Error: message})
		} else {
			emit(ChatEvent{Type: "error", Error: message})
		}
		return
	}
	entry := HistoryEntry{At: time.Now().Format(time.RFC3339), Question: question, Answer: answer, Model: s.cfg.Model}
	s.saveHistory(entry)
	if s.store != nil {
		if err := s.store.AddTurnMessage(request.sessionID, request.queueID, "assistant", answer, s.cfg.Model, "completed", nil); err != nil {
			return
		}
		if request.queueID != "" {
			_ = s.store.SetQueueStatus(request.queueID, "completed", "")
		}
	}
	emit(ChatEvent{Type: "done", Answer: answer, Entry: &entry, Model: modelLabel(s.cfg.Model), Actions: extractActions(answer)})
}

func (s *Server) maybeMemoryCandidate(question, source string) {
	if s.store == nil {
		return
	}
	clean := strings.TrimSpace(question)
	if len(clean) < 8 || len(clean) > 500 {
		return
	}
	lower := strings.ToLower(clean)
	for _, secret := range []string{"contraseña", "password", "token", "api key", "clave privada", "secret", "keepass"} {
		if strings.Contains(lower, secret) {
			return
		}
	}
	for _, marker := range []string{"me gusta", "prefiero", "mi nombre", "soy ", "uso ", "tengo ", "trabajo con", "mi gpu", "mi cpu", "mi modelo"} {
		if strings.Contains(lower, marker) {
			_, _ = s.store.AddMemoryCandidate(clean, source)
			return
		}
	}
}

func (s *Server) finishSocketTurn() {
	s.mu.Lock()
	if s.activeCancel != nil {
		s.activeCancel()
	}
	s.activeCancel = nil
	s.activeRequest = ""
	s.activeQueueID = ""
	s.activeSessionID = ""
	for len(s.queued) > 0 {
		request := s.queued[0]
		s.queued = s.queued[1:]
		if s.store != nil && request.queueID != "" && s.store.QueueStatus(request.queueID) != "queued" {
			continue
		}
		ctx, cancel := context.WithCancel(context.Background())
		s.activeCancel = cancel
		s.activeRequest = strconv.FormatInt(time.Now().UnixNano(), 10)
		s.activeQueueID = request.queueID
		s.activeSessionID = request.sessionID
		s.mu.Unlock()
		go s.runSocketTurn(request, ctx)
		return
	}
	s.mu.Unlock()
}

var (
	urlActionPattern     = regexp.MustCompile(`https?://[^\s<>()]+`)
	pathActionPattern    = regexp.MustCompile(`(?:^|[\s(])((?:/|~/)[^\s,;<>]+)`)
	commandActionPattern = regexp.MustCompile("`([^`]+)`")
	colorActionPattern   = regexp.MustCompile(`#[0-9a-fA-F]{6,8}`)
)

func extractActions(answer string) []Action {
	seen := map[string]bool{}
	actions := make([]Action, 0, 6)
	add := func(kind, label, value string) {
		value = strings.TrimRight(strings.TrimSpace(value), ".,;:!?)]}")
		key := kind + "\x00" + value
		if value == "" || seen[key] || len(actions) >= 6 {
			return
		}
		seen[key] = true
		actions = append(actions, Action{Kind: kind, Label: label, Value: value})
	}
	for _, value := range urlActionPattern.FindAllString(answer, -1) {
		add("url", "Abrir enlace", value)
	}
	for _, match := range pathActionPattern.FindAllStringSubmatch(answer, -1) {
		if len(match) > 1 {
			value := strings.Replace(match[1], "~/", homeDir()+string(filepath.Separator), 1)
			if _, err := os.Stat(value); err == nil {
				add("path", "Abrir archivo", value)
			}
		}
	}
	for _, match := range commandActionPattern.FindAllStringSubmatch(answer, -1) {
		if len(match) > 1 {
			command := strings.TrimSpace(match[1])
			fields := strings.Fields(command)
			if len(fields) > 0 {
				if _, err := exec.LookPath(fields[0]); err == nil {
					add("command", "Copiar comando", command)
				}
			}
		}
	}
	for _, value := range colorActionPattern.FindAllString(answer, -1) {
		add("color", "Copiar color", value)
	}
	return actions
}

func socketWrite(client *websocket.Conn, event ChatEvent) {
	if client == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_ = wsjson.Write(ctx, client, event)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func splitIDs(value string) []string {
	var ids []string
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			ids = append(ids, item)
		}
	}
	return ids
}

func hermesConfigExists() bool {
	for _, path := range []string{filepath.Join(homeDir(), ".hermes", "config.yaml"), filepath.Join(homeDir(), ".hermes", "config.json")} {
		if _, err := os.Stat(path); err == nil {
			return true
		}
	}
	return false
}

// Keep url imported for older Go toolchains where url.QueryEscape is used by
// external clients; this also makes the local-only policy explicit in docs.
var _ = url.QueryEscape
