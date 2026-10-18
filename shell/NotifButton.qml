// qmllint disable
import QtQuick

// Notification centre: a bell with a dot when something is waiting. Click opens the list; right click toggles Do not disturb.
BarButton {
    id: root
    toneName: "accent"
    readonly property var nf: bar ? bar.shell.notifier : null
    readonly property int count: nf ? nf.unread : 0
    readonly property bool dnd: !!nf && nf.dnd
    readonly property string icon: String.fromCodePoint(dnd ? 0xF009B : (count > 0 ? 0xF009A : 0xF009C))
    morphing: !!bar && bar.hostIs("notifications")
    onClicked: if (bar) bar.openPopup("notifications", root, icon, "")

    Text {
        text: root.icon
        color: root.iconColor
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx }
        Rectangle {
            visible: root.count > 0 && !root.dnd
            width: 7; height: 7; radius: 4; color: main.red
            anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: 0 }
        }
    }
    onRightClicked: if (nf) nf.dnd = !nf.dnd
}
