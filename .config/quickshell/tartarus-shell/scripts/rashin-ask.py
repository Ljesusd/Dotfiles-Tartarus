#!/usr/bin/env python3
"""Ask a local OpenAI-compatible or Ollama endpoint without executing tools."""

from __future__ import annotations

import argparse
import json
import os
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from datetime import datetime
from pathlib import Path


MAX_CONTEXT = 16000
LOCAL_HOSTS = {"127.0.0.1", "localhost", "::1"}


class BackendError(RuntimeError):
    def __init__(self, message: str, available: bool = False):
        super().__init__(message)
        self.available = available


def local_url(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("El endpoint local está vacío.")
    if "://" not in value:
        value = "http://" + value
    parsed = urllib.parse.urlparse(value)
    hostname = parsed.hostname
    if hostname not in LOCAL_HOSTS:
        try:
            addresses = {item[4][0] for item in socket.getaddrinfo(hostname, parsed.port or 80)}
        except socket.gaierror as error:
            raise ValueError(f"No se pudo resolver el endpoint local: {error}") from error
        if not addresses or not addresses.issubset(LOCAL_HOSTS):
            raise ValueError("Rashin solo permite endpoints en localhost.")
    return value.rstrip("/")


def endpoint_kind(url: str) -> str:
    path = urllib.parse.urlparse(url).path.rstrip("/")
    if path.endswith("/api/chat"):
        return "ollama"
    return "openai"


def context(vault: Path) -> str:
    chunks: list[str] = []
    for name in ("AGENTS.md", "system.md", "desktop.md", "packages.md", "user.md"):
        path = vault / name
        if not path.is_file():
            continue
        try:
            value = path.read_text(encoding="utf-8")
        except OSError:
            continue
        chunks.append(f"## {name}\n{value[:5000]}")
    joined = "\n\n".join(chunks)
    return joined[:MAX_CONTEXT] or "No hay contexto indexado todavía."


def completion_url(url: str) -> str:
    if endpoint_kind(url) == "ollama" or url.endswith("/chat/completions"):
        return url
    return url + ("/chat/completions" if url.endswith("/v1") else "/v1/chat/completions")


def stream_events(response, kind: str):
    """Decode SSE (llama.cpp) or NDJSON (Ollama) without buffering the answer."""
    pending: list[str] = []
    for raw_line in response:
        line = raw_line.decode("utf-8").rstrip("\r\n")
        if kind == "ollama":
            if line.strip():
                yield json.loads(line)
        elif line.startswith("data:"):
            pending.append(line[5:].lstrip(" "))
        elif not line and pending:
            data = "\n".join(pending)
            pending.clear()
            if data.strip() == "[DONE]":
                yield {"done": True}
                return
            yield json.loads(data)
        # Ignore SSE comments, heartbeat pings, event names and ids.
    if pending:
        data = "\n".join(pending)
        yield {"done": True} if data.strip() == "[DONE]" else json.loads(data)


def streamed_answer(response, kind: str, emit: Callable[[dict], None]) -> str:
    fragments: list[str] = []
    finished = False
    for event in stream_events(response, kind):
        if not isinstance(event, dict):
            raise BackendError("El modelo devolvió un fragmento no válido.", available=True)
        if event.get("error"):
            raise BackendError(f"El modelo local devolvió un error: {event['error']}", available=True)
        if kind == "ollama":
            fragment = (event.get("message") or {}).get("content", "")
        else:
            choices = event.get("choices") or []
            choice = choices[0] if choices else {}
            fragment = (choice.get("delta") or {}).get("content", "")
            finished = finished or choice.get("finish_reason") is not None
        # Reasoning and tool calls are not an answer, and never become actions.
        if isinstance(fragment, str) and fragment:
            fragments.append(fragment)
            emit({"type": "delta", "text": fragment})
        if event.get("done") is True:
            finished = True
            break
    if not finished:
        raise BackendError("Se interrumpió la respuesta del modelo local.")
    return "".join(fragments).strip()


def ask(url: str, model: str, question: str, vault: Path,
        emit: Callable[[dict], None] | None = None) -> str:
    system = (
        "Eres el asistente local de Tartarus. Responde en español salvo que el usuario use otro idioma. "
        "Usa el contexto local solo como referencia; si no basta, dilo. No inventes rutas ni estados. "
        "Puedes proponer comandos, pero nunca los ejecutes ni pidas credenciales. Sé breve y práctico.\n\n"
        "CONTEXTO LOCAL:\n" + context(vault)
    )
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": question},
    ]
    kind = endpoint_kind(url)
    payload = {"model": model, "messages": messages, "stream": emit is not None}

    request = urllib.request.Request(
        completion_url(url),
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            if emit is not None:
                emit({"type": "connected"})
                answer = streamed_answer(response, kind, emit)
            else:
                data = json.loads(response.read().decode("utf-8"))
                if kind == "ollama":
                    answer = data.get("message", {}).get("content", "")
                else:
                    choices = data.get("choices") or []
                    answer = choices[0].get("message", {}).get("content", "") if choices else ""
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[-500:]
        raise BackendError(f"El modelo local respondió HTTP {error.code}: {detail}",
                           available=error.code < 500) from error
    except (UnicodeError, json.JSONDecodeError, AttributeError, TypeError) as error:
        raise BackendError(f"La respuesta del modelo local no era válida: {error}", available=True) from error
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise BackendError(f"No se pudo contactar con el modelo local: {error}") from error

    answer = str(answer or "").strip()
    if not answer:
        raise BackendError("El modelo local no devolvió una respuesta.", available=True)
    return answer


def probe(value: str) -> dict[str, object]:
    url = local_url(value)
    parsed = urllib.parse.urlparse(url)
    if parsed.path.rstrip("/").endswith("/api/chat"):
        target = f"{parsed.scheme}://{parsed.netloc}/api/tags"
    elif parsed.path.rstrip("/").endswith("/v1"):
        target = url + "/models"
    elif parsed.path.rstrip("/").endswith("/chat/completions"):
        target = url.rsplit("/chat/completions", 1)[0] + "/models"
    else:
        target = url + "/v1/models"
    try:
        request = urllib.request.Request(target, method="GET")
        with urllib.request.urlopen(request, timeout=3) as response:
            payload = json.loads(response.read().decode("utf-8"))
            models = payload.get("data") or payload.get("models") or []
            discovered = []
            for item in models:
                if isinstance(item, dict):
                    model_id = str(item.get("id") or item.get("model") or item.get("name") or "").strip()
                    if model_id:
                        discovered.append(model_id)
            metadata = {}
            if models and isinstance(models[0], dict):
                raw_metadata = models[0].get("meta") or models[0].get("details")
                if isinstance(raw_metadata, dict):
                    metadata = raw_metadata
            return {
                "ok": True,
                "available": 200 <= response.status < 300 and bool(discovered),
                "endpoint": target,
                "model": discovered[0] if discovered else "",
                "models": discovered,
                "metadata": metadata,
            }
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, AttributeError, TypeError) as error:
        return {"ok": True, "available": False, "error": str(error)}


def emit_event(event: dict) -> None:
    # One flushed JSON line per event: Quickshell's SplitParser can render it now.
    print(json.dumps(event, ensure_ascii=False), flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--model", default="tartarus-local")
    parser.add_argument("--question", default="")
    parser.add_argument("--vault", default="")
    parser.add_argument("--history", default="")
    parser.add_argument("--probe", action="store_true")
    parser.add_argument("--stream", action="store_true")
    args = parser.parse_args()

    try:
        if args.probe:
            print(json.dumps(probe(args.endpoint), ensure_ascii=False))
            return 0
        question = args.question.strip()
        if not question:
            raise ValueError("Escribe una pregunta para Rashin.")
        answer = ask(local_url(args.endpoint), args.model.strip(), question,
                     Path(os.path.expanduser(args.vault)), emit_event if args.stream else None)
        entry = {
            "at": datetime.now().astimezone().isoformat(timespec="seconds"),
            "question": question,
            "answer": answer,
            "model": args.model,
        }
        warning = ""
        if args.history:
            try:
                history = Path(os.path.expanduser(args.history))
                history.parent.mkdir(parents=True, exist_ok=True)
                with history.open("a", encoding="utf-8") as handle:
                    handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
            except OSError:
                warning = "La respuesta está lista, pero no se pudo guardar en el historial."
        emit_event({"type": "done", "ok": True, "answer": answer, "entry": entry, "warning": warning})
        return 0
    except (ValueError, RuntimeError) as error:
        emit_event({"type": "error", "ok": False, "error": str(error),
                    "available": getattr(error, "available", False)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
