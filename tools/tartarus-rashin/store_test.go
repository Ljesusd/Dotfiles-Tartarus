package main

import (
	"path/filepath"
	"testing"
)

func TestRashinStoreCreatesWorkspaceAndMigratesHistory(t *testing.T) {
	store, err := OpenRashinStore(filepath.Join(t.TempDir(), "rashin.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	if err := store.MigrateHistory([]HistoryEntry{{At: "2026-01-01T00:00:00Z", Question: "¿Qué GPU tengo?", Answer: "AMD", Model: "local"}}); err != nil {
		t.Fatal(err)
	}
	if _, err := store.EnsureDefaults("local"); err != nil {
		t.Fatal(err)
	}
	projects, err := store.Projects(false)
	if err != nil || len(projects) != 1 || projects[0].Name != "General" {
		t.Fatalf("projects=%+v err=%v", projects, err)
	}
	sessions, err := store.Sessions("", "", false)
	if err != nil || len(sessions) != 2 {
		t.Fatalf("sessions=%+v err=%v", sessions, err)
	}
	var importedID string
	for _, session := range sessions {
		if session.Title == "Historial importado" {
			importedID = session.ID
		}
	}
	if importedID == "" {
		t.Fatalf("no imported session: %+v", sessions)
	}
	messages, err := store.Messages(importedID, 20)
	if err != nil || len(messages) != 2 || !((messages[0].Role == "user" && messages[1].Role == "assistant") || (messages[0].Role == "assistant" && messages[1].Role == "user")) {
		t.Fatalf("messages=%+v err=%v", messages, err)
	}
}

func TestRashinStoreQueueLimitAndCancellation(t *testing.T) {
	store, err := OpenRashinStore(filepath.Join(t.TempDir(), "rashin.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	if _, err := store.EnsureDefaults("local"); err != nil {
		t.Fatal(err)
	}
	sessions, _ := store.Sessions("", "", false)
	for i := 0; i < 20; i++ {
		if _, err := store.Enqueue(sessions[0].ID, "prompt", "auto", "", false, nil); err != nil {
			t.Fatalf("enqueue %d: %v", i, err)
		}
	}
	if _, err := store.Enqueue(sessions[0].ID, "overflow", "auto", "", false, nil); err == nil {
		t.Fatal("expected queue limit")
	}
	items, err := store.Queue(sessions[0].ID)
	if err != nil || len(items) != 20 {
		t.Fatalf("queue=%d err=%v", len(items), err)
	}
	if err := store.SetQueueStatus(items[0].ID, "cancelled", "test"); err != nil {
		t.Fatal(err)
	}
	if got := store.QueueStatus(items[0].ID); got != "cancelled" {
		t.Fatalf("status=%q", got)
	}
}
