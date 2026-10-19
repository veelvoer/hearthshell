// qmllint disable
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Hidden on machines without a battery (desktops).
BarButton {
    id: root
    toneName: "green"
    interactive: false

    property var battery: UPower.displayDevice
    readonly property bool available: battery && battery.isPresent && battery.isLaptopBattery
    property bool charging: battery && battery.state === UPowerDeviceState.Charging
    readonly property int level: battery ? Math.round(battery.percentage * 100) : 0

    readonly property string icon: {
        if (charging) return String.fromCodePoint(0xF0084)
        if (level >= 100) return String.fromCodePoint(0xF0079)
        if (level < 10) return String.fromCodePoint(0xF0083)
        return String.fromCodePoint(0xF007A + (Math.floor(level / 10) - 1))
    }

    BatteryIcon {
        visible: cfg.drawnIcons
        level: root.level
        charging: root.charging
        tint: root.iconColor
    }
    Text {
        visible: !cfg.drawnIcons
        text: root.icon
        color: root.charging ? root.iconColor
                             : root.level <= 15 ? '#ff002f' 
                             : root.level <= 30 ? '#f97316' 
                             : root.iconColor
        font {
            family: "JetBrainsMono Nerd Font Propo"
            pixelSize: main.barPx
        }
    }

    HoverLabel {
        reserve: "100%"
        host: root
        shown: cfg.labelBattery
        text: root.level + "%"
        color: main.text
        font.family: main.font
        font.pixelSize: main.barPx
        font.weight: 500
    }
}
