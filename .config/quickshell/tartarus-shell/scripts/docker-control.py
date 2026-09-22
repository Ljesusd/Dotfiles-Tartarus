#!/usr/bin/env python3
"""Bounded Docker CLI adapter for Tartarus. No shell, sudo, or automatic writes."""
import json
import os
import re
import selectors
import shutil
import subprocess
import sys
import time

MAX_CONTAINERS = 128
STATES = {"start": {"created", "exited"}, "stop": {"running"},
          "restart": {"running"}, "unpause": {"paused"}}


def run(args, timeout=8, limit=1024 * 1024, logs=False):
    with subprocess.Popen(["docker", *args], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE) as proc:
        buffers = {"out": bytearray(), "err": bytearray()}
        combined = bytearray()
        deadline = time.monotonic() + timeout
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ, "out")
            selector.register(proc.stderr, selectors.EVENT_READ, "err")
            try:
                while selector.get_map():
                    if time.monotonic() >= deadline:
                        raise RuntimeError("Docker tardó demasiado en responder.")
                    for key, _ in selector.select(0.1):
                        data = os.read(key.fileobj.fileno(), 16384)
                        if not data:
                            selector.unregister(key.fileobj)
                            continue
                        buffers[key.data].extend(data)
                        combined.extend(data)
                        if len(combined) > limit:
                            if logs:
                                proc.kill()
                                proc.wait()
                                return clean(combined[:limit].decode("utf-8", "replace")) + "\n[Salida limitada]"
                            raise RuntimeError("La respuesta Docker supera el límite de seguridad.")
                proc.wait(timeout=max(0.1, deadline - time.monotonic()))
            except BaseException:
                proc.kill()
                proc.wait()
                raise
        if proc.returncode:
            message = buffers["err"].decode("utf-8", "replace")
            if "permission denied" in message.lower():
                raise RuntimeError("Sin permiso para acceder a Docker. Comprueba ‘docker ps’ en tu terminal.")
            if "cannot connect" in message.lower() or "is the docker daemon running" in message.lower():
                raise RuntimeError("Docker no responde. Comprueba el servicio o contexto Docker activo.")
            raise RuntimeError(clean(message.strip())[:600] or "El comando Docker falló.")
        return clean((combined if logs else buffers["out"]).decode("utf-8", "replace"))


def clean(text):
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    return re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)


def valid_id(value):
    if not re.fullmatch(r"[0-9a-f]{64}", value):
        raise ValueError("Identificador de contenedor inválido.")
    return value


def rows(text):
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def snapshot():
    entries = rows(run(["ps", "--all", "--no-trunc", "--format", "{{json .}}", "--last", str(MAX_CONTAINERS + 1)]))
    truncated = len(entries) > MAX_CONTAINERS
    containers = []
    for item in entries[:MAX_CONTAINERS]:
        labels = dict(label.split("=", 1) for label in item.get("Labels", "").split(",") if "=" in label)
        containers.append({"id": valid_id(item["ID"]), "name": item.get("Names", "")[:256],
                           "image": item.get("Image", "")[:256], "state": item.get("State", ""),
                           "status": item.get("Status", "")[:256],
                           "project": labels.get("com.docker.compose.project", "Sin proyecto")[:128],
                           "cpu": "—", "memory": "—"})
    warning = "Se muestran los primeros 128 contenedores." if truncated else ""
    running = [c["id"] for c in containers if c["state"] == "running"]
    if running:
        try:
            stats = {s["ID"]: s for s in rows(run(["stats", "--no-stream", "--no-trunc",
                                                  "--format", "{{json .}}", *running], timeout=10))}
            for item in containers:
                stat = stats.get(item["id"], {})
                item["cpu"] = stat.get("CPUPerc", "—")
                item["memory"] = stat.get("MemUsage", "—")
        except RuntimeError as error:
            warning = str(error)
    containers.sort(key=lambda c: (c["project"].lower(), c["name"].lower()))
    return {"ok": True, "installed": True, "containers": containers, "warning": warning}


def action(verb, container_id):
    valid_id(container_id)
    if verb not in STATES:
        raise ValueError("Acción no permitida.")
    state = json.loads(run(["inspect", "--type", "container", "--format", "{{json .State.Status}}", container_id]))
    if state not in STATES[verb]:
        raise ValueError("El estado cambió o no permite esta acción. Actualiza la lista.")
    args = [verb]
    if verb in {"stop", "restart"}:
        args += ["--time", "10"]
    run([*args, container_id], timeout=25)
    return {"ok": True}


def main(argv):
    installed = shutil.which("docker") is not None
    try:
        if argv == ["available"]:
            return {"ok": True, "installed": installed}
        if not installed:
            raise RuntimeError("Docker no está instalado.")
        if argv == ["snapshot"]:
            return snapshot()
        if len(argv) == 2 and argv[0] == "logs":
            return {"ok": True, "logs": run(["logs", "--timestamps", "--tail", "100", valid_id(argv[1])],
                                               logs=True, limit=128 * 1024)}
        if len(argv) == 3 and argv[0] == "action":
            return action(argv[1], argv[2])
        raise ValueError("Comando no permitido.")
    except (RuntimeError, ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
        return {"ok": False, "installed": installed, "error": str(error)[:600]}


if __name__ == "__main__":
    print(json.dumps(main(sys.argv[1:]), ensure_ascii=True))
