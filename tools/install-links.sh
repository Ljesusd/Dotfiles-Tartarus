#!/usr/bin/env bash
# Explicit opt-in deployment. Existing configurations are moved, never deleted.
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" != --apply ]]; then
    printf 'Usage: bash tools/install-links.sh --apply\nCreates config/bin/application links with backups. Does not start services.\n'
    exit 0
fi
backup="$(mktemp -d "${TMPDIR:-/tmp}/tartarus-link-backup.XXXXXX")"
# Keep backups persistently rather than under /tmp.
install -d -m 700 "${XDG_STATE_HOME:-$HOME/.local/state}/tartarus-install"
mv -- "$backup" "${XDG_STATE_HOME:-$HOME/.local/state}/tartarus-install/"
backup="${XDG_STATE_HOME:-$HOME/.local/state}/tartarus-install/${backup##*/}"
link() {
    local relative="$1" target="$HOME/$1" source="$repo/$1"
    [[ "$(readlink -f -- "$target" 2>/dev/null || true)" == "$source" ]] && return 0
    mkdir -p -- "$(dirname -- "$target")"
    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p -- "$backup/$(dirname -- "$relative")"
        mv -- "$target" "$backup/$relative"
    fi
    ln -s -- "$source" "$target"
}
for config in hypr quickshell/tartarus-shell kitty zed; do
    [[ ! -d "$repo/.config/$config" ]] || link ".config/$config"
done
for directory in .local/bin .local/share/applications .config/systemd/user; do
    for source in "$repo/$directory"/*; do
        [[ -f "$source" ]] || continue
        link "$directory/${source##*/}"
    done
done
systemctl --user daemon-reload
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications"
printf 'Links installed. Backups: %s\nServices were not enabled or started.\n' "$backup"
