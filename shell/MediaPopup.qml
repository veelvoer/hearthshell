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
    readonly property real wantedWidth: shell ? shell.menuWidth("media") : 360
    readonly property real wantedHeight: 62 + col.implicitHeight + 16
    Timer { interval: 1000; running: root.active && !!root.player && root.player.isPlaying; repeat: true; onTriggered: root.player.positionChanged() }

    Text { x: 54; y: 15; text: "Now playing"; color: main.text; font { family: main.serif; pixelSize: 18 } }
    Flickable {
        x: 12; y: 58; width: parent.width - 24; height: Math.max(0, parent.height - 58 - 12)
        contentWidth: width; contentHeight: col.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
        MenuColumn {
            id: col
            shell: root.shell; menu: "media"
            width: parent.width; spacing: 10
            Repeater {
                model: root.shell ? root.shell.menuExtraIds("media") : []
                delegate: MenuExtra { required property string modelData; shell: root.shell; menu: "media"; section: modelData }
            }
            MenuSection {
                shell: root.shell; menu: "media"; section: "card"; spacing: 10
                MediaCard { width: parent.width; tall: true; p: root.player }
        Flow {
            visible: root.players.length > 1
            width: parent.width; spacing: 6
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
        }
    }
}
