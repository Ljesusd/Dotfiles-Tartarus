#!/usr/bin/env python3
"""Export Whisp's active Markdown note to an Obsidian Inbox."""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path


APP_ID = "io.github.tanaybhomia.Whisp"
APP_ROOT = Path.home() / ".var" / "app" / APP_ID
CONFIG_DIR = APP_ROOT / "config" / "whisp"
STATE_FILE = APP_ROOT / ".local" / "state" / "whisp" / "state.json"
DEFAULT_NOTES = APP_ROOT / "data" / "whisp" / "notes"
DEFAULT_INBOX = Path.home() / "Documents" / "Obsidian" / "Inbox"


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def notes_directory() -> Path:
    config = read_json(CONFIG_DIR / "config.json")
    configured = config.get("data_dir")
    if configured:
        path = Path(os.path.expanduser(str(configured)))
        if path.exists():
            return path
    return DEFAULT_NOTES


def active_note(directory: Path) -> Path | None:
    state = read_json(STATE_FILE)
    candidate = state.get("last_active_note")
    if candidate:
        path = Path(os.path.expanduser(str(candidate)))
        if path.is_file() and path.suffix.lower() == ".md":
            return path

    notes = [path for path in directory.glob("*.md") if path.is_file()]
    return max(notes, key=lambda path: path.stat().st_mtime, default=None)


def title_from(content: str, source: Path) -> str:
    for line in content.splitlines():
        clean = line.strip()
        if clean:
            heading = re.sub(r"^#+\s*", "", clean).strip()
            return heading or source.stem
    return source.stem


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^\w\s-]", "", value, flags=re.UNICODE)
    value = re.sub(r"[\s_-]+", "-", value).strip("-")
    return value[:80] or "whisp-note"


def main() -> int:
    directory = notes_directory()
    source = active_note(directory)
    if source is None:
        print(f"No hay notas Markdown en {directory}", file=sys.stderr)
        return 1

    try:
        content = source.read_text(encoding="utf-8").strip()
    except OSError as error:
        print(f"No se pudo leer la nota: {error}", file=sys.stderr)
        return 1

    if not content:
        print("La nota activa está vacía", file=sys.stderr)
        return 1

    inbox = Path(os.environ.get("TARTARUS_OBSIDIAN_INBOX", DEFAULT_INBOX))
    inbox.mkdir(parents=True, exist_ok=True)

    now = datetime.now().astimezone()
    filename = f"{now:%Y-%m-%d-%H%M%S}-{slugify(title_from(content, source))}.md"
    destination = inbox / filename
    counter = 2
    while destination.exists():
        destination = inbox / f"{now:%Y-%m-%d-%H%M%S}-{slugify(title_from(content, source))}-{counter}.md"
        counter += 1

    if not content.startswith("---\n"):
        content = (
            "---\n"
            "source: whisp\n"
            f"created: {now.isoformat(timespec='seconds')}\n"
            "---\n\n"
            + content
        )

    destination.write_text(content.rstrip() + "\n", encoding="utf-8")
    print(f"Exportada: {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
