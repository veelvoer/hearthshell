// qmllint disable
import QtQuick

// Opens the quick settings menu: Wi-Fi, Bluetooth, sound and brightness, power.
BarButton {
    id: root
    toneName: "cyan"
    readonly property string icon: String.fromCodePoint(0xF0570)

    morphing: !!bar && bar.hostIs("quick")
    onClicked: if (bar) bar.openPopup("quick", root, icon, "")

    Text {
        text: root.icon
        color: root.iconColor
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx }
    }
}
