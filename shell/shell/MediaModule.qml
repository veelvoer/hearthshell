// qmllint disable
import Quickshell.Services.Mpris
import QtQuick

// What is playing: icon and "title - artist" that slides out on hover (or always, see Modules). Click plays or pauses,
// scroll skips. Hidden when nothing is open.
BarButton {
    id: root
    toneName: "accent"
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool playing: !!player && player.isPlaying
    visible: !!player
    interactive: !!player
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string icon: String.fromCodePoint(playing ? 0xF0387 : 0xF03E4)

    onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
    onScrolled: dir => { if (!player) return; if (dir > 0 && player.canGoNext) player.next(); else if (dir < 0 && player.canGoPrevious) player.previous(); }

    // album art as a small round thumbnail, with the equaliser over it while playing
    Item {
        implicitWidth: main.barPx + 6
        implicitHeight: main.barPx + 6
        Rectangle {
            id: art
            anchors.fill: parent; radius: width / 2; color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.2); clip: true
            Image {
                anchors.fill: parent; visible: status === Image.Ready
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; sourceSize: Qt.size(64, 64)
            }
            Text {
                anchors.centerIn: parent; visible: !root.player || !root.player.trackArtUrl
                text: root.icon; color: root.iconColor; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx - 2 }
            }
        }
    }
    EqBars { running: root.playing; size: main.barPx - 2; tint: root.iconColor; visible: root.playing }
    HoverLabel {
        host: root
        shown: cfg.labelNetwork
        maxWidth: 190
        text: root.title + (root.artist !== "" ? " · " + root.artist : "")
        elide: Text.ElideRight
        color: main.text
        font.family: main.font
        font.pixelSize: main.barPx
        font.weight: 500
    }
}
