package main

import "testing"

func TestAuxiliaryModelFilesAreNotStandaloneModels(t *testing.T) {
	for _, path := range []string{
		"gemma-4-E4B-it-qat/mmproj-F16.gguf",
		"gemma-4-E4B-it-qat/mmproj-BF16.gguf",
		"gemma-4-E4B-it-qat/MMProj-F32.gguf",
		"gemma-4-E4B-it-qat/mtp-gemma-4-E4B-it.gguf",
	} {
		if !isAuxiliaryModel(path) {
			t.Errorf("auxiliary file appeared as a model: %s", path)
		}
	}
	if isAuxiliaryModel("gemma-4-E4B-it-qat/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf") {
		t.Fatal("main Gemma model must remain selectable")
	}
}

func TestGemmaModelLabel(t *testing.T) {
	if got := modelLabel("gemma-4-E4B-it-qat-UD-Q4_K_XL"); got != "Gemma 4 E4B QAT · UD-Q4_K_XL" {
		t.Fatalf("unexpected label: %q", got)
	}
}
