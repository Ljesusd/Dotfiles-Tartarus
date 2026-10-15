package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// This is the small ACP bridge Tartarus needs. It deliberately keeps the
// protocol boundary separate from the QML and HTTP code: Hermes remains an
// optional agent, while llama-server remains the fast local model.
type acpRPC struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      *int64          `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *acpError       `json:"error,omitempty"`
}

type acpError struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data,omitempty"`
}

var contextWindowError = regexp.MustCompile(`context window of ([0-9,]+) tokens, which is below the minimum ([0-9,]+)`)

func (e *acpError) description() string {
	message := e.Message
	// Hermes puts actionable failures in data.details, leaving the JSON-RPC
	// message as "Internal error". Do not dump arbitrary error data/tracebacks.
	var data struct {
		Details string `json:"details"`
	}
	if json.Unmarshal(e.Data, &data) == nil && strings.TrimSpace(data.Details) != "" {
		message = strings.TrimSpace(data.Details)
	}
	if match := contextWindowError.FindStringSubmatch(message); len(match) == 3 {
		return fmt.Sprintf("Hermes no puede iniciar: el contexto configurado es de %s tokens y necesita al menos %s. Hay que ampliar el contexto real de llama-server y ajustar Hermes al mismo valor; no basta con cambiar el número en Hermes. No se ejecutó ningún comando.",
			strings.ReplaceAll(match[1], ",", "."), strings.ReplaceAll(match[2], ",", "."))
	}
	if message == "" {
		message = "Error sin descripción"
	}
	return message
}

type acpEvent struct {
	Type      string
	Text      string
	Title     string
	ToolID    string
	ToolState string
	RequestID string
	RPCID     int64
	Options   []PermOption
}

type acpClient struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout io.ReadCloser

	writeMu   sync.Mutex
	mu        sync.Mutex
	nextID    atomic.Int64
	pending   map[int64]chan acpRPC
	sessionID string
	closed    bool
	events    chan acpEvent
}

func startACP(vault string) (*acpClient, error) {
	hermes := findLocalBinary("hermes")
	if hermes == "" {
		return nil, errors.New("hermes no está instalado")
	}
	cmd := exec.Command(hermes, "acp")
	cmd.Dir = vault
	cmd.Stderr = os.Stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	c := &acpClient{
		cmd: cmd, stdin: stdin, stdout: stdout,
		pending: map[int64]chan acpRPC{}, events: make(chan acpEvent, 128),
	}
	go c.readLoop()
	return c, nil
}

func (c *acpClient) send(value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_, err = c.stdin.Write(append(data, '\n'))
	return err
}

func (c *acpClient) request(method string, params any) (json.RawMessage, error) {
	id := c.nextID.Add(1)
	result := make(chan acpRPC, 1)
	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return nil, errors.New("ACP cerrado")
	}
	c.pending[id] = result
	c.mu.Unlock()
	if err := c.send(acpRPC{JSONRPC: "2.0", ID: &id, Method: method, Params: mustJSON(params)}); err != nil {
		c.mu.Lock()
		delete(c.pending, id)
		c.mu.Unlock()
		return nil, err
	}
	timeout := 90 * time.Second
	// A Hermes turn can legitimately include several web/browser calls and a
	// long local generation. The old fixed 90s deadline surfaced as
	// "timeout esperando ACP session/prompt" while the agent was still working.
	if method == "session/prompt" {
		timeout = 10 * time.Minute
	}
	select {
	case response := <-result:
		if response.Error != nil {
			return nil, fmt.Errorf("ACP %s: %s", method, response.Error.description())
		}
		return response.Result, nil
	case <-time.After(timeout):
		return nil, fmt.Errorf("timeout esperando ACP %s", method)
	}
}

func (c *acpClient) notify(method string, params any) {
	_ = c.send(acpRPC{JSONRPC: "2.0", Method: method, Params: mustJSON(params)})
}

func (c *acpClient) respond(id int64, optionID string) {
	result := map[string]any{"outcome": map[string]any{"outcome": "cancelled"}}
	if optionID != "" {
		result = map[string]any{"outcome": map[string]any{"outcome": "selected", "optionId": optionID}}
	}
	_ = c.send(acpRPC{JSONRPC: "2.0", ID: &id, Result: mustJSON(result)})
}

func (c *acpClient) initialize(vault string) error {
	if _, err := c.request("initialize", map[string]any{
		"protocolVersion":    1,
		"clientCapabilities": map[string]any{"fs": map[string]bool{"readTextFile": false, "writeTextFile": false}, "terminal": false},
		"clientInfo":         map[string]string{"name": "tartarus-rashin", "title": "Tartarus Rashin", "version": "1"},
	}); err != nil {
		return err
	}
	result, err := c.request("session/new", map[string]any{"cwd": vault, "mcpServers": []any{}})
	if err != nil {
		return err
	}
	var session struct {
		SessionID string `json:"sessionId"`
	}
	if json.Unmarshal(result, &session) != nil || session.SessionID == "" {
		return errors.New("ACP no devolvió una sesión")
	}
	c.mu.Lock()
	// Store the session id as an event-free field using the pending map key -
	// the prompt method reads it from this private field below.
	c.sessionID = session.SessionID
	c.mu.Unlock()
	return nil
}

func (c *acpClient) prompt(text string) {
	c.mu.Lock()
	sessionID := c.sessionID
	c.mu.Unlock()
	go func() {
		_, err := c.request("session/prompt", map[string]any{
			"sessionId": sessionID,
			"prompt":    []map[string]string{{"type": "text", "text": text}},
		})
		if err != nil {
			c.emitEvent(acpEvent{Type: "error", Text: err.Error()})
			return
		}
		c.emitEvent(acpEvent{Type: "turn_end"})
	}()
}

func (c *acpClient) cancel() {
	c.mu.Lock()
	id := c.sessionID
	c.mu.Unlock()
	c.notify("session/cancel", map[string]string{"sessionId": id})
}

func (c *acpClient) close() {
	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return
	}
	c.closed = true
	for id, channel := range c.pending {
		channel <- acpRPC{Error: &acpError{Code: -1, Message: "ACP cerrado"}}
		delete(c.pending, id)
	}
	c.mu.Unlock()
	_ = c.stdin.Close()
	_ = c.stdout.Close()
	_ = c.cmd.Process.Kill()
}

func (c *acpClient) emitEvent(event acpEvent) {
	c.mu.Lock()
	closed := c.closed
	c.mu.Unlock()
	if closed {
		return
	}
	select {
	case c.events <- event:
	default:
		// A slow dashboard must not block ACP's protocol reader forever.
	}
}

func (c *acpClient) readLoop() {
	scanner := bufio.NewScanner(c.stdout)
	scanner.Buffer(make([]byte, 4096), 4<<20)
	for scanner.Scan() {
		var message acpRPC
		if json.Unmarshal(scanner.Bytes(), &message) != nil {
			continue
		}
		if message.ID != nil && message.Method == "" {
			c.mu.Lock()
			pending := c.pending[*message.ID]
			delete(c.pending, *message.ID)
			c.mu.Unlock()
			if pending != nil {
				pending <- message
			}
			continue
		}
		c.handleNotification(message)
	}
	c.mu.Lock()
	closed := c.closed
	c.mu.Unlock()
	if !closed {
		c.emitEvent(acpEvent{Type: "error", Text: "Hermes cerró ACP"})
	}
}

func (c *acpClient) handleNotification(message acpRPC) {
	if message.Method == "session/request_permission" {
		var payload struct {
			ToolCall struct {
				Title string `json:"title"`
			} `json:"toolCall"`
			Options []struct {
				OptionID string `json:"optionId"`
				ID       string `json:"id"`
				Name     string `json:"name"`
				Kind     string `json:"kind"`
			} `json:"options"`
		}
		_ = json.Unmarshal(message.Params, &payload)
		id := int64(0)
		if message.ID != nil {
			id = *message.ID
		}
		options := make([]PermOption, 0, len(payload.Options))
		for _, option := range payload.Options {
			optionID := option.OptionID
			if optionID == "" {
				optionID = option.ID
			}
			options = append(options, PermOption{ID: optionID, Name: option.Name, Kind: option.Kind})
		}
		c.emitEvent(acpEvent{Type: "permission", Title: payload.ToolCall.Title, Options: options, RPCID: id, RequestID: strconv.FormatInt(id, 10)})
		return
	}
	if message.Method != "session/update" {
		return
	}
	var payload struct {
		Update struct {
			SessionUpdate string `json:"sessionUpdate"`
			Content       struct {
				Text string `json:"text"`
			} `json:"content"`
			ToolCallID string `json:"toolCallId"`
			Title      string `json:"title"`
			Status     string `json:"status"`
		} `json:"update"`
	}
	if json.Unmarshal(message.Params, &payload) != nil {
		return
	}
	u := payload.Update
	switch u.SessionUpdate {
	case "agent_message_chunk":
		c.emitEvent(acpEvent{Type: "delta", Text: u.Content.Text})
	case "agent_thought_chunk":
		c.emitEvent(acpEvent{Type: "thought", Text: u.Content.Text})
	case "tool_call", "tool_call_update":
		c.emitEvent(acpEvent{Type: "tool", ToolID: u.ToolCallID, Title: u.Title, ToolState: u.Status})
	}
}

func mustJSON(value any) json.RawMessage {
	data, _ := json.Marshal(value)
	return data
}

func (s *Server) runHermes(ctx context.Context, question string, emit func(ChatEvent)) (string, error) {
	client, err := startACP(s.cfg.VaultPath)
	if err != nil {
		return "", fmt.Errorf("no se pudo iniciar Hermes ACP: %w", err)
	}
	defer client.close()
	if err := client.initialize(s.cfg.VaultPath); err != nil {
		return "", err
	}
	emit(ChatEvent{Type: "state", State: "hermes", Model: "Hermes + " + modelLabel(s.cfg.Model)})
	client.prompt(question)
	go func() {
		<-ctx.Done()
		client.cancel()
	}()
	var answer strings.Builder
	for {
		select {
		case <-ctx.Done():
			return "", errors.New("consulta cancelada")
		case event, ok := <-client.events:
			if !ok {
				return "", errors.New("Hermes cerró la sesión")
			}
			switch event.Type {
			case "delta":
				answer.WriteString(event.Text)
				emit(ChatEvent{Type: "delta", Text: event.Text})
			case "thought":
				emit(ChatEvent{Type: "working", Text: "Hermes está razonando"})
			case "tool":
				emit(ChatEvent{Type: "tool", ToolID: event.ToolID, Title: event.Title, ToolState: event.ToolState})
			case "permission":
				waiter := make(chan bool, 1)
				s.mu.Lock()
				s.permissions[event.RequestID] = waiter
				s.mu.Unlock()
				emit(ChatEvent{Type: "permission", RequestID: event.RequestID, Title: event.Title, Options: event.Options})
				allowed := false
				select {
				case allowed = <-waiter:
				case <-ctx.Done():
				}
				s.mu.Lock()
				delete(s.permissions, event.RequestID)
				s.mu.Unlock()
				if allowed && len(event.Options) > 0 {
					client.respond(event.RPCID, event.Options[0].ID)
				} else {
					client.respond(event.RPCID, "")
				}
			case "error":
				return "", errors.New(event.Text)
			case "turn_end":
				result := strings.TrimSpace(answer.String())
				if result == "" {
					return "", errors.New("Hermes no devolvió una respuesta")
				}
				return result, nil
			}
		}
	}
}
