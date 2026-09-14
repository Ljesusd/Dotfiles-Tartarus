from __future__ import annotations

import argparse
import fcntl
import tempfile
import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import cast


PROJECT_ROOT = Path(__file__).resolve().parent.parent
STATE_DIR = Path.home() / ".local" / "state" / "tartarus-shell"
ACTIVE_WALLPAPER_FILE = STATE_DIR / "active-wallpaper.json"

IMAGE_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".bmp",
    ".gif",
}

WALLPAPER_DIRECTORIES = [
    Path.home() / "Pictures" / "Wallpaper",
    Path.home() / "Pictures" / "Wallpapers",
    Path.home() / "Pictures" / "Wallpaper",
    Path.home() / ".local" / "share" / "backgrounds",
    Path.home() / "Imágenes" / "Wallpapers",
    PROJECT_ROOT / "wallpapers",
]


def safe_path(value: str) -> Path:
    expanded = os.path.expanduser(value)
    return Path(expanded).resolve()


def list_wallpapers() -> list[dict[str, object]]:
    default_dir = Path.home() / "Pictures" / "Wallpaper"
    default_dir.mkdir(parents=True, exist_ok=True)

    seen = set[str]()
    found: list[dict[str, object]] = []

    for folder in WALLPAPER_DIRECTORIES:
        path = folder.expanduser()
        if not path.exists() or not path.is_dir():
            continue

        for file in sorted(path.rglob("*")):
            if (
                not file.is_file()
                or file.suffix.lower() not in IMAGE_EXTENSIONS
            ):
                continue

            resolved = file.resolve()
            key = str(resolved)
            if key in seen:
                continue
            seen.add(key)

            found.append(
                {
                    "name": resolved.stem.replace("-", " ").replace("_", " "),
                    "path": str(resolved),
                    "pathLabel": str(resolved),
                    "isCurrent": False,
                }
            )

    return found


def read_active() -> dict[str, object] | None:
    if not ACTIVE_WALLPAPER_FILE.exists():
        return None

    try:
        with ACTIVE_WALLPAPER_FILE.open("r", encoding="utf-8") as file:
            data = json.load(file)
            return data if isinstance(data, dict) else None
    except (OSError, json.JSONDecodeError):
        return None


def write_active(path: str, monitor: str = "") -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    # Serialize read/modify/write across launcher instances and monitor requests.
    with (STATE_DIR / "active-wallpaper.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        current = read_active() or {}
        if monitor:
            monitors = current.get("monitors", {})
            if not isinstance(monitors, dict):
                monitors = {}
            monitors[monitor] = path
            current = {"path": current.get("path", path), "monitors": monitors}
        else:
            # A global apply replaces every output, so old overrides are stale.
            current = {"path": path, "monitors": {}}
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                             dir=STATE_DIR, delete=False) as file:
                temporary = Path(file.name)
                json.dump(current, file, ensure_ascii=False, indent=2)
                file.write("\n")
                file.flush()
                os.fsync(file.fileno())
            os.replace(temporary, ACTIVE_WALLPAPER_FILE)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()


def detect_backends() -> list[str]:
    backends: list[str] = []

    if shutil.which("hyprpaper") and shutil.which("hyprctl"):
        backends.append("hyprpaper")

    if shutil.which("swww"):
        backends.append("swww")

    return backends


def set_swww(path: str, monitor: str = "") -> None:
    _ = subprocess.run(
        ["swww", "init"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    command = ["swww", "img", "--transition-type", "fade", "--transition-duration", "0.7"]
    if monitor:
        command.extend(["--outputs", monitor])
    command.append(path)
    result = subprocess.run(
        command,
        check=False,
        text=True,
        capture_output=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            result.stderr.strip() or "swww failed to set wallpaper"
        )


def ensure_hyprpaper() -> None:
    if not is_hyprpaper_running():
        if shutil.which("systemctl"):
            _ = subprocess.run(
                ["systemctl", "--user", "start", "hyprpaper.service"],
                check=False,
                text=True,
                capture_output=True,
            )

        for _ in range(20):
            time.sleep(0.15)
            if is_hyprpaper_running():
                break
        else:
            if shutil.which("systemctl"):
                raise RuntimeError(
                    "No se pudo iniciar hyprpaper.service (systemd --user). "
                    "Verifica: systemctl --user status hyprpaper.service"
                )
            raise RuntimeError(
                "No se pudo iniciar hyprpaper. "
                "Asegúrate de iniciar sesión en Wayland."
            )



def set_hyprpaper(path: str) -> None:
    ensure_hyprpaper()
    monitors = []
    monitor_result = subprocess.run(
        ["hyprctl", "monitors", "-j"],
        check=False,
        text=True,
        capture_output=True,
    )

    if monitor_result.returncode == 0 and monitor_result.stdout:
        try:
            monitor_data = json.loads(monitor_result.stdout)
            monitors = [
                str(item.get("name", "")).strip()
                for item in monitor_data
                if str(item.get("name", "")).strip()
            ]
        except json.JSONDecodeError:
            monitors = []

    # Hyprpaper IPC expects direct wallpaper requests.
    # Keep retry logic with a respawn in case a service-started instance is not
    # bound to the active Wayland session.
    if monitors:
        for monitor in monitors:
            if monitor:
                _set_hyprpaper_single(monitor, path)
        return

    _set_hyprpaper_single("", path)


def _set_hyprpaper_single(monitor: str, path: str) -> None:
    target = f"{monitor},{path}" if monitor else path
    result = subprocess.run(
        ["hyprctl", "hyprpaper", "wallpaper", target],
        check=False,
        text=True,
        capture_output=True,
    )

    if result.returncode != 0:
        message = (
            (result.stdout.strip() + "\n" + result.stderr.strip()).strip()
            or "hyprpaper wallpaper failed"
        )
        # Do not restart a global daemon to repair one monitor request.
        raise RuntimeError(message)

def is_hyprpaper_running() -> bool:
    return subprocess.run(
        ["pgrep", "-x", "hyprpaper"],
        check=False,
        text=True,
        capture_output=True,
    ).returncode == 0


def set_wallpaper(path: str, monitor: str = "", *, persist: bool = True) -> None:
    image = safe_path(path)
    if not image.exists() or not image.is_file():
        raise FileNotFoundError(f"No existe archivo: {image}")

    errors: list[str] = []
    for backend in detect_backends():
        try:
            if backend == "swww":
                set_swww(str(image), monitor)
            elif backend == "hyprpaper":
                if monitor:
                    ensure_hyprpaper()
                    _set_hyprpaper_single(monitor, str(image))
                else:
                    set_hyprpaper(str(image))
            else:
                continue

            if persist:
                write_active(str(image), monitor)
            return
        except RuntimeError as error:
            errors.append(f"{backend}: {error}")
            continue

    if errors:
        joined = ", ".join(errors)
        raise RuntimeError(
            "No se pudo aplicar wallpaper con backends disponibles. "
            f"Errores: {joined}"
        )

    raise RuntimeError(
        "No hay backend disponible para wallpaper. "
        "Instala swww o hyprpaper para que Tartarus pueda cambiar fondos."
    )


def print_json(payload: object) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def command_list(json_output: bool) -> None:
    items = list_wallpapers()
    if json_output:
        print_json(items)
        return

    for item in items:
        print(item["pathLabel"])


def command_current(json_output: bool, monitor: str = "") -> None:
    active = read_active() or {}
    overrides = active.get("monitors", {})
    if not isinstance(overrides, dict):
        overrides = {}
    path = overrides.get(monitor, active.get("path", ""))

    if json_output:
        print_json({"path": path, "monitors": overrides})
        return

    print(path)


def command_set(path: str, monitor: str) -> None:
    set_wallpaper(path, monitor)
    print(f"Wallpaper activo: {path}")


def command_apply_saved() -> None:
    active = read_active() or {}
    overrides = active.get("monitors", {})
    if not isinstance(overrides, dict):
        overrides = {}
    result = subprocess.run(["hyprctl", "monitors", "-j"], check=False,
                            text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Cannot enumerate monitors")
    errors = []
    for output in json.loads(result.stdout):
        monitor = output.get("name", "")
        path = overrides.get(monitor, active.get("path", ""))
        if not isinstance(path, str) or not path or not monitor:
            continue
        try:
            set_wallpaper(path, monitor, persist=False)
        except (FileNotFoundError, RuntimeError) as error:
            errors.append(f"{monitor}: {error}")
    if errors:
        raise RuntimeError("; ".join(errors))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Manage Tartarus wallpapers")
    sub = parser.add_subparsers(dest="command", required=True)

    list_cmd = sub.add_parser("list", help="List wallpapers")
    list_cmd.add_argument("--json", action="store_true")

    current_cmd = sub.add_parser("current", help="Show active wallpaper")
    current_cmd.add_argument("--json", action="store_true")
    current_cmd.add_argument("--monitor", default="")

    set_cmd = sub.add_parser("set", help="Set wallpaper")
    set_cmd.add_argument("path")
    set_cmd.add_argument("--monitor", default="")

    sub.add_parser("apply-saved", help="Apply the saved wallpaper")

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        if args.command == "list":
            command_list(args.json)
            return 0

        if args.command == "current":
            command_current(args.json, args.monitor)
            return 0

        if args.command == "set":
            command_set(args.path, args.monitor)
            return 0

        if args.command == "apply-saved":
            command_apply_saved()
            return 0

    except Exception as error:
        print(f"Error: {error}")
        return 1

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
