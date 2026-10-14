// qmllint disable
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// Hidden when the machine has no Bluetooth adapter.
BarButton {
    id: root
    toneName: "magenta"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property var linked: adapter ? adapter.devices.values.filter(d => d.connected) : []

    readonly property string icon: !adapter || !adapter.enabled ? String.fromCodePoint(0xF00B2)
                                 : linked.length > 0 ? String.fromCodePoint(0xF00B1)
                                 : String.fromCodePoint(0xF00AF)
    readonly property string label: linked.length === 1 ? linked[0].name
                                  : linked.length > 1 ? linked.length + " devices" : ""

    morphing: !!bar && bar.hostIs("bluetooth")
    onClicked: if (bar) bar.openPopup("bluetooth", root, icon, label)

    Text {
        text: root.icon
        color: root.iconColor
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx }
    }
    Text {
        visible: root.label !== "" && cfg.labelBluetooth
        text: root.label
        color: main.text
        elide: Text.ElideRight
        Layout.maximumWidth: 110
        font { family: main.font; pixelSize: main.barPx; weight: 500 }
    }
}
