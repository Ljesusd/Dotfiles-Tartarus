"""Recover launcher icons without executing application binaries."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def icon_key(value):
    path = Path(value)
    return path.stem if path.suffix.lower() in {'.png', '.svg', '.xpm', '.ico'} else path.name


def desktop_fields(text):
    fields = {}
    active = False
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('['):
            active = line == '[Desktop Entry]'
        elif active and '=' in line and not line.startswith('#'):
            key, value = line.split('=', 1)
            fields[key] = value
    return fields


def local_icon(root, desktop, value):
    root = root.resolve()
    name = Path(value)
    candidates = [desktop.parent / name, root / str(name).lstrip('/')]
    if value:
        candidates += sorted(root.rglob('*'), key=lambda p: str(p))
    for candidate in candidates:
        resolved = candidate.resolve()
        if root not in resolved.parents or not resolved.is_file():
            continue
        if candidate in candidates[:2] or (
            candidate.suffix.lower() in {'.png', '.svg', '.xpm', '.ico'}
            and candidate.stem.lower() == icon_key(value).lower()
        ):
            return resolved
    return None


def appimage_icon(source, destination):
    tool = shutil.which('7z') or shutil.which('7zz')
    if not tool:
        raise RuntimeError('Falta 7z (paquete 7zip) para recuperar el icono AppImage')
    listing = subprocess.run([tool, 'l', '-slt', '--', str(source)],
                             capture_output=True, text=True, timeout=30, check=True)
    records = []
    for block in listing.stdout.partition('----------')[2].split('\n\n'):
        fields = dict(line.split(' = ', 1) for line in block.splitlines() if ' = ' in line)
        name = fields.get('Path', '')
        if not name or Path(name).is_absolute() or '..' in Path(name).parts:
            continue
        if fields.get('Folder') == '+' or fields.get('Mode', '').startswith('l'):
            continue
        size = int(fields.get('Size', '0'))
        if 0 < size <= 8 * 1024 * 1024:
            records.append((name, size))

    def read(name):
        return subprocess.run([tool, 'x', '-so', '-spd', '--', str(source), name],
                              capture_output=True, timeout=30, check=True).stdout

    icon_name = ''
    for name, size in sorted(records, key=lambda row: row[0].count('/')):
        if name.endswith('.desktop') and size < 256 * 1024:
            fields = desktop_fields(read(name).decode('utf-8', errors='replace'))
            if fields.get('Type', 'Application') == 'Application':
                icon_name = fields.get('Icon', '')
                break
    icons = [(name, size) for name, size in records
             if Path(name).suffix.lower() in {'.png', '.svg', '.xpm'}
             and (Path(name).stem == icon_key(icon_name) if icon_name else Path(name).stem == source.stem)]
    if not icons:
        raise RuntimeError('No se encontró un icono recuperable dentro del AppImage')
    name, _ = max(icons, key=lambda row: row[1])
    payload = read(name)
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / (source.stem + Path(name).suffix.lower())
    with tempfile.NamedTemporaryFile(dir=destination, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(payload)
    try:
        temporary.chmod(0o644)
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)
    return target


def replace_icon(text, icon):
    lines = text.splitlines()
    active = False
    replaced = False
    output = []
    for line in lines:
        if line.startswith('['):
            if active and not replaced:
                output.append('Icon=' + str(icon))
                replaced = True
            active = line == '[Desktop Entry]'
        if active and line.startswith('Icon='):
            line = 'Icon=' + str(icon)
            replaced = True
        output.append(line)
    if active and not replaced:
        output.append('Icon=' + str(icon))
    return '\n'.join(output) + '\n'
