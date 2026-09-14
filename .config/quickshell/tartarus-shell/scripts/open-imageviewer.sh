#!/usr/bin/env bash

set -euo pipefail

image_path="${1:-}"

if [ -z "$image_path" ]; then
    exit 1
fi

monitor_name=""

if command -v hyprctl >/dev/null 2>&1; then
    if command -v jq >/dev/null 2>&1; then
        monitor_name="$(
            hyprctl monitors -j 2>/dev/null \
                | jq -r '(map(select(.focused))[0].name // .[0].name // "")'
        )"
    else
        monitor_name="$(
            hyprctl monitors 2>/dev/null \
                | awk '/^Monitor / { print $2; exit }'
        )"
    fi
fi

if [ -z "$monitor_name" ]; then
    exit 1
fi

qs -c tartarus-shell ipc call imageviewer open \
    "$image_path" \
    "$monitor_name"
