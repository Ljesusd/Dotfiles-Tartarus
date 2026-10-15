package main

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestACPErrorDetails(t *testing.T) {
	tests := []struct {
		name, wire, want string
	}{
		{"context", `{"error":{"code":-32603,"message":"Internal error","data":{"details":"Model qwen has a context window of 8,192 tokens, which is below the minimum 64,000 required by Hermes Agent."}}}`, "contexto configurado es de 8.192 tokens y necesita al menos 64.000"},
		{"details", `{"error":{"code":-32603,"message":"Internal error","data":{"details":"Provider is unavailable"}}}`, "Provider is unavailable"},
		{"missing details", `{"error":{"code":-32603,"message":"Internal error"}}`, "Internal error"},
		{"unknown data", `{"error":{"code":-32603,"message":"Internal error","data":{"debug":"do not display arbitrary debug data"}}}`, "Internal error"},
		{"nonstring details", `{"error":{"code":-32603,"message":"Internal error","data":{"details":{"unexpected":true}}}}`, "Internal error"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var rpc acpRPC
			if err := json.Unmarshal([]byte(tc.wire), &rpc); err != nil {
				t.Fatal(err)
			}
			if got := rpc.Error.description(); !strings.Contains(got, tc.want) {
				t.Fatalf("got %q, want %q", got, tc.want)
			}
		})
	}
}
