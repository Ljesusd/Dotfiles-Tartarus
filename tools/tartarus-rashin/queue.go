package main

import (
	"errors"
	"fmt"
)

func (s *RashinStore) SessionExists(id string) bool {
	var count int
	return s.db.QueryRow("SELECT COUNT(*) FROM sessions WHERE id=?", id).Scan(&count) == nil && count == 1
}

// One durable message per role/turn makes a recovered stream and a resumed
// interrupted request idempotent. Legacy messages keep an empty queue_id.
func (s *RashinStore) AddTurnMessage(sessionID, queueID, role, content, model, state string, attachments []string) error {
	if queueID == "" {
		_, err := s.AddMessage(sessionID, role, content, model, state, attachments)
		return err
	}
	_, err := s.db.Exec(`INSERT INTO messages(id,session_id,role,content,model,state,attachments_json,created_at,queue_id)
		VALUES(?,?,?,?,?,?,?,?,?)
		ON CONFLICT(queue_id,role) WHERE queue_id<>'' DO UPDATE SET content=excluded.content,state=excluded.state`,
		newID("message"), sessionID, role, content, model, state, encodeIDs(attachments), nowString(), queueID)
	if err == nil {
		_, _ = s.db.Exec("UPDATE sessions SET updated_at=? WHERE id=?", nowString(), sessionID)
	}
	return err
}

func (s *Server) sessionConversation(sessionID, excludeQueue string) []ConversationTurn {
	if s.store == nil {
		return nil
	}
	messages, err := s.store.Messages(sessionID, maxConversationTurns+2)
	if err != nil {
		return nil
	}
	turns := []ConversationTurn{}
	for _, message := range messages {
		if (excludeQueue != "" && message.QueueID == excludeQueue) || message.State != "completed" {
			continue
		}
		role := "Rashin"
		if message.Role == "user" {
			role = "Usuario"
		}
		turns = append(turns, ConversationTurn{Role: role, Content: message.Content})
	}
	if len(turns) > maxConversationTurns {
		turns = turns[len(turns)-maxConversationTurns:]
	}
	return turns
}

func (s *Server) defaultSessionID() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.store == nil {
		return s.defaultSession, nil
	}
	if s.store.SessionExists(s.defaultSession) {
		return s.defaultSession, nil
	}
	id, err := s.store.EnsureDefaults(s.cfg.Model)
	if err == nil {
		s.defaultSession = id
	}
	return id, err
}

func (s *Server) queueEvent(request *queuedSocketRequest, event ChatEvent) {
	event.QueueID = request.queueID
	event.SessionID = request.sessionID
	event.ClientID = request.clientID
	// All open dashboards can observe a turn after reconnecting. Consumers
	// filter by session/queue ID; permissions retain their separate requestId.
	s.broadcast(event)
}

func (s *Server) queuedLocked(id string) bool {
	if id == "" {
		return false
	}
	if s.activeQueueID == id {
		return true
	}
	for _, request := range s.queued {
		if request.queueID == id {
			return true
		}
	}
	return false
}

func (s *Server) validateAttachments(sessionID string, ids []string) error {
	if s.store == nil {
		return nil
	}
	for _, id := range ids {
		var owner string
		if err := s.store.db.QueryRow("SELECT session_id FROM attachments WHERE id=?", id).Scan(&owner); err != nil || owner != sessionID {
			return errors.New("el adjunto no pertenece a esta sesión")
		}
	}
	return nil
}

func (s *Server) attachmentPaths(sessionIDs []string) ([]string, error) {
	paths := []string{}
	for _, id := range sessionIDs {
		rows, err := s.store.db.Query("SELECT path FROM attachments WHERE session_id=?", id)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var path string
			if err := rows.Scan(&path); err != nil {
				rows.Close()
				return nil, err
			}
			// Only uploaded files, never arbitrary vault files, may be removed.
			if len(path) < len("attachments/") || path[:len("attachments/")] != "attachments/" {
				rows.Close()
				return nil, fmt.Errorf("ruta de adjunto inválida")
			}
			paths = append(paths, path)
		}
		err = rows.Err()
		rows.Close()
		if err != nil {
			return nil, err
		}
	}
	return paths, nil
}
