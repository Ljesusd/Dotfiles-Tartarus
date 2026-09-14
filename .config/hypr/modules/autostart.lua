-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c tartarus-shell")

    hl.exec_cmd(
        "sleep 1; "
        .. "pgrep -x hyprpaper >/dev/null 2>&1 || "
        .. "hyprpaper >/tmp/tartarus-hyprpaper.log 2>&1 &"
    )

    hl.exec_cmd(
        "sleep 2; python3 "
        .. os.getenv("HOME")
        .. "/.config/quickshell/tartarus-shell/scripts/wallpaper.py apply-saved"
    )

    hl.exec_cmd(
        "sleep 2; state=\"$HOME/.local/state/tartarus-shell/keyboard-layout\"; "
        .. "if [ -r \"$state\" ]; then hyprctl switchxkblayout all $(cat \"$state\"); fi"
    )
end)
