#!/usr/bin/env bash
set -euo pipefail

steam_bin="$(command -v steam || true)"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
log="$runtime_dir/tartarus-steam-gaming.log"
state_file="$runtime_dir/tartarus-steam-gaming.state"
lock_file="$runtime_dir/tartarus-steam-gaming.lock"

exec 9>"$lock_file"
flock -n 9 || exit 0

if [[ -z "$steam_bin" ]]; then
    notify-send -a Tartarus -u critical "Steam nativo no está instalado" 2>/dev/null || true
    exit 1
fi

toggle_gaming_workspace() {
    if hyprctl dispatch 'hl.dsp.workspace.toggle_special("gaming")' >/dev/null 2>&1; then
        printf '%s toggle gaming\n' "$(date --iso-8601=seconds)" >>"$log"
    else
        printf '%s toggle_failed gaming\n' "$(date --iso-8601=seconds)" >>"$log"
        return 1
    fi
}

state_pid() {
    awk -F= '$1 == "gamescope_pid" { print $2; exit }' "$state_file" 2>/dev/null || true
}

managed_session_running() {
    local pid cmdline
    pid="$(state_pid)"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null && [[ -r "/proc/$pid/cmdline" ]]; then
        cmdline="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
        if [[ "$cmdline" == *gamescope* && "$cmdline" == *steam* && "$cmdline" == *gamepadui* && "$cmdline" =~ (^|[[:space:]])-e([[:space:]]|$) ]]; then
            return 0
        fi
    fi

    while read -r candidate; do
        [[ -r "/proc/$candidate/cmdline" ]] || continue
        cmdline="$(tr '\0' ' ' <"/proc/$candidate/cmdline" 2>/dev/null || true)"
        if [[ "$cmdline" == *gamescope* && "$cmdline" == *steam* && "$cmdline" == *gamepadui* && "$cmdline" =~ (^|[[:space:]])-e([[:space:]]|$) ]]; then
            write_state "$candidate"
            return 0
        fi
    done < <(pgrep -x gamescope 2>/dev/null || true)

    return 1
}

write_state() {
    local pid="$1" tmp="$state_file.tmp.$$"
    {
        printf 'gamescope_pid=%s\n' "$pid"
        printf 'started_at=%s\n' "$(date --iso-8601=seconds)"
    } >"$tmp"
    mv -f -- "$tmp" "$state_file"
}

conflicting_session() {
    pgrep -x steam >/dev/null 2>&1 || pgrep -x gamescope >/dev/null 2>&1
}

focused_mode() {
    local field fallback
    field="$1"
    fallback="$2"
    hyprctl monitors -j 2>/dev/null \
        | jq -r --arg field "$field" '.[] | select(.focused == true) | .[$field]' \
        | head -n 1 \
        | awk 'NF { print; found=1 } END { if (!found) exit 1 }' \
        || printf '%s\n' "$fallback"
}

if managed_session_running; then
    toggle_gaming_workspace
    exit 0
fi

rm -f -- "$state_file"

if conflicting_session; then
    printf '%s conflict: Steam or Gamescope is already running outside the managed session\n' \
        "$(date --iso-8601=seconds)" >>"$log"
    notify-send -a Tartarus -u normal \
        "Gaming Mode no iniciado" \
        "Steam o Gamescope ya está abierto fuera de la sesión gestionada." \
        2>/dev/null || true
    exit 1
fi

mkdir -p -- "$runtime_dir"
output_width="$(focused_mode width 1920)"
output_height="$(focused_mode height 1080)"
output_refresh="$(focused_mode refreshRate 100)"
output_refresh="$(printf '%.0f' "$output_refresh" 2>/dev/null || printf '100\n')"
gamescope \
    -e \
    -f \
    -b \
    --force-grab-cursor \
    -W "$output_width" -H "$output_height" \
    -w "$output_width" -h "$output_height" \
    -r "$output_refresh" \
    -- "$steam_bin" -gamepadui \
    >"$log" 2>&1 9>&- &

gamescope_pid=$!
write_state "$gamescope_pid"
printf '%s launch gamescope_pid=%s\n' "$(date --iso-8601=seconds)" "$gamescope_pid" >>"$log"
disown || true
toggle_gaming_workspace
