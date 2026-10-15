#!/usr/bin/env python3
"""Safe local application installer for Tartarus.

The shell only asks this helper to inspect a dropped file. Installation is
explicit; privileged package operations use the desktop Polkit agent when one
is available and fall back to a visible terminal otherwise.
"""

from __future__ import annotations

import json
import os
import re
import signal
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from installer_icons import appimage_icon, desktop_fields, local_icon, replace_icon


HOME = Path.home()
APP_ROOT = HOME / ".local" / "share" / "tartarus" / "apps"
DESKTOP_ROOT = HOME / ".local" / "share" / "applications"

# Some Debian packages are distribution launchers rather than portable
# applications. Steam's Debian package is one of those: it installs a small
# launcher plus apt/policykit integration and expects its dependencies in the
# system. On Arch, the supported equivalent is the native multilib package.
NATIVE_DEB_PACKAGES = {
    "steam": "steam",
    "steam-launcher": "steam",
    "steam-installer": "steam",
}

_active_process: subprocess.Popen | None = None
POLKIT_AGENT_NAMES = (
    "tartarus-polkit-agent",
    "lxqt-policykit-agent",
    "polkit-kde-authentication-agent-1",
    "polkit-mate",
)


def _stop_active_process(signum: int, _frame) -> None:
    """Stop a visible terminal and its installer when Quickshell cancels us."""
    process = _active_process
    if process is not None and process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    raise SystemExit(128 + signum)


signal.signal(signal.SIGTERM, _stop_active_process)
signal.signal(signal.SIGINT, _stop_active_process)


def detect(path: Path) -> tuple[str, str, bool, str]:
    name = path.name.lower()
    if name.endswith((".pkg.tar.zst", ".pkg.tar.xz", ".pkg.tar.gz", ".pkg.tar")):
        return "arch", "Paquete Arch", True, "Se instalará con pacman -U."
    if name.endswith(".flatpakref"):
        return "flatpakref", "Referencia Flatpak", True, "Se descargará desde el repositorio indicado, normalmente Flathub."
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
    return "unknown", "Formato no reconocido", False, "Acepta AppImage, Flatpak/FlatpakRef, paquetes Arch, DEB, RPM y tarballs."


def safe_slug(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9._-]+", "-", value).strip("-.")
    return value[:80] or "app"


def app_title(path: Path) -> str:
    """Turn common archive names into a useful launcher label."""
    value = path.name
    value = re.sub(
        r"\.(appimage|flatpakref?|deb|rpm|tar|tar\.[a-z0-9]+|linux-[a-z0-9_-]+)$",
        "",
        value,
        flags=re.I,
    )
    value = re.sub(r"[-_.](x86_64|aarch64|amd64|arm64)$", "", value, flags=re.I)
    value = re.sub(r"[._-]linux$", "", value, flags=re.I)
    return value.replace("-", " ").replace("_", " ").strip().title() or "Aplicación"


def _tar_compression_args(member: str) -> list[str]:
    suffix = Path(member).suffix.lower()
    if suffix == ".gz":
        return ["-z"]
    if suffix == ".xz":
        return ["-J"]
    if suffix == ".bz2":
        return ["-j"]
    if suffix == ".zst":
        return ["--zstd"]
    return []


def deb_control_fields(path: Path) -> dict[str, str]:
    """Read the small control record without installing the Debian package."""
    if shutil.which("dpkg-deb"):
        result = subprocess.run(
            ["dpkg-deb", "-f", str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
        raw = result.stdout if result.returncode == 0 else ""
    else:
        if not shutil.which("ar") or not shutil.which("tar"):
            return {}
        members = subprocess.run(
            ["ar", "t", str(path)], capture_output=True, text=True, check=False
        )
        control_member = next(
            (line.strip() for line in members.stdout.splitlines()
             if line.strip().startswith("control.tar")),
            None,
        )
        if members.returncode != 0 or not control_member:
            return {}
        payload = subprocess.run(
            ["ar", "p", str(path), control_member],
            capture_output=True,
            check=False,
        )
        if payload.returncode != 0:
            return {}
        result = subprocess.run(
            ["tar", *_tar_compression_args(control_member), "--extract",
             "--to-stdout", "--file", "-", "./control"],
            input=payload.stdout,
            capture_output=True,
            check=False,
        )
        raw = result.stdout.decode("utf-8", errors="replace") if result.returncode == 0 else ""

    fields: dict[str, str] = {}
    current = ""
    for line in raw.splitlines():
        if line[:1].isspace() and current:
            fields[current] += " " + line.strip()
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        current = key.strip()
        fields[current] = value.strip()
    return fields


def native_arch_package(path: Path) -> str | None:
    if path.suffix.lower() != ".deb":
        return None
    package = deb_control_fields(path).get("Package", "").strip().lower()
    return NATIVE_DEB_PACKAGES.get(package)


def inspect_file(raw: str) -> dict:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        return {"ok": False, "error": "El archivo ya no existe."}
    kind, label, supported, detail = detect(path)
    native_package = native_arch_package(path) if kind == "deb" else None
    if native_package:
        label = "Paquete Debian · equivalente Arch"
        detail = f"Se instalará el paquete nativo de Arch: {native_package}."
    return {
        "ok": True,
        "path": str(path),
        "name": path.name,
        "title": app_title(path),
        "kind": kind,
        "kindLabel": label,
        "supported": supported,
        "detail": detail,
        "nativePackage": native_package or "",
        "size": path.stat().st_size,
    }


def run(command: list[str]) -> int:
    global _active_process
    print("$ " + " ".join(command), flush=True)
    process = subprocess.Popen(command, start_new_session=True)
    _active_process = process
    try:
        return process.wait()
    finally:
        _active_process = None


def polkit_agent_running() -> bool:
    """Return whether this user's graphical Polkit agent is active."""
    if not shutil.which("pkexec") or not shutil.which("pidof"):
        return False

    uid = str(os.getuid())
    for name in POLKIT_AGENT_NAMES:
        result = subprocess.run(
            ["pidof", "-x", name],
            stdout=subprocess.PIPE,
            text=True,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode != 0:
            continue

        for raw_pid in result.stdout.split():
            try:
                pid = int(raw_pid)
                if os.stat(f"/proc/{pid}").st_uid == int(uid):
                    return True
            except (FileNotFoundError, ValueError, PermissionError):
                continue
    return False


def run_visible(command: list[str], title: str) -> int:
    """Run privileged/package work in a terminal with visible output."""
    command_to_run = list(command)
    if os.geteuid() != 0:
        if shutil.which("sudo"):
            command_to_run.insert(0, "sudo")
        elif shutil.which("pkexec"):
            command_to_run.insert(0, "pkexec")
        else:
            raise RuntimeError("Se necesita sudo o pkexec para instalar el paquete.")

    if shutil.which("kitty"):
        return run([
            "kitty",
            "--class", "tartarus-installer",
            "--title", title,
            "-e",
            *command_to_run,
        ])
    if os.geteuid() == 0:
        return run(command_to_run)
    return run(command_to_run)


def run_privileged(command: list[str], title: str) -> int:
    """Run a privileged command through Polkit, with a safe visible fallback."""
    if os.geteuid() == 0:
        return run(command)

    if polkit_agent_running():
        # The agent owns the password dialog. No password is passed through
        # QML, Python, stdin, command-line arguments, or shell logs.
        return run(["pkexec", *command])

    # A missing agent must never leave pkexec waiting invisibly. The terminal
    # fallback keeps the package-manager prompt and output visible.
    return run_visible(command, title)


def desktop_exec_path(path: Path) -> str:
    """Quote an executable for a desktop entry without invoking a shell."""
    value = str(path)
    if not any(char.isspace() for char in value) and '"' not in value:
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def desktop_value(value: str) -> str:
    """Keep values written to a .desktop file on a single safe line."""
    return " ".join(str(value).replace("\r", " ").replace("\n", " ").split())


def write_desktop(name: str, executable: Path, icon: Path | None = None) -> None:
    DESKTOP_ROOT.mkdir(parents=True, exist_ok=True)
    desktop_id = safe_slug(name)
    desktop = DESKTOP_ROOT / f"tartarus-{desktop_id}.desktop"
    safe_name = desktop_value(name) or "Aplicación"
    icon_line = f"Icon={desktop_value(icon)}\n" if icon else ""
    desktop.write_text(
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={safe_name}\n"
        f"Exec={desktop_exec_path(executable)} %U\n"
        f"TryExec={desktop_exec_path(executable)}\n"
        f"{icon_line}"
        "Terminal=false\n"
        "Categories=Utility;\n",
        encoding="utf-8",
    )
    desktop.chmod(0o644)
    if shutil.which('update-desktop-database'):
        subprocess.run(['update-desktop-database', str(DESKTOP_ROOT)], check=False)


def install_appimage(path: Path) -> None:
    APP_ROOT.mkdir(parents=True, exist_ok=True)
    target = APP_ROOT / f"{safe_slug(path.stem)}.AppImage"
    shutil.copy2(path, target)
    target.chmod(target.stat().st_mode | 0o111)
    icon = None
    try:
        icon = appimage_icon(target, APP_ROOT / '.icons')
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f'Aviso: aplicación instalada sin icono: {error}', file=sys.stderr)
    write_desktop(app_title(path), target, icon)
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

    # Arch does not normally ship dpkg-deb. A .deb is an ar archive containing
    # a data.tar.* member, so extract only that payload without installing it.
    if not shutil.which("ar") or not shutil.which("tar"):
        raise RuntimeError("No se puede extraer DEB: faltan ar o tar.")
    members = subprocess.run(["ar", "t", str(path)], capture_output=True, text=True, check=False)
    data_member = next((line.strip() for line in members.stdout.splitlines() if line.strip().startswith("data.tar")), None)
    if members.returncode != 0 or not data_member:
        raise RuntimeError("El DEB no contiene un payload data.tar válido.")

    compression_flag = {
        ".gz": "-z",
        ".xz": "-J",
        ".bz2": "-j",
        ".zst": "--zstd",
    }.get(Path(data_member).suffix, "")
    if compression_flag == "--zstd":
        tar_list_command = ["tar", "--zstd", "--list"]
    else:
        tar_list_command = ["tar", compression_flag, "--list"] if compression_flag else ["tar", "--list"]

    payload = subprocess.Popen(["ar", "p", str(path), data_member], stdout=subprocess.PIPE)
    listing = subprocess.run(tar_list_command + ["-f", "-"], stdin=payload.stdout, capture_output=True, text=True, check=False)
    payload.stdout.close()
    payload.wait()
    if listing.returncode != 0:
        raise RuntimeError("No se pudo inspeccionar el contenido del DEB.")
    safe_members(listing.stdout.splitlines())

    target.mkdir(parents=True, exist_ok=True)
    payload = subprocess.Popen(["ar", "p", str(path), data_member], stdout=subprocess.PIPE)
    tar_extract_command = ["tar", compression_flag, "--extract", "--file", "-"] if compression_flag else ["tar", "--extract", "--file", "-"]
    if compression_flag == "--zstd":
        tar_extract_command = ["tar", "--zstd", "--extract", "--file", "-"]
    result = subprocess.run(
        tar_extract_command + ["--directory", str(target), "--no-same-owner", "--no-same-permissions"],
        stdin=payload.stdout,
        check=False,
    )
    payload.stdout.close()
    payload.wait()
    if result.returncode != 0 or payload.returncode != 0:
        raise RuntimeError("No se pudo extraer el contenido del DEB.")


def extract_rpm(path: Path, target: Path) -> None:
    if not shutil.which("rpm2cpio"):
        if not shutil.which("pkexec") and not shutil.which("sudo"):
            raise RuntimeError("Falta rpm2cpio y no hay un método de autenticación disponible para instalar rpm-tools.")
        if run_privileged(
            ["pacman", "-S", "--needed", "--noconfirm", "rpm-tools"],
            "Preparando herramientas RPM",
        ) != 0:
            raise RuntimeError("No se pudo instalar rpm-tools para extraer el RPM.")
    if not shutil.which("rpm2cpio") or not shutil.which("cpio"):
        raise RuntimeError("Para extraer RPM necesitas rpm2cpio y cpio instalados.")

    source = subprocess.Popen(["rpm2cpio", str(path)], stdout=subprocess.PIPE)
    listing = subprocess.run(
        ["cpio", "-t"],
        cwd=target.parent if target.parent.exists() else None,
        stdin=source.stdout,
        capture_output=True,
        text=True,
        check=False,
    )
    source.stdout.close()
    source.wait()
    if listing.returncode != 0 or source.returncode != 0:
        raise RuntimeError("No se pudo inspeccionar el contenido del RPM.")
    safe_members(listing.stdout.splitlines())

    target.mkdir(parents=True, exist_ok=True)
    source = subprocess.Popen(["rpm2cpio", str(path)], stdout=subprocess.PIPE)
    result = subprocess.run(
        ["cpio", "-idm", "--no-absolute-filenames"],
        cwd=target,
        stdin=source.stdout,
        check=False,
    )
    source.stdout.close()
    source.wait()
    if result.returncode != 0 or source.returncode != 0:
        raise RuntimeError("No se pudo extraer el paquete RPM.")


def executable_candidates(path: Path, title: str) -> list[Path]:
    """Find the actual launcher in a portable archive without picking a helper."""
    ignored = {"updater", "pingsender", "gfxtest", "crashreporter"}
    title_tokens = {
        token.lower()
        for token in re.split(r"[^a-zA-Z0-9]+", title)
        if len(token) >= 2
    }
    candidates = [item for item in path.rglob("*") if item.is_file() and os.access(item, os.X_OK)]

    def score(item: Path) -> tuple[int, int, int, str]:
        name = item.name.lower()
        stem = item.stem.lower()
        score_value = 0
        if name in title_tokens or stem in title_tokens:
            score_value += 100
        if name in {"run", "start", "launch"}:
            score_value += 35
        if name.endswith("-bin"):
            score_value -= 20
        if name in ignored or stem in ignored:
            score_value -= 100
        if "." not in name:
            score_value += 15
        return score_value, -len(item.relative_to(path).parts), -len(name), str(item)

    return sorted(candidates, key=score, reverse=True)


def register_extracted(path: Path, title: str) -> bool:
    candidates = list(path.rglob("*.desktop"))
    executable = None
    icon = None

    def parse_desktop(desktop: Path) -> tuple[Path | None, str, Path | None]:
        values = {}
        in_entry = False
        for line in desktop.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if line.startswith("[") and line.endswith("]"):
                in_entry = line == "[Desktop Entry]"
                continue
            if in_entry and "=" in line and not line.startswith("#"):
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()

        if values.get("Type", "Application") != "Application":
            return None, "", None

        parsed_exec = None
        try:
            parsed_exec = shlex.split(values.get("Exec", ""), posix=True)
        except ValueError:
            parsed_exec = None

        possible = None
        if parsed_exec:
            exec_value = parsed_exec[0]
            possible = (Path(exec_value) if exec_value.startswith("/") else desktop.parent / exec_value).resolve()
            if not (possible.is_file() and os.access(possible, os.X_OK) and path in possible.parents):
                possible = None
            if possible is None and '..' not in Path(exec_value).parts:
                for item in sorted(path.rglob(Path(exec_value).name)):
                    resolved = item.resolve()
                    if path in resolved.parents and resolved.is_file() and os.access(resolved, os.X_OK):
                        possible = resolved
                        break

        possible_icon = None
        icon_value = values.get("Icon", "").strip()
        if icon_value:
            icon_path = Path(icon_value)
            if icon_path.is_absolute():
                candidate = icon_path.resolve()
                if candidate.is_file() and path in candidate.parents:
                    possible_icon = candidate
            else:
                candidate = (desktop.parent / icon_path).resolve()
                if candidate.is_file() and path in candidate.parents:
                    possible_icon = candidate
                else:
                    icon_stem = icon_path.stem.lower()
                    possible_icon = next(
                        (item for item in path.rglob("*")
                         if item.is_file()
                         and item.suffix.lower() in {".png", ".svg", ".xpm", ".ico"}
                         and item.stem.lower() == icon_stem),
                        None,
                    )

        if possible_icon is None and icon_value:
            possible_icon = local_icon(path, desktop, icon_value)
        return possible, values.get("Name", "").strip(), possible_icon

    # Prefer a valid application desktop file, but never trust an Exec path
    # that escapes the extracted directory or points to a helper program.
    for desktop in candidates:
        candidate, candidate_title, candidate_icon = parse_desktop(desktop)
        if candidate:
            executable = candidate
            title = candidate_title or title
            icon = candidate_icon
            break

    if executable is None:
        executable = next(iter(executable_candidates(path, title)), None)
        if executable:
            icon = next(
                (item for item in path.rglob("*")
                 if item.is_file() and item.suffix.lower() in {".png", ".svg", ".xpm"}
                 and any(part in item.name.lower() for part in (executable.stem.lower(), title.lower().split()[0]))),
                None,
            )
            if icon is None:
                icon = next(
                    (item for item in path.rglob("*")
                     if item.is_file() and item.name.lower().startswith("default")
                     and item.suffix.lower() in {".png", ".svg", ".xpm"}),
                    None,
                )

    if executable:
        write_desktop(title, executable, icon)
        print(f"Aplicación añadida al launcher: {title}")
        return True
    else:
        print(f"Archivos extraídos en {path}; no se encontró un ejecutable.")
        return False


def remove_portable_artifact(source: Path) -> None:
    """Remove a stale entry previously created for a package extraction."""
    target = APP_ROOT / safe_slug(source.stem)
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.is_dir():
        shutil.rmtree(target)

    desktop = DESKTOP_ROOT / f"tartarus-{safe_slug(app_title(source))}.desktop"
    if desktop.is_file() or desktop.is_symlink():
        desktop.unlink()


def install_native_deb(path: Path) -> int | None:
    """Install a known system DEB through its supported Arch package."""
    package = native_arch_package(path)
    if not package:
        return None
    if not shutil.which("pacman"):
        raise RuntimeError("No se encontró pacman para instalar el paquete nativo.")

    code = run_privileged(
        ["pacman", "-S", "--needed", "--noconfirm", package],
        f"Instalando {package}",
    )
    if code == 0:
        # The old DEB attempt may have left a fake portable launcher behind.
        # Remove only the artifact generated from this exact source filename.
        remove_portable_artifact(path)
        print(f"Instalado como paquete nativo de Arch: {package}")
    return code


def install_local(raw: str) -> int:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        print("El archivo ya no existe.", file=sys.stderr)
        return 2
    kind, _, supported, _ = detect(path)
    if not supported:
        print("Formato no reconocido.", file=sys.stderr)
        return 2
    if kind == "deb":
        native_result = install_native_deb(path)
        if native_result is not None:
            return native_result
    if kind == "arch":
        # Keep pacman's confirmation non-interactive because the shell owns
        # the visible install state. Authentication is delegated to Polkit
        # when its graphical agent is running.
        return run_privileged(
            ["pacman", "-U", "--noconfirm", str(path)],
            f"Instalando {app_title(path)}",
        )
    if kind == "flatpak":
        return run([
            "flatpak", "install", "--user", "--noninteractive", "--assumeyes",
            "--bundle", str(path),
        ])
    if kind == "flatpakref":
        return run([
            "flatpak", "install", "--user", "--noninteractive", "--assumeyes",
            "--from", str(path),
        ])
    if kind == "appimage":
        install_appimage(path)
        return 0

    APP_ROOT.mkdir(parents=True, exist_ok=True)
    target = APP_ROOT / safe_slug(path.stem)
    staging = Path(tempfile.mkdtemp(prefix=f".{safe_slug(path.stem)}-", dir=APP_ROOT))
    try:
        if kind == "deb":
            extract_deb(path, staging)
        elif kind == "rpm":
            extract_rpm(path, staging)
        else:
            extract_tar(path, staging)
        if target.exists():
            shutil.rmtree(target)
        staging.rename(target)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    return 0 if register_extracted(target, app_title(path)) else 1


def repair_icons() -> int:
    pending = 0
    for desktop in sorted(DESKTOP_ROOT.glob('tartarus-*.desktop')):
        text = desktop.read_text(encoding='utf-8')
        values = desktop_fields(text)
        current = values.get('Icon', '')
        if current and (not Path(current).is_absolute() or Path(current).is_file()):
            continue
        try:
            executable = Path(shlex.split(values.get('Exec', ''))[0]).resolve()
            if APP_ROOT.resolve() not in executable.parents:
                continue
            if executable.suffix.lower() == '.appimage':
                icon = appimage_icon(executable, APP_ROOT / '.icons')
            else:
                relative = executable.relative_to(APP_ROOT.resolve())
                root = APP_ROOT / relative.parts[0]
                icon = None
                for entry in sorted(root.rglob('*.desktop')):
                    fields = desktop_fields(entry.read_text(encoding='utf-8', errors='replace'))
                    if fields.get('Icon'):
                        icon = local_icon(root, entry, fields['Icon'])
                    if icon:
                        break
                if not icon:
                    raise RuntimeError('No se encontró un icono en los archivos instalados')
            backup_root = DESKTOP_ROOT / '.tartarus-icon-backups'
            backup_root.mkdir(exist_ok=True)
            backup = backup_root / desktop.name
            if not backup.exists():
                shutil.copy2(desktop, backup)
            desktop.write_text(replace_icon(text, icon), encoding='utf-8')
            print(f'Icono reparado: {values.get("Name", desktop.name)}')
        except (RuntimeError, OSError, ValueError, IndexError, subprocess.SubprocessError) as error:
            pending += 1
            print(f'Pendiente: {desktop.name}: {error}', file=sys.stderr)
    if shutil.which('update-desktop-database'):
        subprocess.run(['update-desktop-database', str(DESKTOP_ROOT)], check=False)
    return 1 if pending else 0


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == 'repair-icons':
        return repair_icons()
    if len(sys.argv) < 3 or sys.argv[1] not in {"inspect", "install"}:
        print("Uso: app-installer.py inspect|install ARCHIVO", file=sys.stderr)
        return 2
    if sys.argv[1] == "inspect":
        print(json.dumps(inspect_file(sys.argv[2]), ensure_ascii=False))
        return 0
    try:
        return install_local(sys.argv[2])
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
