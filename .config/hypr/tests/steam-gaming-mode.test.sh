#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Load only the pure conversion helper; never start/stop Steam or Gamescope.
source <(sed -n '/^normalize_refresh() {$/,/^}$/p' "$test_dir/../scripts/steam-gaming-mode.sh")

check() {
    local actual
    actual="$(normalize_refresh "$1")"
    if [[ "$actual" != "$2" ]]; then
        printf 'FAIL locale=%s input=%q expected=%s actual=%q\n' "$LC_ALL" "$1" "$2" "$actual" >&2
        exit 1
    fi
}

for test_locale in C es_ES.UTF-8; do
    export LC_ALL="$test_locale"
    check 100.00000 100
    check 164.96000 165
    check 143.98000 144
    check 59.94000 60
    check 100 100
    check 1000 1000
    check '' 100
    check null 100
    check 0 100
    check -60 100
    check 100100 100
    check 100,00000 100
    check garbage 100
    check $'100\n100' 100
    check 999999999999999999999999999999999999 100
done
printf 'PASS: 30 refresh conversion cases; no gaming session started.\n'

source <(sed -n '/^steam_preload() {$/,/^}$/p' "$test_dir/../scripts/steam-gaming-mode.sh")
[[ "$(steam_preload '')" == '' ]]
[[ "$(steam_preload 'libgamemodeauto.so.0')" == '' ]]
[[ "$(steam_preload '/usr/lib/libgamemodeauto.so.0:libother.so libtest.so')" == 'libother.so:libtest.so' ]]
[[ "$(steam_preload 'libother.so')" == 'libother.so' ]]
printf 'PASS: preload filtering preserves unrelated libraries.\n'

source <(sed -n '/^wait_for_window() {$/,/^}$/p' "$test_dir/../scripts/steam-gaming-mode.sh")
(
    log=/dev/null
    notify-send() { :; }
    sleep() { :; }
    kill() { return 0; }
    hyprctl() { printf '[{"pid":123,"mapped":true,"workspace":{"name":"special:gaming"}}]'; }
    wait_for_window 123
    if wait_for_window 456; then exit 1; fi
    hyprctl() { printf '[]'; }
    if wait_for_window 123; then exit 1; fi
    kill() { return 1; }
    if wait_for_window 123; then exit 1; fi
)
printf 'PASS: window readiness, unrelated PID, timeout and exited process.\n'

source <(sed -n '/^watch_session() {$/,/^}$/p' "$test_dir/../scripts/steam-gaming-mode.sh")
(
    lock_file="$(mktemp /tmp/tartarus-gaming-test.XXXXXX)"
    trap 'rm -f -- "$lock_file"' EXIT
    state_pid() { printf 'different-session'; }
    exec 9>"$lock_file"
    flock -n 9
    sleep 1 9>&- &
    test_pid=$!
    watch_session "$test_pid"
    exec 9>&-
    flock -n "$lock_file" true
    wait
)
printf 'PASS: session watcher does not retain launch lock.\n'

source <(sed -n '/^configure_cursor_capture() {$/,/^}$/p' "$test_dir/../scripts/steam-gaming-mode.sh")
unset TARTARUS_GAMING_FORCE_GRAB
configure_cursor_capture
[[ ${#cursor_args[@]} == 0 ]]
TARTARUS_GAMING_FORCE_GRAB=1 configure_cursor_capture
[[ ${#cursor_args[@]} == 1 && ${cursor_args[0]} == --force-grab-cursor ]]
TARTARUS_GAMING_FORCE_GRAB=0 configure_cursor_capture
[[ ${#cursor_args[@]} == 0 ]]
printf 'PASS: automatic pointer capture by default; forced capture is opt-in and reversible.\n'
