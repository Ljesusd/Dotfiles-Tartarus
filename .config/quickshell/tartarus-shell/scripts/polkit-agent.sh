#!/usr/bin/env bash

# The native Qt/QML agent runs independently of Quickshell, so reloading the
# shell cannot interrupt authentication. Keep existing agents as a fallback.

set -uo pipefail

uid="$(id -u)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/../auth"
build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tartarus-shell/polkit"
binary="$build_dir/tartarus-polkit-agent"
fallback_agents=(
    lxqt-policykit-agent
    polkit-kde-authentication-agent-1
    polkit-mate
    polkit-mate-authentication-agent-1
    polkit-gnome-authentication-agent-1
    hyprpolkitagent
    psst-polkit-agent
)

build_agent() {
    cmake -S "$source_dir" -B "$build_dir" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON &&
        cmake --build "$build_dir" --parallel 2 &&
        ctest --test-dir "$build_dir" --output-on-failure
}

case "${1:-}" in
    --build) build_agent; exit $? ;;
    --preview|--check-ui)
        if [ ! -x "$binary" ]; then build_agent || exit 1; fi
        exec "$binary" "$1"
        ;;
    "") ;;
    *) printf 'Uso: %s [--build|--preview|--check-ui]\n' "$0" >&2; exit 2 ;;
esac

# Prevent simultaneous autostarts without polling or multiple registered agents.
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    exec 9>"$XDG_RUNTIME_DIR/tartarus-polkit-agent.lock"
    flock -n 9 || exit 0
fi

is_user_pid() {
    [ -r "/proc/$1/status" ] \
        && awk -v uid="$uid" '$1 == "Uid:" && $2 == uid { found = 1 } END { exit found ? 0 : 1 }' \
            "/proc/$1/status"
}

custom_pid() {
    ps -eo pid=,uid=,args= | awk -v uid="$uid" -v binary="$binary" \
        '$2 == uid && $3 == binary { print $1; exit }'
}

fallback_pids() {
    for agent in "${fallback_agents[@]}"; do
        for pid in $(pidof -x "$agent" 2>/dev/null || true); do
            if is_user_pid "$pid"; then
                printf '%s\n' "$pid"
            fi
        done
    done
}

stop_fallbacks() {
    local pid
    while read -r pid; do
        [ -n "$pid" ] || continue
        kill -TERM "$pid" 2>/dev/null || true
    done < <(fallback_pids)

    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if ! fallback_pids | grep -q .; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}

# The binary lives in the user cache because the repository must not contain
# an architecture-specific executable. Build it once on first login; if the
# build cannot happen, retain the existing graphical agent.
if [ ! -x "$binary" ]; then
    if ! build_agent; then
        printf 'Tartarus: no se pudo compilar el agente QML; se usará el fallback.\n' >&2
    fi
fi

if [ -n "$(custom_pid || true)" ]; then
    exit 0
fi

child_pid=""
stop_agent() {
    if [ -n "$child_pid" ]; then
        kill -TERM "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi
    exit 0
}
trap stop_agent TERM INT HUP

if [ -x "$binary" ]; then
    stop_fallbacks || true
    "$binary" &
    child_pid=$!
    wait "$child_pid"
    status=$?
    child_pid=""
    if [ "$status" -eq 0 ] || [ "$status" -eq 143 ]; then exit 0; fi
    printf 'Tartarus: el agente QML falló; iniciando el agente gráfico de respaldo.\n' >&2
fi

for fallback in "${fallback_agents[@]}" \
        /usr/lib/polkit-kde-authentication-agent-1 \
        /usr/lib/mate-polkit/polkit-mate-authentication-agent-1; do
    if command -v "$fallback" >/dev/null 2>&1; then
        exec "$fallback"
    fi
done
printf 'Tartarus: no hay ningún agente Polkit disponible.\n' >&2
exit 1
