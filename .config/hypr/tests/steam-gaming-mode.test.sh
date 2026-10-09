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
