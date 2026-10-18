// qmllint disable
import QtQuick

// Opens the app launcher.
BarButton {
    id: root
    toneName: "accent"
    readonly property string icon: String.fromCodePoint(0xF003B)
    morphing: !!bar && bar.shell.launcherOpen
    onClicked: if (bar) bar.shell.toggleLauncher()

    Text {
        text: root.icon
        color: root.iconColor
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx }
    }
}
