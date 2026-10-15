#!/usr/bin/env bash
set -euo pipefail

steam_bin="$(command -v steam || true)"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
log="$runtime_dir/tartarus-steam-gaming.log"
state_file="$runtime_dir/tartarus-steam-gaming.state"
lock_file="$runtime_dir/tartarus-steam-gaming.lock"
compositor_state_file="$runtime_dir/tartarus-steam-gaming-compositor.state"

exec 9>"$lock_file"
flock -n 9 || exit 0

set_shell_gaming() {
    local enabled="$1"
    [[ "$enabled" == 1 || "$enabled" == true ]] && enabled=true || enabled=false
    command -v qs >/dev/null 2>&1 || return 0
    qs -c tartarus-shell ipc call performance setGaming "$enabled" >/dev/null 2>&1 || true
}

get_hypr_bool() {
    local option="$1"
    hyprctl getoption "$option" -j 2>/dev/null \
        | jq -r 'if .bool == true then "true" elif .bool == false then "false" else empty end' \
        | head -n 1
}

save_compositor_state() {
    [[ -e "$compositor_state_file" ]] && return 0
    local animations blur shadow
    animations="$(get_hypr_bool 'animations:enabled')"
    blur="$(get_hypr_bool 'decoration:blur:enabled')"
    shadow="$(get_hypr_bool 'decoration:shadow:enabled')"
    {
        printf 'animations_enabled=%s\n' "${animations:-true}"
        printf 'blur_enabled=%s\n' "${blur:-true}"
        printf 'shadow_enabled=%s\n' "${shadow:-true}"
    } >"$compositor_state_file"
}

set_compositor_gaming() {
    save_compositor_state
    hyprctl keyword animations:enabled false >/dev/null 2>&1 || true
    hyprctl keyword decoration:blur:enabled false >/dev/null 2>&1 || true
    hyprctl keyword decoration:shadow:enabled false >/dev/null 2>&1 || true
}

restore_compositor() {
    [[ -e "$compositor_state_file" ]] || return 0
    local animations blur shadow
    animations="$(awk -F= '$1 == "animations_enabled" { print $2; exit }' "$compositor_state_file")"
    blur="$(awk -F= '$1 == "blur_enabled" { print $2; exit }' "$compositor_state_file")"
    shadow="$(awk -F= '$1 == "shadow_enabled" { print $2; exit }' "$compositor_state_file")"
    [[ "$animations" == true || "$animations" == false ]] && hyprctl keyword animations:enabled "$animations" >/dev/null 2>&1 || true
    [[ "$blur" == true || "$blur" == false ]] && hyprctl keyword decoration:blur:enabled "$blur" >/dev/null 2>&1 || true
    [[ "$shadow" == true || "$shadow" == false ]] && hyprctl keyword decoration:shadow:enabled "$shadow" >/dev/null 2>&1 || true
    rm -f -- "$compositor_state_file"
}

cleanup_gaming() {
    restore_compositor
    set_shell_gaming 0
    rm -f -- "$state_file"
}

watch_session() {
    local watched_pid="$1"
    (
        while kill -0 "$watched_pid" 2>/dev/null; do
            sleep 2
        done
        exec 9>"$lock_file"
        flock 9
        if [[ "$(state_pid)" == "$watched_pid" ]]; then
            cleanup_gaming
        fi
    ) >/dev/null 2>&1 9>&- &
    disown || true
}

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
    done < <(pgrep -x 'gamescope|gamescope-wl' 2>/dev/null || true)

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
    pgrep -x steam >/dev/null 2>&1 || pgrep -x 'gamescope|gamescope-wl' >/dev/null 2>&1
}

steam_preload() {
    local entry result="" entries=()
    read -r -a entries <<< "${1//:/ }"
    for entry in "${entries[@]}"; do
        case "${entry##*/}" in
            libgamemodeauto.so*) continue ;;
        esac
        result+="${result:+:}$entry"
    done
    printf '%s' "$result"
}

wait_for_window() {
    local pid="$1" attempt
    for ((attempt=0; attempt<120; attempt++)); do
        kill -0 "$pid" 2>/dev/null || break
        if hyprctl clients -j 2>/dev/null | jq -e --argjson pid "$pid" \
            'any(.[]; .pid == $pid and .mapped == true and .workspace.name == "special:gaming")' >/dev/null; then
            return 0
        fi
        sleep 0.25
    done
    printf '%s no visible gaming window pid=%s\n' "$(date --iso-8601=seconds)" "$pid" >>"$log"
    notify-send -a Tartarus "Steam no mostró una ventana" "Consulta el registro: $log" 2>/dev/null || true
    return 1
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

normalize_refresh() {
    local value="${1:-}" rounded
    # Hyprland JSON uses a decimal point regardless of the session locale.
    # Capture printf before emitting anything: on error it can still output
    # a partial number, which must never be concatenated with the fallback.
    if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] \
        && rounded="$(LC_ALL=C printf '%.0f' "$value" 2>/dev/null)" \
        && [[ "$rounded" =~ ^[0-9]{1,4}$ ]] \
        && (( 10#$rounded >= 1 && 10#$rounded <= 1000 )); then
        printf '%s\n' "$rounded"
    else
        printf '100\n'
    fi
}

if managed_session_running; then
    managed_pid="$(state_pid)"
    wait_for_window "$managed_pid" || exit 1
    set_compositor_gaming
    set_shell_gaming 1
    toggle_gaming_workspace
    exit 0
fi

cleanup_gaming

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
output_refresh="$(normalize_refresh "$output_refresh")"
clean_preload="$(steam_preload "${LD_PRELOAD:-}")"
steam_command=(env -u LD_PRELOAD)
if [[ -n "$clean_preload" ]]; then
    steam_command+=("LD_PRELOAD=$clean_preload")
fi
steam_command+=("$steam_bin" -gamepadui)
# Let games release and reacquire the pointer when focus moves to another
# monitor. Forced relative mode is an opt-in workaround for specific games.
configure_cursor_capture() {
    cursor_args=()
    if [[ "${TARTARUS_GAMING_FORCE_GRAB:-0}" == 1 ]]; then
        cursor_args=(--force-grab-cursor)
    fi
}
configure_cursor_capture
gamescope_command=(
    gamescope \
    --backend wayland \
    -e \
    -f \
    -b \
    "${cursor_args[@]}" \
    -W "$output_width" -H "$output_height" \
    -w "$output_width" -h "$output_height" \
    -r "$output_refresh" \
    -- "${steam_command[@]}"
)

set_compositor_gaming
if command -v gamemoderun >/dev/null 2>&1; then
    # gamemoderun forwards its arguments through env(1); unlike gamescope it
    # does not accept the conventional `--` separator.
    gamemoderun "${gamescope_command[@]}" \
        >"$log" 2>&1 9>&- &
else
    "${gamescope_command[@]}" \
        >"$log" 2>&1 9>&- &
fi

gamescope_pid=$!
write_state "$gamescope_pid"
printf '%s launch gamescope_pid=%s\n' "$(date --iso-8601=seconds)" "$gamescope_pid" >>"$log"
watch_session "$gamescope_pid"
disown || true
wait_for_window "$gamescope_pid" || exit 1
set_shell_gaming 1
toggle_gaming_workspace
