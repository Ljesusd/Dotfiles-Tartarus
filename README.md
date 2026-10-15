# Tartarus

Personal Linux desktop built with Hyprland (Lua configuration) and Quickshell.
Includes the Tartarus shell, quick settings, notifications, widgets, launcher,
installer/store, capture tools, a local agent workspace, and Sung music player.

## Components

- `.config/`: Hyprland, Quickshell, Kitty, Zed and optional user services.
- `tools/tartarus-rashin/`: Go daemon, HTTP/chat workspace and Hermes ACP bridge.
- `.local/bin/`: source wrappers; the Rashin executable is compiled on demand.
- `Sung/`: vendored upstream source, including its own license and build guide.
- `system/`: reference system configuration, not automatically installed.

This is a personal configuration, not a distribution installer. Review the
monitor mapping (DP-2 / HDMI-A-1), keyboard layouts and startup applications in
`.config/hypr/modules/` before enabling it. It requires a compatible **Lua-based
Hyprland** version; do not overwrite a legacy hyprland.conf setup blindly.

## Installation

Install the dependencies in [DEPENDENCIES.md](DEPENDENCIES.md), then:

```sh
git clone https://github.com/Ljesusd/Dotfiles-Tartarus.git
cd Dotfiles-Tartarus
bash tools/install-links.sh --apply
```

The script links only the listed desktop configurations, public wrappers,
desktop entries and user services. Existing targets are moved to a unique
backup under `~/.local/state/tartarus-install/`. It neither installs packages
nor starts/enables services. Keep this checkout in place while using the links.
Ensure `~/.local/bin` is in your PATH. Log out/in when ready to activate desktop
changes; do not restart the shell during an installation or active recording.

Build Sung separately following [its guide](Sung/README.md). Configure private
music accounts on your machine; no account settings are shipped.

## Local models and Hermes

See [local AI setup](docs/LOCAL-AI.md). Model weights, downloaded Hermes source,
API keys, chat history, skills installed by the user and personal memories are
not bundled. The integration source and service definitions are included.
No AI service is automatically enabled by the installation script.

## Gaming

Super + G opens/toggles the managed Gamescope Steam session. Pointer capture is
automatic, so games can release/reacquire the mouse across focus changes.
To opt back into forced capture, launch with:

```sh
TARTARUS_GAMING_FORCE_GRAB=1 bash ~/.config/hypr/scripts/steam-gaming-mode.sh
```

Capture options apply to a **new** managed session, not an already running game.
Exit Steam normally before testing a different setting. If camera movement
breaks after switching monitors, run `bash tools/gaming-diagnostics.sh` before
and after the failure. This prints focus information, not keystrokes or window
titles. The intermittent Risk of Rain issue still requires in-game validation.

## Checks and publication

```sh
bash .config/hypr/tests/steam-gaming-mode.test.sh
node --test .config/quickshell/tartarus-shell/tests/*.test.cjs
python3 -m unittest discover -s .config/quickshell/tartarus-shell/tests -p 'test_*.py'
(cd tools/tartarus-rashin && go test ./...)
python3 tools/audit-publication.py
```

The publication audit examines the Git index and reachable history for common
secret patterns, sensitive filenames, gitlinks and oversized files. It is not
a complete secret detector: review new files and the staged diff before push.
Never stage your home directory, KeePass files, Syncthing identity or Hermes
private state. See [third-party notices](THIRD_PARTY.md) for license boundaries.
