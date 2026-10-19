// qmllint disable
import QtQuick

// Opens the power menu.
BarButton {
    id: root
    toneName: "red"
    readonly property string icon: String.fromCodePoint(0xF0425)
    morphing: !!bar && bar.shell.powerOpen
    onClicked: if (bar) bar.shell.togglePower()

    Text {
        text: root.icon
        color: root.iconColor
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx }
    }
}
