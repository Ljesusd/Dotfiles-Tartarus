package main

// The store deliberately lives behind a small repository-like API.  Rashin's
// dashboard can therefore grow without making the model runner responsible
// for persistence details.  SQLite is local, WAL-backed, and the database is
// never exposed outside the localhost daemon.

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"mime"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type RashinStore struct {
	db   *sql.DB
	root string
}

type ProjectRecord struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
	Pinned      bool   `json:"pinned"`
	Archived    bool   `json:"archived"`
	CreatedAt   string `json:"createdAt"`
	UpdatedAt   string `json:"updatedAt"`
}

type SessionRecord struct {
	ID        string `json:"id"`
	ProjectID string `json:"projectId"`
	Title     string `json:"title"`
	Pinned    bool   `json:"pinned"`
	Archived  bool   `json:"archived"`
	Status    string `json:"status"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
}

type MessageRecord struct {
	ID          string   `json:"id"`
	SessionID   string   `json:"sessionId"`
	Role        string   `json:"role"`
	Content     string   `json:"content"`
	Model       string   `json:"model,omitempty"`
	State       string   `json:"state,omitempty"`
	CreatedAt   string   `json:"createdAt"`
	Attachments []string `json:"attachmentIds,omitempty"`
	QueueID     string   `json:"queueId,omitempty"`
}

type QueueRecord struct {
	ID            string   `json:"id"`
	SessionID     string   `json:"sessionId"`
	Prompt        string   `json:"prompt"`
	Mode          string   `json:"mode"`
	ModelProfile  string   `json:"modelProfile,omitempty"`
	FastMode      bool     `json:"fastMode"`
	Status        string   `json:"status"`
	Position      int      `json:"position"`
	Error         string   `json:"error,omitempty"`
	CreatedAt     string   `json:"createdAt"`
	StartedAt     string   `json:"startedAt,omitempty"`
	FinishedAt    string   `json:"finishedAt,omitempty"`
	AttachmentIDs []string `json:"attachmentIds,omitempty"`
}

type AttachmentRecord struct {
	ID          string `json:"id"`
	SessionID   string `json:"sessionId"`
	Name        string `json:"name"`
	Mime        string `json:"mime"`
	Path        string `json:"path"`
	Size        int64  `json:"size"`
	TextContent string `json:"textContent,omitempty"`
	CreatedAt   string `json:"createdAt"`
}

type ModelProfileRecord struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Tier          string `json:"tier"`
	ModelID       string `json:"modelId"`
	Path          string `json:"path"`
	ContextTokens int    `json:"contextTokens"`
	Installed     bool   `json:"installed"`
	Active        bool   `json:"active"`
	Size          int64  `json:"size"`
	Source        string `json:"source,omitempty"`
}

type ModelDownloadRecord struct {
	ID        string  `json:"id"`
	URL       string  `json:"url"`
	Name      string  `json:"name"`
	Tier      string  `json:"tier"`
	Path      string  `json:"path"`
	Status    string  `json:"status"`
	Progress  float64 `json:"progress"`
	Bytes     int64   `json:"bytes"`
	Total     int64   `json:"total"`
	Error     string  `json:"error,omitempty"`
	CreatedAt string  `json:"createdAt"`
	UpdatedAt string  `json:"updatedAt"`
}

type MemoryCandidateRecord struct {
	ID        string `json:"id"`
	Content   string `json:"content"`
	Source    string `json:"source,omitempty"`
	Status    string `json:"status"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
}

func OpenRashinStore(root string) (*RashinStore, error) {
	if err := os.MkdirAll(filepath.Dir(root), 0o700); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", root)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	store := &RashinStore{db: db, root: root}
	for _, statement := range []string{
		"PRAGMA journal_mode=WAL",
		"PRAGMA foreign_keys=ON",
		"PRAGMA busy_timeout=5000",
	} {
		if _, err := db.Exec(statement); err != nil {
			db.Close()
			return nil, err
		}
	}
	if err := store.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

func (s *RashinStore) Close() error {
	if s == nil || s.db == nil {
		return nil
	}
	return s.db.Close()
}

func (s *RashinStore) migrate() error {
	_, err := s.db.Exec(`
CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS projects (
 id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
 pinned INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
 id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
 title TEXT NOT NULL, pinned INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0,
 status TEXT NOT NULL DEFAULT 'idle', created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS messages (
 id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
 role TEXT NOT NULL, content TEXT NOT NULL, model TEXT NOT NULL DEFAULT '',
 state TEXT NOT NULL DEFAULT 'completed', attachments_json TEXT NOT NULL DEFAULT '[]',
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS attachments (
 id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
 name TEXT NOT NULL, mime TEXT NOT NULL, path TEXT NOT NULL, size INTEGER NOT NULL,
 text_content TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS queue_items (
 id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
 prompt TEXT NOT NULL, mode TEXT NOT NULL DEFAULT 'auto', model_profile TEXT NOT NULL DEFAULT '',
 fast_mode INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'queued', position INTEGER NOT NULL DEFAULT 0,
 attachment_ids_json TEXT NOT NULL DEFAULT '[]', error TEXT NOT NULL DEFAULT '',
 created_at TEXT NOT NULL, started_at TEXT NOT NULL DEFAULT '', finished_at TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS model_profiles (
 id TEXT PRIMARY KEY, name TEXT NOT NULL, tier TEXT NOT NULL, model_id TEXT NOT NULL,
 path TEXT NOT NULL, context_tokens INTEGER NOT NULL DEFAULT 98304, installed INTEGER NOT NULL DEFAULT 0,
 active INTEGER NOT NULL DEFAULT 0, size INTEGER NOT NULL DEFAULT 0, source TEXT NOT NULL DEFAULT '',
 updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS model_downloads (
 id TEXT PRIMARY KEY, url TEXT NOT NULL, name TEXT NOT NULL, tier TEXT NOT NULL,
 path TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'queued', progress REAL NOT NULL DEFAULT 0,
 bytes INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL DEFAULT 0, error TEXT NOT NULL DEFAULT '',
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS memory_candidates (
 id TEXT PRIMARY KEY, content TEXT NOT NULL, source TEXT NOT NULL DEFAULT '',
 status TEXT NOT NULL DEFAULT 'pending', created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS user_profile (id INTEGER PRIMARY KEY CHECK(id=1), content TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS messages_session_created ON messages(session_id, created_at);
CREATE INDEX IF NOT EXISTS queue_session_status ON queue_items(session_id, status, position);
`)
	if err != nil {
		return err
	}
	var migrated string
	_ = s.db.QueryRow("SELECT value FROM schema_meta WHERE key='message_queue_v1'").Scan(&migrated)
	if migrated != "1" {
		tx, err := s.db.Begin()
		if err != nil {
			return err
		}
		defer tx.Rollback()
		if _, err = tx.Exec("ALTER TABLE messages ADD COLUMN queue_id TEXT NOT NULL DEFAULT ''"); err != nil {
			return err
		}
		if _, err = tx.Exec("CREATE UNIQUE INDEX messages_queue_role ON messages(queue_id,role) WHERE queue_id<>''"); err != nil {
			return err
		}
		if _, err = tx.Exec("INSERT INTO schema_meta(key,value) VALUES('message_queue_v1','1')"); err != nil {
			return err
		}
		return tx.Commit()
	}
	return nil
}

func nowString() string { return time.Now().UTC().Format(time.RFC3339Nano) }

func newID(prefix string) string {
	buf := make([]byte, 10)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
	}
	return prefix + "-" + hex.EncodeToString(buf)
}

func boolInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func (s *RashinStore) EnsureDefaults(model string) (string, error) {
	var projectID string
	err := s.db.QueryRow("SELECT id FROM projects ORDER BY created_at LIMIT 1").Scan(&projectID)
	if errors.Is(err, sql.ErrNoRows) {
		projectID = newID("project")
		now := nowString()
		if _, err = s.db.Exec("INSERT INTO projects(id,name,created_at,updated_at) VALUES(?,?,?,?)", projectID, "General", now, now); err != nil {
			return "", err
		}
	} else if err != nil {
		return "", err
	}
	var sessionID string
	err = s.db.QueryRow("SELECT id FROM sessions WHERE project_id=? ORDER BY created_at LIMIT 1", projectID).Scan(&sessionID)
	if errors.Is(err, sql.ErrNoRows) {
		sessionID = newID("session")
		now := nowString()
		_, err = s.db.Exec("INSERT INTO sessions(id,project_id,title,created_at,updated_at) VALUES(?,?,?,?,?)", sessionID, projectID, "Nueva conversación", now, now)
	} else if err == nil {
		// The model is deliberately not baked into session names; it can change
		// without making existing conversations look like new ones.
		_ = model
	}
	return sessionID, err
}

func (s *RashinStore) MigrateHistory(entries []HistoryEntry) error {
	var imported string
	_ = s.db.QueryRow("SELECT value FROM schema_meta WHERE key='history_imported_v1'").Scan(&imported)
	if imported == "1" {
		return nil
	}
	if err := s.separateLegacyHistory(); err != nil {
		return err
	}
	if len(entries) == 0 {
		_, err := s.db.Exec("INSERT OR REPLACE INTO schema_meta(key,value) VALUES('history_imported_v1','1')")
		return err
	}
	var count int
	if err := s.db.QueryRow("SELECT COUNT(*) FROM messages").Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		_, err := s.db.Exec("INSERT OR REPLACE INTO schema_meta(key,value) VALUES('history_imported_v1','1')")
		return err
	}
	defaultSession, err := s.EnsureDefaults("")
	if err != nil {
		return err
	}
	var projectID string
	if err := s.db.QueryRow("SELECT project_id FROM sessions WHERE id=?", defaultSession).Scan(&projectID); err != nil {
		return err
	}
	sessionID, err := s.createImportedSession(projectID)
	if err != nil {
		return err
	}
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if _, err = tx.Exec("INSERT INTO messages(id,session_id,role,content,model,created_at) VALUES(?,?,?,?,?,?)", newID("message"), sessionID, "user", entry.Question, entry.Model, entry.At); err != nil {
			tx.Rollback()
			return err
		}
		if _, err = tx.Exec("INSERT INTO messages(id,session_id,role,content,model,created_at) VALUES(?,?,?,?,?,?)", newID("message"), sessionID, "assistant", entry.Answer, entry.Model, entry.At); err != nil {
			tx.Rollback()
			return err
		}
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	_, err = s.db.Exec("INSERT OR REPLACE INTO schema_meta(key,value) VALUES('history_split_v1','1'),('history_imported_v1','1')")
	return err
}

func (s *RashinStore) createImportedSession(projectID string) (string, error) {
	var existing string
	if err := s.db.QueryRow("SELECT id FROM sessions WHERE project_id=? AND title='Historial importado' LIMIT 1", projectID).Scan(&existing); err == nil {
		return existing, nil
	}
	now := nowString()
	id := newID("session")
	_, err := s.db.Exec("INSERT INTO sessions(id,project_id,title,created_at,updated_at) VALUES(?,?,?,?,?)", id, projectID, "Historial importado", now, now)
	return id, err
}

// Versions created before SQLite stored the JSONL history in the first
// "Nueva conversación". Move that legacy transcript once so a new chat opens
// cleanly while keeping the old answers searchable in their own session.
func (s *RashinStore) separateLegacyHistory() error {
	var marker string
	_ = s.db.QueryRow("SELECT value FROM schema_meta WHERE key='history_split_v1'").Scan(&marker)
	if marker == "1" {
		return nil
	}
	var sessionID, projectID, title string
	var count int
	err := s.db.QueryRow("SELECT id,project_id,title FROM sessions ORDER BY created_at,rowid LIMIT 1").Scan(&sessionID, &projectID, &title)
	if err == nil && title == "Nueva conversación" {
		if err := s.db.QueryRow("SELECT COUNT(*) FROM messages WHERE session_id=?", sessionID).Scan(&count); err != nil {
			return err
		}
		if count > 0 {
			imported, err := s.createImportedSession(projectID)
			if err != nil {
				return err
			}
			if _, err := s.db.Exec("UPDATE messages SET session_id=? WHERE session_id=?", imported, sessionID); err != nil {
				return err
			}
		}
	}
	_, err = s.db.Exec("INSERT INTO schema_meta(key,value) VALUES('history_split_v1','1') ON CONFLICT(key) DO UPDATE SET value='1'")
	return err
}

func (s *RashinStore) Projects(includeArchived bool) ([]ProjectRecord, error) {
	query := "SELECT id,name,description,pinned,archived,created_at,updated_at FROM projects"
	if !includeArchived {
		query += " WHERE archived=0"
	}
	query += " ORDER BY pinned DESC, updated_at DESC"
	rows, err := s.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []ProjectRecord{}
	for rows.Next() {
		var p ProjectRecord
		var pin, arch int
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &pin, &arch, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		p.Pinned = pin != 0
		p.Archived = arch != 0
		items = append(items, p)
	}
	return items, rows.Err()
}

func (s *RashinStore) Sessions(projectID, search string, includeArchived bool) ([]SessionRecord, error) {
	query := "SELECT id,project_id,title,pinned,archived,status,created_at,updated_at FROM sessions WHERE 1=1"
	args := []any{}
	if projectID != "" {
		query += " AND project_id=?"
		args = append(args, projectID)
	}
	if !includeArchived {
		query += " AND archived=0"
	}
	if search != "" {
		query += " AND title LIKE ?"
		args = append(args, "%"+search+"%")
	}
	query += " ORDER BY pinned DESC, updated_at DESC"
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []SessionRecord{}
	for rows.Next() {
		var item SessionRecord
		var pin, arch int
		if err := rows.Scan(&item.ID, &item.ProjectID, &item.Title, &pin, &arch, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		item.Pinned = pin != 0
		item.Archived = arch != 0
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *RashinStore) CreateProject(name, description string) (ProjectRecord, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		name = "Nuevo proyecto"
	}
	now := nowString()
	item := ProjectRecord{ID: newID("project"), Name: name, Description: strings.TrimSpace(description), CreatedAt: now, UpdatedAt: now}
	_, err := s.db.Exec("INSERT INTO projects(id,name,description,created_at,updated_at) VALUES(?,?,?,?,?)", item.ID, item.Name, item.Description, now, now)
	return item, err
}

func (s *RashinStore) UpdateProject(id, name, description string, archived, pinned *bool) error {
	var current ProjectRecord
	rows, err := s.Projects(true)
	if err != nil {
		return err
	}
	for _, item := range rows {
		if item.ID == id {
			current = item
			break
		}
	}
	if current.ID == "" {
		return errors.New("project not found")
	}
	if name != "" {
		current.Name = strings.TrimSpace(name)
		if current.Name == "" {
			return errors.New("el nombre del proyecto no puede estar vacío")
		}
	}
	if description != "" {
		current.Description = strings.TrimSpace(description)
	}
	if archived != nil {
		current.Archived = *archived
	}
	if pinned != nil {
		current.Pinned = *pinned
	}
	_, err = s.db.Exec("UPDATE projects SET name=?,description=?,archived=?,pinned=?,updated_at=? WHERE id=?", current.Name, current.Description, boolInt(current.Archived), boolInt(current.Pinned), nowString(), id)
	return err
}

func (s *RashinStore) DeleteProject(id string) error {
	var name string
	if err := s.db.QueryRow("SELECT name FROM projects WHERE id=?", id).Scan(&name); err != nil {
		return err
	}
	if name == "General" {
		return errors.New("no se puede borrar el proyecto General")
	}
	_, err := s.db.Exec("DELETE FROM projects WHERE id=?", id)
	return err
}

func (s *RashinStore) CreateSession(projectID, title string) (SessionRecord, error) {
	if projectID == "" {
		if err := s.db.QueryRow("SELECT project_id FROM sessions ORDER BY created_at LIMIT 1").Scan(&projectID); err != nil {
			if _, ensureErr := s.EnsureDefaults(""); ensureErr != nil {
				return SessionRecord{}, ensureErr
			}
			if err := s.db.QueryRow("SELECT project_id FROM sessions ORDER BY created_at LIMIT 1").Scan(&projectID); err != nil {
				return SessionRecord{}, err
			}
		}
	}
	var exists int
	if err := s.db.QueryRow("SELECT COUNT(*) FROM projects WHERE id=?", projectID).Scan(&exists); err != nil || exists == 0 {
		return SessionRecord{}, errors.New("project not found")
	}
	title = strings.TrimSpace(title)
	if title == "" {
		title = "Nueva conversación"
	}
	now := nowString()
	item := SessionRecord{ID: newID("session"), ProjectID: projectID, Title: title, Status: "idle", CreatedAt: now, UpdatedAt: now}
	_, err := s.db.Exec("INSERT INTO sessions(id,project_id,title,created_at,updated_at) VALUES(?,?,?,?,?)", item.ID, item.ProjectID, item.Title, now, now)
	return item, err
}

func (s *RashinStore) UpdateSession(id, title string, archived, pinned *bool) error {
	var current SessionRecord
	rows, err := s.Sessions("", "", true)
	if err != nil {
		return err
	}
	for _, item := range rows {
		if item.ID == id {
			current = item
			break
		}
	}
	if current.ID == "" {
		return errors.New("session not found")
	}
	if title != "" {
		current.Title = strings.TrimSpace(title)
		if current.Title == "" {
			return errors.New("el nombre de la sesión no puede estar vacío")
		}
	}
	if archived != nil {
		current.Archived = *archived
	}
	if pinned != nil {
		current.Pinned = *pinned
	}
	_, err = s.db.Exec("UPDATE sessions SET title=?,archived=?,pinned=?,updated_at=? WHERE id=?", current.Title, boolInt(current.Archived), boolInt(current.Pinned), nowString(), id)
	return err
}

func (s *RashinStore) DeleteSession(id string) error {
	result, err := s.db.Exec("DELETE FROM sessions WHERE id=?", id)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return errors.New("session not found")
	}
	return nil
}

func decodeIDs(value string) []string {
	var ids []string
	_ = json.Unmarshal([]byte(value), &ids)
	return ids
}
func encodeIDs(ids []string) string { data, _ := json.Marshal(ids); return string(data) }

func (s *RashinStore) AddMessage(sessionID, role, content, model, state string, attachments []string) (MessageRecord, error) {
	if state == "" {
		state = "completed"
	}
	now := nowString()
	item := MessageRecord{ID: newID("message"), SessionID: sessionID, Role: role, Content: content, Model: model, State: state, CreatedAt: now, Attachments: attachments}
	_, err := s.db.Exec("INSERT INTO messages(id,session_id,role,content,model,state,attachments_json,created_at) VALUES(?,?,?,?,?,?,?,?)", item.ID, sessionID, role, content, model, state, encodeIDs(attachments), now)
	if err == nil {
		_, _ = s.db.Exec("UPDATE sessions SET updated_at=? WHERE id=?", now, sessionID)
	}
	return item, err
}

func (s *RashinStore) Messages(sessionID string, limit int) ([]MessageRecord, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	rows, err := s.db.Query("SELECT rowid,id,session_id,role,content,model,state,attachments_json,created_at,queue_id FROM messages WHERE session_id=? ORDER BY created_at DESC,rowid DESC LIMIT ?", sessionID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []MessageRecord{}
	sequence := map[string]int64{}
	for rows.Next() {
		var item MessageRecord
		var rowid int64
		var ids string
		if err := rows.Scan(&rowid, &item.ID, &item.SessionID, &item.Role, &item.Content, &item.Model, &item.State, &ids, &item.CreatedAt, &item.QueueID); err != nil {
			return nil, err
		}
		item.Attachments = decodeIDs(ids)
		items = append(items, item)
		sequence[item.ID] = rowid
	}
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].CreatedAt == items[j].CreatedAt {
			return sequence[items[i].ID] < sequence[items[j].ID]
		}
		return items[i].CreatedAt < items[j].CreatedAt
	})
	return items, rows.Err()
}

func (s *RashinStore) Enqueue(sessionID, prompt, mode, profile string, fast bool, attachments []string) (QueueRecord, error) {
	var pending int
	if err := s.db.QueryRow("SELECT COUNT(*) FROM queue_items WHERE session_id=? AND status IN ('queued','running')", sessionID).Scan(&pending); err != nil {
		return QueueRecord{}, err
	}
	if pending >= 20 {
		return QueueRecord{}, errors.New("la cola de esta sesión está llena (máximo 20 mensajes)")
	}
	now := nowString()
	var pos int
	_ = s.db.QueryRow("SELECT COALESCE(MAX(position),0)+1 FROM queue_items WHERE session_id=? AND status IN ('queued','running')", sessionID).Scan(&pos)
	item := QueueRecord{ID: newID("queue"), SessionID: sessionID, Prompt: prompt, Mode: mode, ModelProfile: profile, FastMode: fast, Status: "queued", Position: pos, AttachmentIDs: attachments, CreatedAt: now}
	_, err := s.db.Exec("INSERT INTO queue_items(id,session_id,prompt,mode,model_profile,fast_mode,status,position,attachment_ids_json,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)", item.ID, sessionID, prompt, mode, profile, boolInt(fast), item.Status, pos, encodeIDs(attachments), now)
	return item, err
}

func (s *RashinStore) QueueStatus(id string) string {
	var status string
	if err := s.db.QueryRow("SELECT status FROM queue_items WHERE id=?", id).Scan(&status); err != nil {
		return "missing"
	}
	return status
}

func (s *RashinStore) Queue(sessionID string) ([]QueueRecord, error) {
	query := "SELECT id,session_id,prompt,mode,model_profile,fast_mode,status,position,attachment_ids_json,error,created_at,started_at,finished_at FROM queue_items WHERE status IN ('queued','running','interrupted')"
	args := []any{}
	if sessionID != "" {
		query += " AND session_id=?"
		args = append(args, sessionID)
	}
	query += " ORDER BY created_at"
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []QueueRecord{}
	for rows.Next() {
		var item QueueRecord
		var fast int
		var ids string
		if err := rows.Scan(&item.ID, &item.SessionID, &item.Prompt, &item.Mode, &item.ModelProfile, &fast, &item.Status, &item.Position, &ids, &item.Error, &item.CreatedAt, &item.StartedAt, &item.FinishedAt); err != nil {
			return nil, err
		}
		item.FastMode = fast != 0
		item.AttachmentIDs = decodeIDs(ids)
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *RashinStore) SetQueueStatus(id, status, message string) error {
	now := nowString()
	_, err := s.db.Exec("UPDATE queue_items SET status=?,error=?,started_at=CASE WHEN ?='running' AND started_at='' THEN ? ELSE started_at END,finished_at=CASE WHEN ? IN ('completed','failed','cancelled','interrupted') THEN ? ELSE finished_at END WHERE id=?", status, message, status, now, status, now, id)
	return err
}

func (s *RashinStore) InterruptRunningQueue() error {
	_, err := s.db.Exec("UPDATE queue_items SET status='interrupted', error='El daemon se reinició antes de terminar', finished_at=? WHERE status IN ('running','queued')", nowString())
	return err
}

func (s *RashinStore) UpsertModel(item ModelProfileRecord) error {
	_, err := s.db.Exec("INSERT INTO model_profiles(id,name,tier,model_id,path,context_tokens,installed,active,size,source,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,tier=excluded.tier,model_id=excluded.model_id,path=excluded.path,context_tokens=excluded.context_tokens,installed=excluded.installed,active=excluded.active,size=excluded.size,source=excluded.source,updated_at=excluded.updated_at", item.ID, item.Name, item.Tier, item.ModelID, item.Path, item.ContextTokens, boolInt(item.Installed), boolInt(item.Active), item.Size, item.Source, nowString())
	return err
}
func (s *RashinStore) Models() ([]ModelProfileRecord, error) {
	rows, err := s.db.Query("SELECT id,name,tier,model_id,path,context_tokens,installed,active,size,source FROM model_profiles ORDER BY installed DESC,tier")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []ModelProfileRecord{}
	for rows.Next() {
		var item ModelProfileRecord
		var installed, active int
		if err := rows.Scan(&item.ID, &item.Name, &item.Tier, &item.ModelID, &item.Path, &item.ContextTokens, &installed, &active, &item.Size, &item.Source); err != nil {
			return nil, err
		}
		item.Installed = installed != 0
		item.Active = active != 0
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *RashinStore) PruneModels(ids []string) error {
	if len(ids) == 0 {
		return nil
	}
	placeholders := make([]string, len(ids))
	args := make([]any, len(ids))
	for i, id := range ids {
		placeholders[i] = "?"
		args[i] = id
	}
	_, err := s.db.Exec("DELETE FROM model_profiles WHERE source='local' AND id NOT IN ("+strings.Join(placeholders, ",")+")", args...)
	return err
}

func (s *RashinStore) CreateModelDownload(item ModelDownloadRecord) error {
	_, err := s.db.Exec("INSERT INTO model_downloads(id,url,name,tier,path,status,progress,bytes,total,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)", item.ID, item.URL, item.Name, item.Tier, item.Path, item.Status, item.Progress, item.Bytes, item.Total, item.CreatedAt, item.UpdatedAt)
	return err
}

func (s *RashinStore) UpdateModelDownload(id, status, message string, progress float64, bytes, total int64) error {
	_, err := s.db.Exec("UPDATE model_downloads SET status=?,error=?,progress=?,bytes=?,total=?,updated_at=? WHERE id=?", status, message, progress, bytes, total, nowString(), id)
	return err
}

func (s *RashinStore) ModelDownloads() ([]ModelDownloadRecord, error) {
	rows, err := s.db.Query("SELECT id,url,name,tier,path,status,progress,bytes,total,error,created_at,updated_at FROM model_downloads ORDER BY created_at DESC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []ModelDownloadRecord{}
	for rows.Next() {
		var item ModelDownloadRecord
		if err := rows.Scan(&item.ID, &item.URL, &item.Name, &item.Tier, &item.Path, &item.Status, &item.Progress, &item.Bytes, &item.Total, &item.Error, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
func (s *RashinStore) ActivateModel(id string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	if _, err = tx.Exec("UPDATE model_profiles SET active=0"); err != nil {
		tx.Rollback()
		return err
	}
	if _, err = tx.Exec("UPDATE model_profiles SET active=1,updated_at=? WHERE id=?", nowString(), id); err != nil {
		tx.Rollback()
		return err
	}
	return tx.Commit()
}

func (s *RashinStore) MemoryCandidates(status string) ([]MemoryCandidateRecord, error) {
	query := "SELECT id,content,source,status,created_at,updated_at FROM memory_candidates"
	args := []any{}
	if status != "" {
		query += " WHERE status=?"
		args = append(args, status)
	}
	query += " ORDER BY created_at DESC"
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []MemoryCandidateRecord{}
	for rows.Next() {
		var item MemoryCandidateRecord
		if err := rows.Scan(&item.ID, &item.Content, &item.Source, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
func (s *RashinStore) AddMemoryCandidate(content, source string) (MemoryCandidateRecord, error) {
	var existing string
	if err := s.db.QueryRow("SELECT id FROM memory_candidates WHERE content=? AND status='pending' LIMIT 1", strings.TrimSpace(content)).Scan(&existing); err == nil {
		var item MemoryCandidateRecord
		_ = s.db.QueryRow("SELECT id,content,source,status,created_at,updated_at FROM memory_candidates WHERE id=?", existing).Scan(&item.ID, &item.Content, &item.Source, &item.Status, &item.CreatedAt, &item.UpdatedAt)
		return item, nil
	}
	now := nowString()
	item := MemoryCandidateRecord{ID: newID("memory"), Content: strings.TrimSpace(content), Source: source, Status: "pending", CreatedAt: now, UpdatedAt: now}
	_, err := s.db.Exec("INSERT INTO memory_candidates(id,content,source,status,created_at,updated_at) VALUES(?,?,?,?,?,?)", item.ID, item.Content, item.Source, item.Status, now, now)
	return item, err
}
func (s *RashinStore) SetMemoryStatus(id, status string) error {
	_, err := s.db.Exec("UPDATE memory_candidates SET status=?,updated_at=? WHERE id=?", status, nowString(), id)
	return err
}

func (s *RashinStore) UserProfile() (string, error) {
	var content string
	err := s.db.QueryRow("SELECT content FROM user_profile WHERE id=1").Scan(&content)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return content, err
}

func (s *RashinStore) SaveUserProfile(content string) error {
	_, err := s.db.Exec("INSERT INTO user_profile(id,content,updated_at) VALUES(1,?,?) ON CONFLICT(id) DO UPDATE SET content=excluded.content,updated_at=excluded.updated_at", strings.TrimSpace(content), nowString())
	return err
}

func validAttachment(name, contentType string) bool {
	ext := strings.ToLower(filepath.Ext(name))
	allowed := map[string]bool{".txt": true, ".md": true, ".markdown": true, ".json": true, ".yaml": true, ".yml": true, ".toml": true, ".csv": true, ".go": true, ".qml": true, ".js": true, ".ts": true, ".py": true, ".sh": true, ".c": true, ".h": true, ".cpp": true, ".rs": true, ".pdf": true, ".doc": true, ".docx": true, ".odt": true, ".png": true, ".jpg": true, ".jpeg": true, ".webp": true, ".gif": true, ".mp4": true, ".webm": true, ".mkv": true, ".mov": true, ".avi": true}
	if allowed[ext] {
		return true
	}
	if contentType != "" {
		base, _, _ := mime.ParseMediaType(contentType)
		return strings.HasPrefix(base, "text/") || base == "application/pdf" || strings.HasPrefix(base, "image/")
	}
	return false
}
