package main

import (
	"encoding/json"
	"net/http/httptest"
	"path/filepath"
	"testing"
)

func TestDeleteDefaultSessionCreatesFallback(t *testing.T) {
	store, err := OpenRashinStore(filepath.Join(t.TempDir(), "rashin.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	defaultID, err := store.EnsureDefaults("local")
	if err != nil {
		t.Fatal(err)
	}
	server := &Server{store: store, defaultSession: defaultID, cfg: Config{Model: "local"}}
	request := httptest.NewRequest("DELETE", "/api/sessions/"+defaultID, nil)
	request.SetPathValue("id", defaultID)
	recorder := httptest.NewRecorder()
	server.handleDeleteSession(recorder, request)
	if recorder.Code != 200 {
		t.Fatalf("status=%d body=%s", recorder.Code, recorder.Body.String())
	}
	var response map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response["ok"] != true || response["defaultSessionId"] == defaultID {
		t.Fatalf("response=%v", response)
	}
	sessions, err := store.Sessions("", "", false)
	if err != nil || len(sessions) != 1 || sessions[0].ID == defaultID {
		t.Fatalf("sessions=%+v err=%v", sessions, err)
	}
}
