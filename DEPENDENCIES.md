# Dependencies

## Desktop

- Linux with a user systemd session and Wayland; developed on Arch Linux.
- Hyprland with Lua configuration support (tested with 0.56.2), XWayland,
  Quickshell and Qt 6 Quick/Controls. Legacy Hyprland configuration is not supported.
- `bash`, `python`, `jq`, `curl`, `git`, `coreutils`, `util-linux` (flock),
  `desktop-file-utils`, `xdg-utils`, `wl-clipboard` and a notification client.
- Kitty and Zed are configured but may be replaced by editing the keybindings.
- PipeWire/WirePlumber (`wpctl`), NetworkManager (`nmcli`), BlueZ and upower
  provide the audio, networking, Bluetooth and battery backends.
- Optional hardware controls: `brightnessctl`, `ddcutil`, `hyprsunset`.
- Optional gaming: native Steam, `gamescope`, GameMode; GPU drivers and matching
  32-bit graphics libraries must be installed separately.
- Optional capture: `slurp`, `grim`, `wf-recorder`, `ffmpeg`.
- Installer features: pacman/paru on Arch, Flatpak, `7z` (7zip), `bsdtar`,
  `rpm2cpio` and `cpio` as needed for the selected package format. Extracting a
  foreign package does not satisfy its runtime dependencies automatically.
- Native authentication UI: CMake, a C++ compiler, Qt 6 development packages
  and polkit development libraries; see the auth component README.

Package names differ by distribution. This repository does not silently install
or upgrade system dependencies.

## Sung

CMake >= 3.24, a C++20 compiler and Qt >= 6.8 with Core, Concurrent, Gui, Quick,
Qml, QuickControls2, Multimedia, Network, DBus and Svg. See `Sung/README.md` and
`Sung/helper/requirements.txt` for its optional music-provider helpers.

## Tests

Node.js for the JavaScript suites, Python 3 for installer tests, Go for Rashin,
and the relevant Qt development/test packages for native components. Tests that
access live music services are optional and require user-owned credentials.

## Tartarus Rashin

The local Rashin daemon is built from `tools/tartarus-rashin` with Go and runs as
the user unit `tartarus-rashin.service` on `127.0.0.1:3610`.

- Go (the wrapper builds the daemon on demand)
- curl (Quickshell probes and streams the local daemon)
- `llama-server` (the default local provider, currently expected on port 8081)
- Python 3 (local vault indexing fallback)
- Hermes is optional; the dashboard's **Configurar Hermes** action installs and
  configures it through the interactive local setup when requested

The daemon keeps its state in `~/.local/state/tartarus-shell` and its private
context in `~/.local/share/tartarus/rashin`. It binds to localhost only.
