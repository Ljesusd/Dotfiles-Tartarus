#!/usr/bin/env bash

set -euo pipefail

folder="${1:-$HOME/Pictures/Wallpaper}"

case "$folder" in
    ~/*) folder="$HOME/${folder#~/}" ;;
esac

mkdir -p "$folder"

# Try the desktop's preferred file manager first, then a fallback list.
desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
desktop="$(printf '%s' "$desktop" | tr '[:upper:]' '[:lower:]')"

preferred=""
case "$desktop" in
    *kde*|*plasma*) preferred="/usr/bin/dolphin" ;;
    *gnome*|*cinnamon*|*unity*|*mate*) preferred="/usr/bin/nautilus" ;;
    *xfce*|*lxde*|*lxqt*|*budgie*) preferred="/usr/bin/thunar" ;;
    *) preferred="" ;;
esac

candidates=(/usr/bin/nautilus /usr/bin/dolphin /usr/bin/thunar /usr/bin/nemo /usr/bin/caja /usr/bin/pcmanfm-qt /usr/bin/pcmanfm)

launcher=""

launch() {
    local fm="$1"
    if ! command -v "$fm" >/dev/null 2>&1; then
        return 1
    fi

    if "$fm" --help 2>/dev/null | grep -q -- "--new-window"; then
        "$fm" --new-window "$folder" >/dev/null 2>&1 &
    else
        "$fm" "$folder" >/dev/null 2>&1 &
    fi

    launcher="$fm"
    return 0
}

if [ -n "$preferred" ] && launch "$preferred"; then
    :
elif [ "$preferred" != "" ]; then
    for fm in "${candidates[@]}"; do
        if launch "$fm"; then
            break
        fi
    done
elif [ -z "$preferred" ]; then
    for fm in "${candidates[@]}"; do
        if launch "$fm"; then
            break
        fi
    done
fi

if [ -z "$launcher" ]; then
    if command -v gio >/dev/null 2>&1; then
        gio open "$folder" >/dev/null 2>&1 &
        exit 0
    fi

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "file://$folder" >/dev/null 2>&1 &
        exit 0
    fi

    echo "error=no_file_manager"
    exit 1
fi

# Force floating only for the newly opened manager window (best effort on Hyprland).
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    before_addrs="$(hyprctl clients -j 2>/dev/null | jq -r '.[].address' | sort -u)"

    for _ in $(seq 1 60); do
        sleep 0.12

        now_addrs="$(hyprctl clients -j 2>/dev/null | jq -r '.[].address' | sort -u)"
        target_addr=""

        while IFS= read -r addr; do
            [ -z "$addr" ] && continue
            if ! grep -qxF "$addr" <<< "$before_addrs"; then
                target_addr="$addr"
                break
            fi
        done <<< "$now_addrs"

        if [ -n "$target_addr" ]; then
            hyprctl dispatch focuswindow "address:$target_addr" >/dev/null 2>&1 || true
            if ! hyprctl dispatch setfloating "address:$target_addr" >/dev/null 2>&1; then
                hyprctl dispatch focuswindow "address:$target_addr" >/dev/null 2>&1 || true
                hyprctl dispatch togglefloating >/dev/null 2>&1 || true
            fi
            hyprctl dispatch bringactivetotop >/dev/null 2>&1 || true
            break
        fi
    done
fi

exit 0
