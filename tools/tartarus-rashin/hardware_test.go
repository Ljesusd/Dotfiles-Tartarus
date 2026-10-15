package main

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const gpuFixture = "Slot:\t2d:00.0\nClass:\tVGA compatible controller [0300]\nDevice:\tNavi 44 [7590]\nSDevice:\tRadeon RX 9060 XT GAMING OC 16G\nDriver:\tamdgpu"

func TestGPUPCIContext(t *testing.T) {
	other := "Slot:\t00:00.0\nClass:\tHost bridge [0600]\nDevice:\tBridge"
	second := "Slot:\t03:00.0\nClass:\t3D controller [0302]\nDevice:\tAnother GPU"
	if got := gpuPCIContext(other + "\n\n" + gpuFixture + "\n\n" + second + "\n"); got != gpuFixture+"\n\n"+second {
		t.Fatalf("wrong display selection: %q", got)
	}
	if gpuPCIContext(other) != "" || gpuPCIContext("") != "" {
		t.Fatal("must not infer a GPU without a display-class PCI device")
	}
}

func TestGPUReadOnlyContext(t *testing.T) {
	dir := t.TempDir()
	script := "#!/bin/sh\n[ \"$*\" = '-vmm -nn -k' ] || exit 1\nprintf '%s' '" + gpuFixture + "'\n"
	if err := os.WriteFile(filepath.Join(dir, "lspci"), []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
	for _, question := range []string{"Sabes cual gpu es?", "Qué tarjeta gráfica tengo?", "Qué grafica tengo?"} {
		var events []ChatEvent
		got := (&Server{}).readOnlyContext(context.Background(), question, func(e ChatEvent) { events = append(events, e) })
		if !strings.Contains(got, "RX 9060 XT") {
			t.Fatalf("GPU missing for %q: %q", question, got)
		}
		if len(events) < 2 || events[0].ToolID != "gpu_query" || events[1].ToolState != "done" {
			t.Fatalf("expected GPU events, got %+v", events)
		}
	}
}

func TestMissingGPUCommandIsNotReportedAsSuccess(t *testing.T) {
	t.Setenv("PATH", t.TempDir())
	var events []ChatEvent
	got := (&Server{}).readOnlyContext(context.Background(), "tarjeta gráfica", func(e ChatEvent) { events = append(events, e) })
	if !strings.Contains(got, "No disponible") || len(events) != 2 || events[1].ToolState != "failed" {
		t.Fatalf("missing command must be reported: %q %+v", got, events)
	}
}
