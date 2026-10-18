// qmllint disable
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Display: brightness, and for each screen its size, refresh rate and scaling.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    readonly property var mons: Hyprland.monitors.values
    readonly property real wantedHeight: 62 + col.implicitHeight + 16
    property int bright: 0
    property bool brightAvailable: false
    property bool dragging: false
    onActiveChanged: if (active) Hyprland.refreshMonitors()

    Process {
        id: reader
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                root.brightAvailable = f.length >= 5 && f[1] === "backlight";
                if (root.brightAvailable && !root.dragging) root.bright = parseInt(f[3]);
            }
        }
    }
    Process { id: setter }
    Timer { interval: 1500; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: reader.running = true }
    function setBrightness(p) { bright = Math.round(p); setter.command = ["brightnessctl", "-q", "set", bright + "%"]; setter.running = true; }

    // One monitor line for Hyprland's Lua config; the current mode and position are kept, only what was asked changes.
    function apply(m, mode, scale) {
        const o = m.lastIpcObject || {};
        const md = mode || (m.width + "x" + m.height + "@" + (o.refreshRate ? o.refreshRate.toFixed(2) : "60"));
        const sc = scale || m.scale;
        Hyprland.dispatch("hl.monitor({ output = '" + m.name + "', mode = '" + md + "', position = '" + m.x + "x" + m.y + "', scale = " + sc + " })");
        refresh.restart();
    }
    Timer { id: refresh; interval: 900; onTriggered: Hyprland.refreshMonitors() }

    Text { x: 54; y: 15; text: "Display"; color: main.text; font { family: main.serif; pixelSize: 18 } }

    Flickable {
        id: scroller
        x: 12; y: 58; width: parent.width - 24; height: Math.max(0, parent.height - 58 - 12)
        contentWidth: width; contentHeight: col.implicitHeight; clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: scroller.width; spacing: 10
        PillSlider {
            visible: root.brightAvailable
            width: parent.width
            glyph: String.fromCodePoint(0xF00E0); from: 5; to: 100; value: root.bright; valueText: root.bright + "%"
            onPressedChanged: root.dragging = pressed
            onMoved: v => root.setBrightness(v)
        }
        Repeater {
            model: root.mons
            delegate: Rectangle {
                id: mc
                required property var modelData
                readonly property var o: modelData.lastIpcObject || {}
                readonly property var modes: {
                    const seen = {}, out = [];
                    for (const s of (o.availableModes || [])) {
                        const base = s.split("@")[0];
                        if (base !== modelData.width + "x" + modelData.height) continue;
                        const hz = Math.round(parseFloat(s.split("@")[1]));
                        if (!seen[hz]) { seen[hz] = 1; out.push({ "hz": hz, "mode": base + "@" + hz }); }
                    }
                    return out.slice(0, 5);
                }
                width: col.width; height: head.height + 14 + scaleRow.height + (modes.length > 1 ? 14 + hzRow.height : 0) + 20
                radius: 24; color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                Row {
                    id: head; x: 16; y: 14; spacing: 12
                    Rectangle { width: 40; height: 40; radius: 20; color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.9)
                        Text { anchors.centerIn: parent; text: String.fromCodePoint(0xF0379); color: main.bg; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 } } }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: mc.modelData.name; color: main.text; font { family: main.font; pixelSize: 14; weight: 700 } }
                        Text { text: mc.modelData.width + "×" + mc.modelData.height + "  ·  " + Math.round(mc.o.refreshRate || 0) + " Hz  ·  " + mc.modelData.scale + "×"; color: main.muted; font { family: main.font; pixelSize: 11 } }
                    }
                }
                Row {
                    id: scaleRow; x: 16; y: head.y + head.height + 14; spacing: 6
                    Repeater {
                        model: [1, 1.25, 1.5, 1.75, 2]
                        delegate: Rectangle {
                            required property real modelData
                            readonly property bool on: Math.abs(mc.modelData.scale - modelData) < 0.01
                            width: 52; height: 30; radius: 15
                            color: on ? main.accent : (sm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.16) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08))
                            Text { anchors.centerIn: parent; text: modelData.toFixed(modelData % 1 === 0 ? 1 : 2) + "×"; color: on ? main.bg : main.text; font { family: main.font; pixelSize: 12; weight: 700 } }
                            MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!on) root.apply(mc.modelData, "", modelData) }
                        }
                    }
                }
                Row {
                    id: hzRow; visible: mc.modes.length > 1; x: 16; y: scaleRow.y + scaleRow.height + 14; spacing: 6
                    Repeater {
                        model: mc.modes
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: Math.round(mc.o.refreshRate || 0) === modelData.hz
                            width: 64; height: 30; radius: 15
                            color: on ? main.accent : (hm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.16) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08))
                            Text { anchors.centerIn: parent; text: modelData.hz + " Hz"; color: on ? main.bg : main.text; font { family: main.font; pixelSize: 12; weight: 700 } }
                            MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!on) root.apply(mc.modelData, modelData.mode, "") }
                        }
                    }
                }
            }
        }
        }
    }
}
