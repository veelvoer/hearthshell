// qmllint disable
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// Wi-Fi, or an ethernet symbol (without the network name) while a cable is connected.
BarButton {
    id: root
    toneName: "blue"

    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired)
    readonly property bool ethernet: !!wiredDevice && wiredDevice.connected
    property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null
    readonly property real signal: active ? active.signalStrength : 0
    readonly property bool available: !!wifiDevice || !!wiredDevice

    readonly property string icon: {
        if (ethernet) return String.fromCodePoint(0xF0200)
        if (!Networking.wifiEnabled) return String.fromCodePoint(0xF05AA)
        if (!active) return String.fromCodePoint(0xF092D)
        let tier = signal >= 0.75 ? 4
                 : signal >= 0.50 ? 3
                 : signal >= 0.25 ? 2
                 : 1
        return String.fromCodePoint(0xF091F + (tier - 1) * 3)
    }
    readonly property string label: {
        if (ethernet) return ""
        if (!Networking.wifiEnabled) return "off"
        if (!active) return "Disconnected"
        return active.name
    }

    morphing: !!bar && bar.hostIs("network")
    onClicked: if (bar) bar.openPopup("network", root, icon, label)

    SignalBars {
        visible: cfg.drawnIcons && !root.ethernet
        level: !Networking.wifiEnabled || !root.active ? 0 : (root.signal >= 0.75 ? 4 : root.signal >= 0.5 ? 3 : root.signal >= 0.25 ? 2 : 1)
        off: !Networking.wifiEnabled
        tint: root.iconColor
    }
    Text {
        visible: !cfg.drawnIcons || root.ethernet
        text: root.icon
        color: root.iconColor
        font {
            family: "JetBrainsMono Nerd Font Propo"
            pixelSize: main.barPx
        }
    }

    HoverLabel {
        host: root
        shown: root.label !== "" && cfg.labelNetwork
        text: root.label
        color: main.text
        font.family: main.font
        font.pixelSize: main.barPx
        font.weight: 500
    }
}
