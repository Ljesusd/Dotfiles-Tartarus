package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func decodeJSON(r *http.Request, target any) error {
	decoder := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	return decoder.Decode(target)
}

func (s *Server) handleWorkspace(w http.ResponseWriter, r *http.Request) {
	projects, err := s.store.Projects(false)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	sessions, err := s.store.Sessions("", r.URL.Query().Get("q"), false)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	queue, _ := s.store.Queue(r.URL.Query().Get("sessionId"))
	memories, _ := s.store.MemoryCandidates("pending")
	models, _ := s.refreshModelCatalog()
	writeHTTPJSON(w, map[string]any{
		"defaultSessionId": s.defaultSession,
		"projects":         projects,
		"sessions":         sessions,
		"queue":            queue,
		"memoryCandidates": memories,
		"models":           models,
	})
}

func (s *Server) handleProjects(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.Projects(r.URL.Query().Get("archived") == "1")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, items)
}

func (s *Server) handleCreateProject(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	item, err := s.store.CreateProject(body.Name, body.Description)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, item)
}

func (s *Server) handleUpdateProject(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Archived    *bool  `json:"archived"`
		Pinned      *bool  `json:"pinned"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	if err := s.store.UpdateProject(r.PathValue("id"), body.Name, body.Description, body.Archived, body.Pinned); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func (s *Server) handleDeleteProject(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "falta el proyecto", http.StatusBadRequest)
		return
	}
	// Remove attachment files before the database cascade. Messages and queue
	// rows are deleted by the foreign-key relationship.
	rows, _ := s.store.db.Query("SELECT path FROM attachments WHERE session_id IN (SELECT id FROM sessions WHERE project_id=?)", id)
	if rows != nil {
		for rows.Next() {
			var rel string
			if rows.Scan(&rel) == nil {
				if path, err := s.safeVaultPath(rel); err == nil {
					_ = os.Remove(path)
				}
			}
		}
		rows.Close()
	}
	if err := s.store.DeleteProject(id); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func (s *Server) handleSessions(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.Sessions(r.URL.Query().Get("projectId"), r.URL.Query().Get("q"), r.URL.Query().Get("archived") == "1")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, items)
}

func (s *Server) handleCreateSession(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ProjectID string `json:"projectId"`
		Title     string `json:"title"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	item, err := s.store.CreateSession(body.ProjectID, body.Title)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeHTTPJSON(w, item)
}

func (s *Server) handleSessionMessages(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.Messages(r.PathValue("id"), 500)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, items)
}

func (s *Server) handleUpdateSession(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Title    string `json:"title"`
		Archived *bool  `json:"archived"`
		Pinned   *bool  `json:"pinned"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	if err := s.store.UpdateSession(r.PathValue("id"), body.Title, body.Archived, body.Pinned); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func (s *Server) handleDeleteSession(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "falta la sesión", http.StatusBadRequest)
		return
	}
	// A session can be removed even when it is the current/default one.  The
	// dashboard deliberately clears its view after the delete; the daemon then
	// makes sure a fresh fallback exists for the next prompt.
	if pending, err := s.store.Queue(id); err == nil {
		for _, item := range pending {
			_ = s.cancelQueueItem(item.ID)
		}
	}
	rows, _ := s.store.db.Query("SELECT path FROM attachments WHERE session_id=?", id)
	if rows != nil {
		for rows.Next() {
			var rel string
			if rows.Scan(&rel) == nil {
				if path, err := s.safeVaultPath(rel); err == nil {
					_ = os.Remove(path)
				}
			}
		}
		rows.Close()
	}
	if err := s.store.DeleteSession(id); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if id == s.defaultSession {
		fallback, err := s.store.EnsureDefaults(s.cfg.Model)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		s.defaultSession = fallback
	}
	writeHTTPJSON(w, map[string]any{"ok": true, "defaultSessionId": s.defaultSession})
}

func (s *Server) handleQueue(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.Queue(r.URL.Query().Get("sessionId"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, items)
}

func (s *Server) handleCancelQueueItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "falta la cola", http.StatusBadRequest)
		return
	}
	_ = s.cancelQueueItem(id)
	if err := s.store.SetQueueStatus(id, "cancelled", "Cancelado desde el dashboard"); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func (s *Server) handleResumeQueueItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "falta la cola", http.StatusBadRequest)
		return
	}
	items, err := s.store.Queue("")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	for _, item := range items {
		if item.ID != id {
			continue
		}
		if item.Status == "queued" || item.Status == "running" {
			writeHTTPJSON(w, map[string]any{"ok": true, "status": item.Status})
			return
		}
		if item.Status != "interrupted" {
			http.Error(w, "la consulta ya no se puede reanudar", http.StatusBadRequest)
			return
		}
		if err := s.store.SetQueueStatus(id, "queued", "Reanudada desde el dashboard"); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		writeHTTPJSON(w, map[string]any{"ok": true, "status": "queued"})
		return
	}
	http.Error(w, "consulta no encontrada", http.StatusNotFound)
}

// cancelQueueItem updates the durable queue and, when the item is in memory,
// also prevents a queued websocket turn from being started later.  The old
// implementation only changed SQLite, so a cancelled item could still run
// when the previous turn finished.
func (s *Server) cancelQueueItem(id string) bool {
	var active context.CancelFunc
	var queued *queuedSocketRequest
	s.mu.Lock()
	if s.activeQueueID == id {
		active = s.activeCancel
	} else {
		for index, item := range s.queued {
			if item.queueID != id {
				continue
			}
			queued = item
			s.queued = append(s.queued[:index], s.queued[index+1:]...)
			break
		}
	}
	s.mu.Unlock()
	if queued != nil {
		if s.store != nil {
			_ = s.store.SetQueueStatus(id, "cancelled", "Cancelado desde el dashboard")
		}
		socketWrite(queued.client, ChatEvent{Type: "cancelled", QueueID: id, SessionID: queued.sessionID, Error: "Consulta cancelada"})
		return true
	}
	if active != nil {
		if s.store != nil {
			_ = s.store.SetQueueStatus(id, "cancelled", "Cancelado desde el dashboard")
		}
		active()
		return true
	}
	return false
}

func (s *Server) refreshModelCatalog() ([]ModelProfileRecord, error) {
	root := filepath.Join(homeDir(), "Models", "LLM")
	var paths []string
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err == nil && info != nil && !info.IsDir() && strings.EqualFold(filepath.Ext(path), ".gguf") && !isAuxiliaryModel(path) {
			paths = append(paths, path)
		}
		return nil
	})
	ids := make([]string, 0, len(paths))
	for _, path := range paths {
		name := filepath.Base(path)
		lower := strings.ToLower(name)
		tier := "Medium"
		switch {
		case strings.Contains(lower, "q2") || strings.Contains(lower, "iq2"):
			tier = "Low"
		case strings.Contains(lower, "q4") || strings.Contains(lower, "iq4"):
			tier = "Medium"
		case strings.Contains(lower, "q5") || strings.Contains(lower, "iq5"):
			tier = "High"
		case strings.Contains(lower, "q6") || strings.Contains(lower, "iq6"):
			tier = "XHigh"
		case strings.Contains(lower, "q8") || strings.Contains(lower, "iq8"):
			tier = "Max"
		case strings.Contains(lower, "f16") || strings.Contains(lower, "bf16"):
			tier = "Ultra"
		}
		id := modelSlug(name)
		ids = append(ids, id)
		modelID := strings.TrimSuffix(name, filepath.Ext(name))
		active := strings.Contains(strings.ToLower(s.cfg.Model), strings.ToLower(modelID))
		item := ModelProfileRecord{ID: id, Name: modelDisplayName(name), Tier: tier, ModelID: modelID, Path: path, ContextTokens: 98304, Installed: true, Active: active, Source: "local", Size: fileSize(path)}
		if err := s.store.UpsertModel(item); err != nil {
			return nil, err
		}
	}
	if err := s.store.PruneModels(ids); err != nil {
		return nil, err
	}
	return s.store.Models()
}

func isAuxiliaryModel(path string) bool {
	name := strings.ToLower(filepath.Base(path))
	return strings.HasPrefix(name, "mmproj") || strings.HasPrefix(name, "mtp") || strings.Contains(name, ".mtp.") || strings.Contains(name, "-mtp-") || strings.Contains(name, "_mtp_")
}

func modelSlug(name string) string {
	name = strings.ToLower(strings.TrimSuffix(name, filepath.Ext(name)))
	var b strings.Builder
	for _, r := range name {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		} else if b.Len() > 0 {
			b.WriteByte('-')
		}
	}
	return strings.Trim(b.String(), "-")
}
func modelDisplayName(name string) string {
	name = strings.TrimSuffix(name, filepath.Ext(name))
	name = strings.ReplaceAll(name, "_", " ")
	name = strings.ReplaceAll(name, "-", " ")
	return name
}
func fileSize(path string) int64 {
	info, err := os.Stat(path)
	if err != nil {
		return 0
	}
	return info.Size()
}

func (s *Server) handleModels(w http.ResponseWriter, r *http.Request) {
	items, err := s.refreshModelCatalog()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	downloads, _ := s.store.ModelDownloads()
	writeHTTPJSON(w, map[string]any{"models": items, "downloads": downloads, "activeModel": s.cfg.Model, "contextTokens": 98304, "singleActive": true})
}
func (s *Server) handleModelsRefresh(w http.ResponseWriter, r *http.Request) { s.handleModels(w, r) }

func (s *Server) handleModelDownloads(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.ModelDownloads()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, items)
}

func safeModelName(value string) string {
	value = filepath.Base(strings.TrimSpace(value))
	if value == "." || value == "" {
		value = "model.gguf"
	}
	var b strings.Builder
	for _, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || strings.ContainsRune("._-", r) {
			b.WriteRune(r)
		} else {
			b.WriteRune('_')
		}
	}
	value = b.String()
	if !strings.HasSuffix(strings.ToLower(value), ".gguf") {
		value += ".gguf"
	}
	return value
}

func (s *Server) handleModelDownload(w http.ResponseWriter, r *http.Request) {
	var body struct {
		URL     string `json:"url"`
		Name    string `json:"name"`
		Tier    string `json:"tier"`
		Replace bool   `json:"replace"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	u, err := url.Parse(strings.TrimSpace(body.URL))
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		http.Error(w, "la URL debe ser HTTP(S)", http.StatusBadRequest)
		return
	}
	name := safeModelName(body.Name)
	if body.Name == "" {
		name = safeModelName(filepath.Base(u.Path))
	}
	tier := body.Tier
	if tier == "" {
		tier = "Medium"
	}
	if !map[string]bool{"Low": true, "Medium": true, "High": true, "XHigh": true, "Max": true, "Ultra": true}[tier] {
		http.Error(w, "perfil inválido", http.StatusBadRequest)
		return
	}
	dir := filepath.Join(homeDir(), "Models", "LLM", "Tartarus")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	path := filepath.Join(dir, name)
	if !body.Replace {
		if _, err := os.Stat(path); err == nil {
			http.Error(w, "ese modelo ya existe; usa replace para actualizarlo", http.StatusConflict)
			return
		}
	}
	now := nowString()
	item := ModelDownloadRecord{ID: newID("download"), URL: u.String(), Name: name, Tier: tier, Path: path, Status: "queued", CreatedAt: now, UpdatedAt: now}
	if err := s.store.CreateModelDownload(item); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	go s.downloadModel(item, body.Replace)
	writeHTTPJSON(w, item)
}

func (s *Server) downloadModel(item ModelDownloadRecord, replace bool) {
	request, err := http.NewRequest(http.MethodGet, item.URL, nil)
	if err != nil {
		_ = s.store.UpdateModelDownload(item.ID, "failed", err.Error(), 0, 0, 0)
		return
	}
	client := &http.Client{Timeout: 0}
	response, err := client.Do(request)
	if err != nil {
		_ = s.store.UpdateModelDownload(item.ID, "failed", err.Error(), 0, 0, 0)
		return
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		_ = s.store.UpdateModelDownload(item.ID, "failed", fmt.Sprintf("HTTP %d", response.StatusCode), 0, 0, response.ContentLength)
		return
	}
	flags := os.O_CREATE | os.O_WRONLY
	if replace {
		flags |= os.O_TRUNC
	} else {
		flags |= os.O_EXCL
	}
	file, err := os.OpenFile(item.Path, flags, 0o600)
	if err != nil {
		_ = s.store.UpdateModelDownload(item.ID, "failed", err.Error(), 0, 0, response.ContentLength)
		return
	}
	_ = s.store.UpdateModelDownload(item.ID, "downloading", "", 0, 0, response.ContentLength)
	var written int64
	buffer := make([]byte, 256*1024)
	lastReport := time.Now()
	for {
		n, readErr := response.Body.Read(buffer)
		if n > 0 {
			if _, err := file.Write(buffer[:n]); err != nil {
				file.Close()
				_ = s.store.UpdateModelDownload(item.ID, "failed", err.Error(), 0, written, response.ContentLength)
				return
			}
			written += int64(n)
			if time.Since(lastReport) > time.Second {
				progress := float64(0)
				if response.ContentLength > 0 {
					progress = float64(written) / float64(response.ContentLength) * 100
				}
				_ = s.store.UpdateModelDownload(item.ID, "downloading", "", progress, written, response.ContentLength)
				lastReport = time.Now()
			}
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			file.Close()
			_ = s.store.UpdateModelDownload(item.ID, "failed", readErr.Error(), 0, written, response.ContentLength)
			return
		}
	}
	if err := file.Close(); err != nil {
		_ = s.store.UpdateModelDownload(item.ID, "failed", err.Error(), 0, written, response.ContentLength)
		return
	}
	_ = s.store.UpdateModelDownload(item.ID, "completed", "", 100, written, response.ContentLength)
	_, _ = s.refreshModelCatalog()
}

func (s *Server) handleModelDelete(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ID string `json:"id"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	models, err := s.refreshModelCatalog()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	for _, item := range models {
		if item.ID != body.ID {
			continue
		}
		if item.Active {
			http.Error(w, "no se puede borrar el perfil activo", http.StatusBadRequest)
			return
		}
		root := filepath.Join(homeDir(), "Models", "LLM")
		rel, relErr := filepath.Rel(root, item.Path)
		if relErr != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
			http.Error(w, "ruta de modelo inválida", http.StatusBadRequest)
			return
		}
		if err := os.Remove(item.Path); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		writeHTTPJSON(w, map[string]any{"ok": true})
		return
	}
	http.Error(w, "modelo no encontrado", http.StatusNotFound)
}

func (s *Server) handleModelActivate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ID string `json:"id"`
	}
	if err := decodeJSON(r, &body); err != nil || strings.TrimSpace(body.ID) == "" {
		http.Error(w, "falta el id del perfil", http.StatusBadRequest)
		return
	}
	models, err := s.refreshModelCatalog()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	var selected *ModelProfileRecord
	for _, item := range models {
		if item.ID == body.ID {
			copy := item
			selected = &copy
			break
		}
	}
	if selected == nil || !selected.Installed {
		http.Error(w, "modelo no instalado", http.StatusNotFound)
		return
	}
	if err := s.store.ActivateModel(selected.ID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	s.cfg.Model = selected.ModelID
	if err := saveConfig(s.cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := saveActiveModel(selected); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	// Restart only llama-server. Rashin itself keeps the dashboard, sessions,
	// queue and websocket alive while the model process reloads.
	restarting := false
	if systemctl, err := exec.LookPath("systemctl"); err == nil {
		restarting = exec.Command(systemctl, "--user", "restart", "tartarus-rashin-llama.service").Start() == nil
	}
	writeHTTPJSON(w, map[string]any{"ok": true, "activeModel": selected.ModelID, "restartRequired": true, "restarting": restarting, "message": "Perfil guardado; el servidor local del modelo se está recargando."})
}

func activeModelPath() string { return filepath.Join(stateDir(), "rashin-active-model.json") }

func saveActiveModel(item *ModelProfileRecord) error {
	if err := os.MkdirAll(stateDir(), 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(map[string]any{"path": item.Path, "modelId": item.ModelID, "contextTokens": item.ContextTokens})
	if err != nil {
		return err
	}
	tmp := activeModelPath() + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, activeModelPath())
}

func saveConfig(cfg Config) error {
	if err := os.MkdirAll(stateDir(), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	tmp := configPath() + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, configPath())
}

func (s *Server) handleAttachmentUpload(w http.ResponseWriter, r *http.Request) {
	if r.ContentLength > 100<<20 {
		http.Error(w, "el mensaje supera 100 MB", http.StatusRequestEntityTooLarge)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 100<<20)
	if err := r.ParseMultipartForm(100 << 20); err != nil {
		http.Error(w, "formulario de adjuntos inválido", http.StatusBadRequest)
		return
	}
	sessionID := r.FormValue("sessionId")
	if sessionID == "" {
		sessionID = s.defaultSession
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "falta el archivo", http.StatusBadRequest)
		return
	}
	defer file.Close()
	video := strings.HasPrefix(header.Header.Get("Content-Type"), "video/") || map[string]bool{".mp4": true, ".webm": true, ".mkv": true, ".mov": true, ".avi": true}[strings.ToLower(filepath.Ext(header.Filename))]
	maxFileSize := int64(25 << 20)
	if video {
		maxFileSize = 100 << 20
	}
	if header.Size > maxFileSize {
		http.Error(w, fmt.Sprintf("cada archivo está limitado a %d MB", maxFileSize/(1<<20)), http.StatusRequestEntityTooLarge)
		return
	}
	if !validAttachment(header.Filename, header.Header.Get("Content-Type")) {
		http.Error(w, "tipo de archivo no admitido", http.StatusUnsupportedMediaType)
		return
	}
	id := newID("attachment")
	safeName := filepath.Base(header.Filename)
	dir := filepath.Join(s.cfg.VaultPath, "attachments")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	rel := filepath.ToSlash(filepath.Join("attachments", id+"-"+safeName))
	path := filepath.Join(s.cfg.VaultPath, filepath.FromSlash(rel))
	out, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	written, copyErr := io.Copy(out, io.LimitReader(file, maxFileSize+1))
	out.Close()
	if copyErr != nil || written > maxFileSize {
		_ = os.Remove(path)
		http.Error(w, "no se pudo guardar el archivo", 500)
		return
	}
	mimeType := header.Header.Get("Content-Type")
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}
	textContent := extractAttachmentText(path, mimeType, header.Filename)
	item := AttachmentRecord{ID: id, SessionID: sessionID, Name: safeName, Mime: mimeType, Path: rel, Size: written, TextContent: textContent, CreatedAt: nowString()}
	if _, err = s.store.db.Exec("INSERT INTO attachments(id,session_id,name,mime,path,size,text_content,created_at) VALUES(?,?,?,?,?,?,?,?)", item.ID, item.SessionID, item.Name, item.Mime, item.Path, item.Size, item.TextContent, item.CreatedAt); err != nil {
		_ = os.Remove(path)
		http.Error(w, err.Error(), 500)
		return
	}
	writeHTTPJSON(w, item)
}

func extractAttachmentText(path, mimeType, name string) string {
	ext := strings.ToLower(filepath.Ext(name))
	if strings.HasPrefix(mimeType, "text/") || ext == ".md" || ext == ".json" || ext == ".yaml" || ext == ".yml" || ext == ".qml" || ext == ".go" || ext == ".js" || ext == ".ts" || ext == ".py" || ext == ".sh" {
		data, _ := os.ReadFile(path)
		return string(data[:min(len(data), 2<<20)])
	}
	if ext == ".pdf" {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if bin, err := exec.LookPath("pdftotext"); err == nil {
			out, err := exec.CommandContext(ctx, bin, "-layout", path, "-").Output()
			if err == nil {
				return string(out[:min(len(out), 2<<20)])
			}
		}
	}
	return ""
}

func (s *Server) handleMemoryCandidates(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.MemoryCandidates(r.URL.Query().Get("status"))
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	writeHTTPJSON(w, items)
}
func (s *Server) handleCreateMemoryCandidate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Content string `json:"content"`
		Source  string `json:"source"`
	}
	if err := decodeJSON(r, &body); err != nil || strings.TrimSpace(body.Content) == "" {
		http.Error(w, "falta el contenido", 400)
		return
	}
	item, err := s.store.AddMemoryCandidate(body.Content, body.Source)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	writeHTTPJSON(w, item)
}
func (s *Server) handleUpdateMemoryCandidate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Status string `json:"status"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", 400)
		return
	}
	if body.Status != "approved" && body.Status != "rejected" && body.Status != "pending" {
		http.Error(w, "estado inválido", 400)
		return
	}
	if err := s.store.SetMemoryStatus(r.PathValue("id"), body.Status); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true})
}

func (s *Server) handleUserProfile(w http.ResponseWriter, r *http.Request) {
	content, err := s.store.UserProfile()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, map[string]any{"content": content, "localOnly": true})
}

func (s *Server) handleSaveUserProfile(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Content string `json:"content"`
	}
	if err := decodeJSON(r, &body); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	if len(body.Content) > 10000 {
		http.Error(w, "el perfil es demasiado largo", http.StatusRequestEntityTooLarge)
		return
	}
	if err := s.store.SaveUserProfile(body.Content); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeHTTPJSON(w, map[string]any{"ok": true})
}
