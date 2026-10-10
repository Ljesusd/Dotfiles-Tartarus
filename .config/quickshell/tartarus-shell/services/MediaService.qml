pragma Singleton
import QtQml
import Quickshell.Services.Mpris

QtObject {
    id: root
    readonly property var players: Mpris.players.values
    property var preferredPlayer: null
    readonly property var sungPlayer: players.find(player =>
        String(player.identity || "").trim().toLowerCase() === "sung"
        || String(player.desktopEntry || "").trim().toLowerCase() === "sung") ?? null
    readonly property var activePlayer: root.pickPlayer(root.preferredPlayer)
    readonly property bool available: activePlayer !== null
    readonly property string title: activePlayer?.trackTitle || ""
    readonly property string artist: activePlayer?.trackArtist || ""
    readonly property string artUrl: activePlayer?.trackArtUrl || ""
    readonly property string identity: activePlayer?.identity || ""
    readonly property bool playing: activePlayer?.isPlaying ?? false
    readonly property bool canToggle: activePlayer?.canTogglePlaying ?? false
    readonly property bool canPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canNext: activePlayer?.canGoNext ?? false

    function hasTrack(player) {
        return !!player && String(player.trackTitle || "").trim().length > 0
    }

    // Follow the same MPRIS model as Ryoku: keep the selected player when it
    // still has a track, otherwise choose the player currently playing. Sung,
    // browsers and other MPRIS clients are all valid sources.
    function pickPlayer(preferred) {
        const candidates = root.players.filter(player => root.hasTrack(player))
        if (preferred && candidates.includes(preferred)) return preferred
        // Sung is Tartarus's primary music source. Keep browser MPRIS sessions
        // available as a fallback, but do not steal the card while Sung has a
        // track loaded (even if Sung is paused).
        const sung = candidates.find(player =>
            String(player.identity || "").trim().toLowerCase() === "sung"
            || String(player.desktopEntry || "").trim().toLowerCase() === "sung")
        if (sung) return sung
        return candidates.find(player => player.isPlaying) ?? candidates[0] ?? null
    }

    function formatTime(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0) return "—:—"
        const total = Math.floor(seconds)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const suffix = String(total % 60).padStart(2, "0")
        return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + suffix
            : Math.floor(total / 60) + ":" + suffix
    }

    // A slider gesture belongs to one player and one track, even if MPRIS
    // changes the active player/metadata before the pointer is released.
    function seekTo(seconds, expectedPlayer, expectedTrack) {
        const player = root.activePlayer
        if (!player || player !== expectedPlayer || !root.players.includes(player)
                || player.uniqueId !== expectedTrack || !player.canSeek
                || !player.positionSupported || !player.lengthSupported
                || !Number.isFinite(player.length) || player.length <= 0
                || !Number.isFinite(seconds)) return
        player.position = Math.max(0, Math.min(player.length, seconds))
    }

    function refreshPosition() {
        const player = root.activePlayer
        if (player && root.players.includes(player) && player.positionSupported && player.isPlaying)
            player.positionChanged()
    }

    onPlayersChanged: {
        if (!players.includes(preferredPlayer)) preferredPlayer = null
    }
    function selectPlayer(player) {
        if (root.players.includes(player)) root.preferredPlayer = player
    }
    function command(name) {
        const player = root.activePlayer
        if (!player) return
        if (name === "play-pause" && root.canToggle) player.togglePlaying()
        else if (name === "previous" && root.canPrevious) player.previous()
        else if (name === "next" && root.canNext) player.next()
    }
}
