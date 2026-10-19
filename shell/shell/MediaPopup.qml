// qmllint disable
import Quickshell.Services.Mpris
import QtQuick

// Now playing: a big card, and a switcher when more than one player is open.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    readonly property var players: Mpris.players ? Mpris.players.values : []
    property var chosen: null
    readonly property var player: {
        if (chosen && players.indexOf(chosen) >= 0) return chosen;
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }
    onActiveChanged: if (active) chosen = null
    readonly property real wantedHeight: 62 + 200 + (players.length > 1 ? 52 : 0) + 24
    Timer { interval: 1000; running: root.active && !!root.player && root.player.isPlaying; repeat: true; onTriggered: root.player.positionChanged() }

    Text { x: 54; y: 15; text: "Now playing"; color: main.text; font { family: main.serif; pixelSize: 18 } }
    MediaCard { x: 12; y: 58; width: parent.width - 24; tall: true; p: root.player }
    Flow {
        visible: root.players.length > 1
        x: 12; y: 58 + 200 + 10; width: parent.width - 24; spacing: 6
        Repeater {
            model: root.players
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData === root.player
                height: 30; width: lbl.implicitWidth + 24; radius: 15
                color: on ? main.accent : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
                Text { id: lbl; anchors.centerIn: parent; text: modelData.identity || "Player"; color: on ? main.bg : main.text; font { family: main.font; pixelSize: 12; weight: 600 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen = modelData }
            }
        }
    }
}
