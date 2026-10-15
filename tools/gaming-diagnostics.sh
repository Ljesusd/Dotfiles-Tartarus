#!/usr/bin/env bash
# Read-only focus snapshot; omits window titles and process command lines.
set -euo pipefail
hyprctl version
pacman -Q gamescope xorg-xwayland 2>/dev/null || true
hyprctl getoption input:follow_mouse
hyprctl getoption cursor:no_warps
hyprctl monitors -j | jq '[.[] | {name,focused,activeWorkspace,specialWorkspace}]'
hyprctl activewindow -j | jq '{class,pid,workspace,fullscreen}'
hyprctl clients -j | jq '[.[] | select(.class == "gamescope") | {class,pid,mapped,workspace,fullscreen,xwayland}]'
