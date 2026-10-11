#!/usr/bin/env bash
set -euo pipefail
capture_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../capture" && pwd)"
available() {
    command -v qs >/dev/null && command -v wl-copy >/dev/null && command -v flock >/dev/null &&
    [ -f "$capture_root/shell.qml" ] &&
    [ -d /usr/lib/qt6/qml/Qt5Compat/GraphicalEffects ]
}
case "${1:-area}" in
    --check) available; exit $? ;;
    --help) printf '%s\n' 'Capturas de Tartarus: area | monitor'; exit 0 ;;
    area|region) capture_mode=region; fallback_mode=area ;;
    monitor) capture_mode=monitor; fallback_mode=monitor ;;
    *) printf '%s\n' 'Modo de captura no válido' >&2; exit 2 ;;
esac
if ! available; then
    command -v notify-send >/dev/null && notify-send -a Tartarus 'Captura básica' 'Editor no disponible. Revisa Quickshell, wl-clipboard y qt6-5compat.' || true
    exec bash "$HOME/.config/hypr/scripts/screenshot.sh" "$fallback_mode"
fi
capture_runtime="${XDG_RUNTIME_DIR:-$HOME/.cache}"
mkdir -p -- "$capture_runtime"
exec 9>"$capture_runtime/tartarus-capture.lock"
flock -n 9 || exit 0
# Allow the sidebar close animation to finish before freezing the desktop.
sleep 0.3
exec env TARTARUS_CAPTURE_MODE="$capture_mode" TARTARUS_CAPTURE_SAVEDIR="$HOME/Pictures/Screenshots" qs -p "$capture_root"
