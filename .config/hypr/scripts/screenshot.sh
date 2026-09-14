#!/usr/bin/env bash

set -euo pipefail

mode="${1:-area}"

screenshot_dir="$HOME/Pictures/Screenshots"
timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
file="$screenshot_dir/$timestamp.png"

mkdir -p "$screenshot_dir"

notify() {
    local message="$1"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Screenshot" "$message"
    else
        printf '%s\n' "$message"
    fi
}

set_launcher_focus_close_suppressed() {
    local suppressed="$1"

    qs -c tartarus-shell ipc call launcher suppressFocusClose \
        "$suppressed" \
        >/dev/null 2>&1 || true
}

send_toast() {
    local monitor="$1"

    qs -c tartarus-shell ipc call toast pushImage \
        "$monitor" \
        "camera-photo" \
        "Screenshot captured" \
        "Copied to clipboard" \
        "$file" \
        >/dev/null 2>&1 || true
}

copy_png() {
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy --type image/png
    else
        cat >/dev/null
    fi
}

capture_monitor() {
    if ! command -v jq >/dev/null 2>&1; then
        notify "Missing dependency: jq"
        exit 1
    fi

    local monitor
    monitor="$(
        hyprctl monitors -j \
            | jq -r '.[] | select(.focused) | .name'
    )"

    if [ -z "$monitor" ] || [ "$monitor" = "null" ]; then
        notify "Could not determine focused monitor"
        exit 1
    fi

    if command -v wl-copy >/dev/null 2>&1; then
        grim -o "$monitor" - \
            | tee "$file" \
            | copy_png

        send_toast "$monitor"
        notify "Saved and copied: $file"
    else
        grim -o "$monitor" "$file"
        send_toast "$monitor"
        notify "Saved: $file"
    fi
}

capture_area() (
    local geometry
    local position
    local size
    local x
    local y
    local width
    local height
    local center_x
    local center_y
    local monitor
    local snapshot_dir
    local monitors_json
    local origin_x origin_y crop_x crop_y
    local dependency

    for dependency in grim slurp jq magick; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            notify "Missing dependency: $dependency"
            return 1
        fi
    done

    snapshot_dir="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/tartarus-screenshot.XXXXXX")"
    cleanup_area() {
        rm -f -- "$snapshot_dir/screen.png"
        rmdir -- "$snapshot_dir"
        set_launcher_focus_close_suppressed false
    }
    trap cleanup_area EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    monitors_json="$(hyprctl monitors -j)"
    origin_x="$(jq -er 'map(.x) | min' <<<"$monitors_json")"
    origin_y="$(jq -er 'map(.y) | min' <<<"$monitors_json")"

    # Capture BEFORE any overlay or focus change. Scale 1 maps logical
    # compositor coordinates to pixels, including mixed-scale outputs.
    grim -s 1 "$snapshot_dir/screen.png"
    set_launcher_focus_close_suppressed true

    if ! geometry="$(slurp)"; then
        return 0
    fi

    if [[ ! "$geometry" =~ ^-?[0-9]+,-?[0-9]+\ [0-9]+x[0-9]+$ ]]; then
        notify "Invalid screenshot selection"
        return 1
    fi

    read -r position size <<<"$geometry"

    x="${position%,*}"
    y="${position#*,}"
    width="${size%x*}"
    height="${size#*x}"
    crop_x=$((x - origin_x))
    crop_y=$((y - origin_y))
    if ((width <= 0 || height <= 0 || crop_x < 0 || crop_y < 0)); then
        notify "Selection is outside the captured screen"
        return 1
    fi

    magick "$snapshot_dir/screen.png" \
        -crop "${width}x${height}+${crop_x}+${crop_y}" +repage "$file"

    center_x=$((x + width / 2))
    center_y=$((y + height / 2))

    monitor="$(
            jq -r \
                --argjson x "$center_x" \
                --argjson y "$center_y" \
                '
                .[]
                | select(
                    $x >= .x
                    and $x < (.x + (if (.transform % 2) == 1 then .height else .width end) / .scale)
                    and $y >= .y
                    and $y < (.y + (if (.transform % 2) == 1 then .width else .height end) / .scale)
                )
                | .name
                ' <<<"$monitors_json" |
            head -n1
    )"

    if command -v wl-copy >/dev/null 2>&1; then
        copy_png < "$file"

        if [ -n "$monitor" ] && [ "$monitor" != "null" ]; then
            send_toast "$monitor"
        fi
        notify "Saved and copied: $file"
    else
        if [ -n "$monitor" ] && [ "$monitor" != "null" ]; then
            send_toast "$monitor"
        fi
        notify "Saved: $file"
    fi

)

case "$mode" in
    monitor)
        capture_monitor
        ;;

    area)
        capture_area
        ;;

    *)
        printf 'Usage: %s {monitor|area}\n' "$0" >&2
        exit 1
        ;;
esac
