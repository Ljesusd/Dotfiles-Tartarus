pragma Singleton
import QtQml
import Quickshell.Services.Mpris

QtObject {
    id: root
    readonly property var players: Mpris.players.values
    property var preferredPlayer: null
    readonly property var activePlayer: players.includes(preferredPlayer)
        ? preferredPlayer : (players[0] ?? null)
    readonly property bool available: activePlayer !== null
    readonly property string title: activePlayer?.trackTitle || ""
    readonly property string artist: activePlayer?.trackArtist || ""
    readonly property string identity: activePlayer?.identity || ""
    readonly property bool playing: activePlayer?.isPlaying ?? false
    readonly property bool canToggle: activePlayer?.canTogglePlaying ?? false
    readonly property bool canPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canNext: activePlayer?.canGoNext ?? false

    onPlayersChanged: {
        if (!players.includes(preferredPlayer)) preferredPlayer = null
    }
    function selectPlayer(player) {
        if (players.includes(player)) preferredPlayer = player
    }
    function command(name) {
        const player = root.activePlayer
        if (!player) return
        if (name === "play-pause" && root.canToggle) player.togglePlaying()
        else if (name === "previous" && root.canPrevious) player.previous()
        else if (name === "next" && root.canNext) player.next()
    }
}
