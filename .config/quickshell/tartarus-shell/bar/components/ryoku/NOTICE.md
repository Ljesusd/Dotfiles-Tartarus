# Ryoku music components

Source: https://github.com/ryoku-dev/ryoku
Revision: `98a0368253d9628be72b853985878a5db90e1547` (local reference checkout).
License: GNU GPL version 3, reproduced in `LICENSE`.
Original authors: the Ryoku contributors. No warranty.

Copied from `ryoku/shell/quickshell/shell/`:

- `modules/desktop/music/MusicCard.qml`
- `modules/desktop/music/MusicCover.qml`
- `modules/desktop/music/MusicSeek.qml`
- `modules/desktop/music/MusicTransport.qml`
- `utils/artcolor.js` (here `ArtColor.js`)

Modified for Tartarus on 2026-10-10: local imports, colors, Material icons,
accessible controls and protected
seek gestures. The plate omits Ryoku's optional video background. The parent
`../MusicCard.qml` adapts the wide composition from upstream `MusicWidget.qml`
and keeps Tartarus's close button, draggable header and player selector.
Tartarus samples remote artwork once per image before passing the palette to
Ryoku's original ArtColor selection functions; this also handles HTTP MPRIS art.
Lyrics, Spotify Canvas, Ryoku daemon and tall/glass modes are not imported.

These adapted components remain GPL-3.0. Keep this notice, source and license
with redistributed copies; do not treat the imported code as permissively licensed.
