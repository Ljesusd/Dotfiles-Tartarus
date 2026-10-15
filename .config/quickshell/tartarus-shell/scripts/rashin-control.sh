#!/usr/bin/env bash
# Own only the two Tartarus units; never kill unrelated model servers.
set -euo pipefail

case "${1:-}" in
    enable|disable) action=$1 ;;
    *) printf 'Uso: rashin-control.sh enable|disable\n' >&2; exit 2 ;;
esac

units=(tartarus-rashin.service tartarus-rashin-llama.service)
if [[ "$action" == enable ]]; then
    exec systemctl --user enable --now "${units[@]}"
fi

# Stop first, even if updating the autostart configuration later fails.
systemctl --user stop "${units[@]}"

# `disable` also removes links to unit definitions installed from dotfiles.
# Preserve those definitions so the next activation still works after reboot.
linked_paths=()
unit_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
for unit in "${units[@]}"; do
    if [[ -L "$unit_config_dir/$unit" ]]; then
        linked_paths+=("$(readlink -f -- "$unit_config_dir/$unit")")
    fi
done
disable_status=0
systemctl --user disable "${units[@]}" || disable_status=$?
if ((${#linked_paths[@]})); then
    systemctl --user link "${linked_paths[@]}"
fi
exit "$disable_status"
