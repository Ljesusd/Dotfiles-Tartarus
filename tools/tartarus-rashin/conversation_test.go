package main

import (
	"strings"
	"testing"
)

func TestConversationPromptKeepsShortFollowUpContext(t *testing.T) {
	got := conversationPrompt("Hazlo", []ConversationTurn{
		{Role: "Usuario", Content: "¿Puedes comprobar la GPU?"},
		{Role: "Rashin", Content: "Puedo ejecutar lspci y consultar el modelo AMD."},
	})
	if !strings.Contains(got, "Puedo ejecutar lspci") || !strings.Contains(got, "MENSAJE ACTUAL DEL USUARIO:\nHazlo") {
		t.Fatalf("conversation context was lost: %q", got)
	}
}

func TestActionConfirmationUsesHermes(t *testing.T) {
	previous := []ConversationTurn{{Role: "Rashin", Content: "¿Quieres que instale y ejecute radeontop?"}}
	for _, question := range []string{"Sí", "ok", "Hazlo"} {
		if !needsSession(question, previous) {
			t.Fatalf("%q should use the action lane", question)
		}
	}
	if needsSession("¿Qué GPU tengo?", previous) {
		t.Fatal("a read-only question should not require the action lane")
	}
}

func TestCurrentQuestionsUseHermesWebLane(t *testing.T) {
	for _, question := range []string{
		"Busca en Wikipedia quién es el presidente actual de Brasil",
		"¿Cuáles son las últimas noticias sobre Linux?",
		"What is the current price and include the source URL",
	} {
		if !needsWebTools(question) {
			t.Fatalf("%q should use the web tools lane", question)
		}
	}
	for _, question := range []string{"¿Qué GPU tengo?", "Explícame este archivo local"} {
		if needsWebTools(question) {
			t.Fatalf("%q should stay local", question)
		}
	}
}

func TestChatSessionRetainsOnlyRecentTurns(t *testing.T) {
	var session chatSession
	for i := 0; i < maxConversationTurns+4; i++ {
		session.append("q", "a")
	}
	if got := len(session.snapshot()); got != maxConversationTurns {
		t.Fatalf("got %d turns, want %d", got, maxConversationTurns)
	}
}
