# Local AI: Rashin, llama.cpp and Hermes

Rashin provides the local chat UI, projects, sessions, attachments and queue.
Its optional agent lane launches `hermes acp`; the fast lane calls the configured
OpenAI-compatible endpoint directly. These are distinct capabilities: enabling
a model does not automatically grant it Hermes tools.

## Build and configure

1. Install Go, Python 3, curl and a llama.cpp build appropriate for your GPU.
2. Install the public links with `bash tools/install-links.sh --apply`.
3. Download a compatible GGUF and its matching multimodal projector, if needed.
   The default path is `~/Models/LLM/gemma-4-E4B-it-qat/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf`.
4. Install/configure Hermes using its official setup or the shell's setup action.
   Select a custom Chat Completions endpoint `http://127.0.0.1:8081/v1` and the
   exact model alias exposed by `/v1/models`. Enable only tools you intend to use.

The llama wrapper accepts `TARTARUS_LLAMA_SERVER`, `TARTARUS_LLM_MODEL` and
`TARTARUS_LLM_CONTEXT`. It first uses llama-server from PATH, then the existing
`~/Code/llama.cpp/build-hip/bin/llama-server` convention. A saved model selection
in local state takes precedence over the default model environment variable.
A sibling `mmproj-F16.gguf` is passed as projector, never as a standalone model.

For different paths/hardware use `systemctl --user edit tartarus-rashin-llama`:

```ini
[Service]
Environment=TARTARUS_LLAMA_SERVER=/absolute/path/to/llama-server
Environment=TARTARUS_LLM_MODEL=/absolute/path/to/model.gguf
Environment=TARTARUS_LLM_CONTEXT=98304
```

The current 96K context, full GPU offload and f16 KV cache are personal defaults,
not suitable for every GPU. Lower the context if memory is insufficient. Match
Hermes' context configuration to the server's actual capacity.

```sh
systemctl --user daemon-reload
systemctl --user start tartarus-rashin-llama tartarus-rashin
```

These commands start services only for this session; use `enable` explicitly if
you want login autostart. Stop both with `systemctl --user stop
tartarus-rashin tartarus-rashin-llama` to release model resources. The shell also
offers its own on/off control. The service definitions do not force autostart.

## Ports and privacy

- Model API: `127.0.0.1:8081`; Rashin UI/API: `127.0.0.1:3610`.
- Rashin state: `~/.local/state/tartarus-shell`; indexed context:
  `~/.local/share/tartarus/rashin`.
- Hermes config, keys, sessions and memories: `~/.hermes`, intentionally excluded.
- Use the interactive setup for secrets. Do not paste credentials into tracked
  service files or commit exported context/hardware maps.
- Local inference does not imply offline tools: web search/browser providers can
  contact external services. Configure them explicitly and review permissions.

Sung and external agents are independent projects; the repository ships their
integration, not your private provider accounts or downloaded models.
