#!/usr/bin/env python3
"""Safe local application installer for Tartarus.

The shell only asks this helper to inspect a dropped file. Installation is
explicit and runs in a visible terminal, so package-manager prompts never hide
behind the shell.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path


HOME = Path.home()
APP_ROOT = HOME / ".local" / "share" / "tartarus" / "apps"
BIN_ROOT = HOME / ".local" / "bin"
DESKTOP_ROOT = HOME / ".local" / "share" / "applications"


def detect(path: Path) -> tuple[str, str, bool, str]:
    name = path.name.lower()
    if name.endswith((".pkg.tar.zst", ".pkg.tar.xz", ".pkg.tar.gz", ".pkg.tar")):
        return "arch", "Paquete Arch", True, "Se instalará con pacman -U."
    if name.endswith(".flatpak"):
        return "flatpak", "Bundle Flatpak", True, "Se instalará para tu usuario."
    if name.endswith(".appimage"):
        return "appimage", "AppImage", True, "Se copiará a tu instalación local."
    if name.endswith(".deb"):
        return "deb", "Paquete Debian", True, "Se extraerá como aplicación portable."
    if name.endswith(".rpm"):
        return "rpm", "Paquete RPM", True, "Se extraerá como aplicación portable."
    if name.endswith((".tar", ".tar.gz", ".tgz", ".tar.xz", ".tar.zst", ".tar.bz2")):
        return "archive", "Archivo comprimido", True, "Se extraerá en tu carpeta local de aplicaciones."
    return "unknown", "Formato no reconocido", False, "Acepta AppImage, Flatpak, paquetes Arch, DEB, RPM y tarballs."


def safe_slug(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9._-]+", "-", value).strip("-.")
    return value[:80] or "app"


def inspect_file(raw: str) -> dict:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        return {"ok": False, "error": "El archivo ya no existe."}
    kind, label, supported, detail = detect(path)
    return {
        "ok": True,
        "path": str(path),
        "name": path.name,
        "title": path.stem,
        "kind": kind,
        "kindLabel": label,
        "supported": supported,
        "detail": detail,
        "size": path.stat().st_size,
    }


def run(command: list[str]) -> int:
    print("$ " + " ".join(command), flush=True)
    return subprocess.run(command, check=False).returncode


def write_desktop(name: str, executable: Path) -> None:
    DESKTOP_ROOT.mkdir(parents=True, exist_ok=True)
    desktop_id = safe_slug(name)
    desktop = DESKTOP_ROOT / f"tartarus-{desktop_id}.desktop"
    desktop.write_text(
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={name}\n"
        f"Exec={executable} %U\n"
        "Terminal=false\n"
        "Categories=Utility;\n",
        encoding="utf-8",
    )
    desktop.chmod(0o644)


def install_appimage(path: Path) -> None:
    APP_ROOT.mkdir(parents=True, exist_ok=True)
    target = APP_ROOT / f"{safe_slug(path.stem)}.AppImage"
    shutil.copy2(path, target)
    target.chmod(target.stat().st_mode | 0o111)
    write_desktop(path.stem, target)
    print(f"Instalada en {target}")


def safe_members(names: list[str]) -> None:
    for name in names:
        item = Path(name)
        if item.is_absolute() or ".." in item.parts:
            raise RuntimeError(f"El archivo contiene una ruta insegura: {name}")


def extract_tar(path: Path, target: Path) -> None:
    listing = subprocess.run(
        ["tar", "-tf", str(path)], capture_output=True, text=True, check=False
    )
    if listing.returncode != 0:
        raise RuntimeError("No se pudo inspeccionar el archivo comprimido.")
    safe_members(listing.stdout.splitlines())
    target.mkdir(parents=True, exist_ok=True)
    code = run([
        "tar", "--extract", "--file", str(path), "--directory", str(target),
        "--no-same-owner", "--no-same-permissions",
    ])
    if code != 0:
        raise RuntimeError("No se pudo extraer el archivo.")


def extract_deb(path: Path, target: Path) -> None:
    if shutil.which("dpkg-deb"):
        target.mkdir(parents=True, exist_ok=True)
        if run(["dpkg-deb", "-x", str(path), str(target)]) != 0:
            raise RuntimeError("No se pudo extraer el paquete DEB.")
        return
    raise RuntimeError("Para extraer DEB necesitas dpkg-deb instalado.")


def extract_rpm(path: Path, target: Path) -> None:
    if not shutil.which("rpm2cpio") or not shutil.which("cpio"):
        raise RuntimeError("Para extraer RPM necesitas rpm2cpio y cpio instalados.")
    target.mkdir(parents=True, exist_ok=True)
    source = subprocess.Popen(["rpm2cpio", str(path)], stdout=subprocess.PIPE)
    result = subprocess.run(["cpio", "-idm", "--no-absolute-filenames"], cwd=target, stdin=source.stdout, check=False)
    source.wait()
    if result.returncode != 0 or source.returncode != 0:
        raise RuntimeError("No se pudo extraer el paquete RPM.")


def register_extracted(path: Path, title: str) -> None:
    candidates = list(path.rglob("*.desktop"))
    if not candidates:
        print(f"Archivos extraídos en {path}")
        print("No se encontró un archivo .desktop para añadirlo al launcher.")
        return
    desktop = candidates[0]
    executable = next((item for item in path.rglob("*") if item.is_file() and os.access(item, os.X_OK)), None)
    if executable:
        write_desktop(title, executable)
        print(f"Aplicación añadida al launcher: {title}")
    else:
        print(f"Archivos extraídos en {path}; no se encontró un ejecutable.")


def install_local(raw: str) -> int:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        print("El archivo ya no existe.", file=sys.stderr)
        return 2
    kind, _, supported, _ = detect(path)
    if not supported:
        print("Formato no reconocido.", file=sys.stderr)
        return 2
    if kind == "arch":
        # pkexec provides the graphical polkit prompt and does not require a
        # terminal. Keep pacman's confirmation non-interactive because the
        # shell owns the visible install state.
        return run(["pkexec", "pacman", "-U", "--noconfirm", str(path)])
    if kind == "flatpak":
        return run(["flatpak", "install", "--user", str(path)])
    if kind == "appimage":
        install_appimage(path)
        return 0

    target = APP_ROOT / safe_slug(path.stem)
    if target.exists():
        shutil.rmtree(target)
    if kind == "deb":
        extract_deb(path, target)
    elif kind == "rpm":
        extract_rpm(path, target)
    else:
        extract_tar(path, target)
    register_extracted(target, path.stem)
    return 0


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in {"inspect", "install"}:
        print("Uso: app-installer.py inspect|install ARCHIVO", file=sys.stderr)
        return 2
    if sys.argv[1] == "inspect":
        print(json.dumps(inspect_file(sys.argv[2]), ensure_ascii=False))
        return 0
    return install_local(sys.argv[2])


if __name__ == "__main__":
    raise SystemExit(main())
