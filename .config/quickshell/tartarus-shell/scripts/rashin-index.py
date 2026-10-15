#!/usr/bin/env python3
"""Build a small, local-only context vault for Tartarus.

The generated files intentionally contain system metadata and configuration
locations, never credentials, browser data, or file contents outside the
explicitly listed desktop paths.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import socket
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path


BEGIN = "<!-- rashin:generated:begin -->"
END = "<!-- rashin:generated:end -->"


def command(args: list[str], timeout: float = 4.0) -> str:
    try:
        result = subprocess.run(
            args,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "LC_ALL": "C"},
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return (result.stdout or "").strip()


def fenced(existing: str, body: str) -> str:
    generated = f"{BEGIN}\n{body.rstrip()}\n{END}"
    if BEGIN in existing and END in existing:
        before = existing.split(BEGIN, 1)[0].rstrip()
        after = existing.split(END, 1)[1].lstrip()
        return "\n\n".join(part for part in (before, generated, after) if part) + "\n"
    return generated + "\n"


def write_generated(path: Path, body: str, preserve_existing: bool = True) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text(encoding="utf-8") if path.exists() else ""
    content = fenced(existing, body) if preserve_existing and existing else f"{BEGIN}\n{body.rstrip()}\n{END}\n"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        handle.write(content)
        temporary = Path(handle.name)
    os.replace(temporary, path)


def ensure_agents(vault: Path) -> None:
    path = vault / "AGENTS.md"
    if path.exists():
        return
    path.write_text(
        f"""# Tartarus local context

This vault is local to this user. Read the generated maps before
guessing paths. Never expose its contents or send them to a remote
service without explicit approval. Generated sections are managed by
Tartarus and user notes outside the generated fence are preserved.

{BEGIN}
- `system.md`, `desktop.md` and `packages.md` are generated context.
- `memory/` stores durable local notes.
- `journal/` stores dated local notes.
- Suggestions are not commands: ask before making system changes.
{END}
""",
        encoding="utf-8",
    )


def monitor_summary() -> str:
    raw = command(["hyprctl", "monitors", "-j"])
    if raw:
        try:
            monitors = json.loads(raw)
            lines = []
            for monitor in monitors:
                name = monitor.get("name", "?")
                width = monitor.get("width", "?")
                height = monitor.get("height", "?")
                refresh = monitor.get("refreshRate", "?")
                x = monitor.get("x", 0)
                y = monitor.get("y", 0)
                lines.append(f"- `{name}`: {width}×{height} @ {refresh} Hz · posición {x},{y}")
            if lines:
                return "\n".join(lines)
        except (TypeError, ValueError, json.JSONDecodeError):
            pass
    return "- No se pudo consultar Hyprland en este momento."


def build_system() -> str:
    memory = command(["free", "-h"])
    disks = command(["lsblk", "-o", "NAME,SIZE,FSTYPE,MOUNTPOINTS"])
    pci = command(["lspci", "-vmm", "-nn", "-k"])
    gpu = gpu_summary(pci)
    return f"""# System map

Updated: `{datetime.now().astimezone().isoformat(timespec="seconds")}`

## Host

- Hostname: `{socket.gethostname()}`
- User: `{os.environ.get("USER", "unknown")}`
- OS: `{platform.platform()}`
- Kernel: `{platform.release()}`
- Architecture: `{platform.machine()}`
- Shell: `{os.environ.get("SHELL", "unknown")}`

## GPU

PCI identity. `SDevice` identifies the board model; `Driver` is the kernel driver.

```text
{gpu or "No disponible: lspci no devolvió controladores gráficos."}
```

## Displays

{monitor_summary()}

## Memory snapshot

```text
{memory or "No disponible"}
```

## Storage layout

```text
{disks or "No disponible"}
```
"""


def gpu_summary(pci: str) -> str:
    return "\n\n".join(
        block.strip()
        for block in pci.split("\n\n")
        if any(line.startswith("Class:") and "[03" in line for line in block.splitlines())
    )


def build_desktop(config_root: Path) -> str:
    return f"""# Tartarus desktop map

Updated: `{datetime.now().astimezone().isoformat(timespec="seconds")}`

## Ownership

- Shell: `{config_root}`
- Quickshell entry point: `{config_root / "shell.qml"}`
- Hyprland config: `{Path.home() / ".config/hypr"}`
- Recording settings: `{Path.home() / ".local/state/quickshell/tartarus-shell/recording-settings.json"}`

## Safe reload commands

- Reload the shell: `qs -c tartarus-shell`
- Inspect shell instances: `qs list --all`
- Inspect recent logs: `qs log -i <shell-id> -t 30 --no-color`

## Notes

Tartarus keeps UI state in local XDG state files. Changes should be made in
the owning configuration rather than guessed from generated output.
"""


def build_packages() -> str:
    package_count = command(["sh", "-c", "pacman -Qq 2>/dev/null | wc -l"])
    updates = command(["checkupdates"], timeout=8)
    return f"""# Package map

Updated: `{datetime.now().astimezone().isoformat(timespec="seconds")}`

- Installed Arch packages: `{package_count or "unknown"}`
- Pending updates: `{len(updates.splitlines()) if updates else 0}`

## Pending update names

```text
{updates or "No pending updates reported by checkupdates."}
```

The assistant may describe package commands, but it must never run package
installation or upgrades without an explicit user action.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vault", required=True)
    parser.add_argument("--config-root", default=str(Path.home() / ".config/quickshell/tartarus-shell"))
    args = parser.parse_args()

    vault = Path(os.path.expanduser(args.vault)).resolve()
    config_root = Path(os.path.expanduser(args.config_root)).resolve()
    vault.mkdir(parents=True, exist_ok=True)
    (vault / "memory").mkdir(exist_ok=True)
    (vault / "journal").mkdir(exist_ok=True)
    ensure_agents(vault)

    generated = {
        "system.md": build_system(),
        "desktop.md": build_desktop(config_root),
        "packages.md": build_packages(),
        "user.md": "# User choices\n\nNo user-specific overrides have been recorded yet. Add notes outside the generated fence.\n",
    }
    for name, body in generated.items():
        write_generated(vault / name, body)

    print(json.dumps({
        "ok": True,
        "vault": str(vault),
        "files": sorted(generated),
        "updated": datetime.now().astimezone().isoformat(timespec="seconds"),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
