// qmllint disable
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Screen brightness via brightnessctl. Hidden when the machine has no backlight.
BarButton {
    id: root
    toneName: "cyan"
    property int percent: 0
    property bool available: false
    interactive: available

    readonly property string icon: percent < 34 ? String.fromCodePoint(0xF00DE)
                                 : percent < 67 ? String.fromCodePoint(0xF00DF)
                                 : String.fromCodePoint(0xF00E0)

    function refresh() { reader.running = true; }
    onScrolled: dir => { setter.command = ["brightnessctl", "-q", "set", dir > 0 ? "5%+" : "5%-"]; setter.running = true; }

    Process {
        id: reader
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const f = text.trim().split("\n")[0].split(",");
                root.available = f.length >= 5 && f[1] === "backlight";
                if (root.available) root.percent = parseInt(f[3]);
            }
        }
    }
    Process { id: setter; onExited: root.refresh() }
    Timer { interval: 2500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

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
