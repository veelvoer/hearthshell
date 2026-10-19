// qmllint disable
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Screen brightness via brightnessctl. Hidden when the machine has no backlight.
BarButton {
    id: root
    toneName: "cyan"
    interactive: available

    readonly property string icon: percent < 34 ? String.fromCodePoint(0xF00DE)
                                 : percent < 67 ? String.fromCodePoint(0xF00DF)
                                 : String.fromCodePoint(0xF00E0)

    onScrolled: dir => { setter.command = ["brightnessctl", "-q", "set", dir > 0 ? "5%+" : "5%-"]; setter.running = true; }

    BacklightReader { id: backlight; interval: 2000 }
    property bool available: backlight.available
    property int percent: backlight.percent < 0 ? 0 : backlight.percent
    Process { id: setter }

    Text {
        text: root.icon
        color: root.iconColor
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx }
    }
    HoverLabel {
        reserve: "100%"
        host: root
        shown: cfg.labelBrightness
        text: root.percent + "%"
        color: main.text
        font.family: main.font
        font.pixelSize: main.barPx
        font.weight: 500
    }
}
