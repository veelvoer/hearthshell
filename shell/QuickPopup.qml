// qmllint disable
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

// Quick settings: toggles, sound and brightness sliders, battery, power actions.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    signal requestMenu(string kind)     // switch to the Wi-Fi or Bluetooth menu
    signal requestClose()
    readonly property real wantedHeight: 62 + body.implicitHeight + 16

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool soundReady: !!sink && sink.ready && !!sink.audio
    readonly property bool muted: soundReady && sink.audio.muted
    readonly property int vol: soundReady ? Math.round(sink.audio.volume * 100) : 0
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    readonly property var wifiNet: wifiDev ? wifiDev.networks.values.find(n => n.connected) : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property int btLinked: adapter ? adapter.devices.values.filter(d => d.connected).length : 0
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.isPresent && battery.isLaptopBattery
    readonly property int level: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: !!battery && battery.state === UPowerDeviceState.Charging
    property int bright: 0
    property bool brightAvailable: false
    property string confirm: ""

    function cp(n) { return String.fromCodePoint(n); }
    readonly property string batGlyph: charging ? cp(0xF0084) : level >= 100 ? cp(0xF0079) : level < 10 ? cp(0xF0083) : cp(0xF007A + (Math.floor(level / 10) - 1))

    PwObjectTracker { objects: [root.sink] }
    Process {
        id: reader
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                root.brightAvailable = f.length >= 5 && f[1] === "backlight";
                if (root.brightAvailable && !dragB.pressed) root.bright = parseInt(f[3]);
            }
        }
    }
    Process { id: setter }
    Process { id: power }
    Timer { interval: 1200; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: reader.running = true }
    Timer { id: confirmTimer; interval: 3000; onTriggered: root.confirm = "" }
    Timer { id: lockTimer; interval: 420; onTriggered: if (root.shell) root.shell.lockNow() }
    onActiveChanged: if (!active) confirm = ""

    function setBrightness(p) {
        bright = Math.round(p);
        setter.command = ["brightnessctl", "-q", "set", bright + "%"];
        setter.running = true;
    }
    function run(cmd) { power.command = cmd; power.running = true; }
    function powerAction(key, cmd) {
        if (confirm === key) { confirm = ""; run(cmd); } else { confirm = key; confirmTimer.restart(); }
    }

    Text {
        x: 54; y: 15; text: "Quick settings"; color: main.text
        font { family: main.serif; pixelSize: 18 }
    }

    // one square toggle
    component Tile: Item {
        id: tile
        property string glyph: ""
        property string title: ""
        property string sub: ""
        property bool checked: false
        property bool chevron: false
        signal clicked()
        signal chevronClicked()
        width: parent ? (parent.width - 10) / 2 : 150; height: 62
        scale: tm.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
        Rectangle {
            anchors.fill: parent; radius: 18
            color: tile.checked ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.20) : (tm.containsMouse ? main.card : Qt.rgba(main.card.r, main.card.g, main.card.b, 0.7))
            border.width: 1; border.color: tile.checked ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.55) : main.line
            Behavior on color { ColorAnimation { duration: main.ms(180) } }
            Behavior on border.color { ColorAnimation { duration: main.ms(180) } }
        }
        Text {
            x: 14; anchors.verticalCenter: parent.verticalCenter; text: tile.glyph
            color: tile.checked ? main.accent : main.text
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 }
        }
        Column {
            x: 50; anchors.verticalCenter: parent.verticalCenter; spacing: 1; width: parent.width - 50 - (tile.chevron ? 32 : 10)
            Text { width: parent.width; elide: Text.ElideRight; text: tile.title; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
            Text { width: parent.width; elide: Text.ElideRight; text: tile.sub; color: main.muted; font { family: main.font; pixelSize: 11 } }
        }
        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked() }
        Item {
            visible: tile.chevron; anchors.right: parent.right; width: 32; height: parent.height
            Text { anchors.centerIn: parent; text: "›"; color: cm.containsMouse ? main.accent : main.muted
                font { pixelSize: 22; weight: 600 } }
            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.chevronClicked() }
        }
    }

    Column {
        id: body
        x: 12; y: 60; width: parent.width - 24; spacing: 10

        Flow {
            width: parent.width; spacing: 10
            Tile {
                glyph: Networking.wifiEnabled ? root.cp(0xF05A9) : root.cp(0xF05AA)
                title: "Wi-Fi"
                sub: !Networking.wifiEnabled ? "Off" : (root.wifiNet ? root.wifiNet.name : "Not connected")
                checked: Networking.wifiEnabled; chevron: true
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                onChevronClicked: root.requestMenu("network")
            }
            Tile {
                visible: !!root.adapter
                glyph: !root.adapter || !root.adapter.enabled ? root.cp(0xF00B2) : root.cp(0xF00AF)
                title: "Bluetooth"
                sub: !root.adapter || !root.adapter.enabled ? "Off" : (root.btLinked > 0 ? root.btLinked + " connected" : "On")
                checked: !!root.adapter && root.adapter.enabled; chevron: true
                onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                onChevronClicked: root.requestMenu("bluetooth")
            }
            Tile {
                glyph: root.muted ? "󰸈" : root.cp(0xF057E)
                title: "Sound"; sub: root.muted ? "Muted" : root.vol + "%"
                checked: !root.muted
                onClicked: if (root.soundReady) root.sink.audio.muted = !root.sink.audio.muted
            }
            Tile {
                glyph: root.cp(0xF0493)
                title: "Settings"; sub: "Open the panel"
                onClicked: { root.requestClose(); if (root.shell) root.shell.openSettings(); }
            }
        }

        Rectangle {
            width: parent.width; height: sliders.implicitHeight + 28; radius: 18
            color: Qt.rgba(main.card.r, main.card.g, main.card.b, 0.7); border.width: 1; border.color: main.line
            Column {
                id: sliders
                x: 16; y: 14; width: parent.width - 32; spacing: 12
                Row {
                    width: sliders.width; spacing: 12; height: 26
                    Text { width: 24; anchors.verticalCenter: parent.verticalCenter; text: root.muted ? "󰸈" : root.cp(0xF057E); color: main.accent
                        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 } }
                    HSlider {
                        id: dragV; width: parent.width - 84; anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 1; value: root.soundReady ? root.sink.audio.volume : 0
                        onMoved: v => { if (root.soundReady) { root.sink.audio.volume = v; root.sink.audio.muted = false; } }
                    }
                    Text { width: 36; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
                        text: root.vol + "%"; color: main.muted; font { family: main.font; pixelSize: 12; weight: 600 } }
                }
                Row {
                    visible: root.brightAvailable
                    width: sliders.width; spacing: 12; height: 26
                    Text { width: 24; anchors.verticalCenter: parent.verticalCenter; text: root.cp(0xF00E0); color: main.accent
                        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 } }
                    HSlider {
                        id: dragB; width: parent.width - 84; anchors.verticalCenter: parent.verticalCenter
                        from: 5; to: 100; value: root.bright
                        onMoved: v => root.setBrightness(v)
                    }
                    Text { width: 36; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
                        text: root.bright + "%"; color: main.muted; font { family: main.font; pixelSize: 12; weight: 600 } }
                }
            }
        }

        Rectangle {
            visible: root.hasBattery
            width: parent.width; height: 48; radius: 18
            color: Qt.rgba(main.card.r, main.card.g, main.card.b, 0.7); border.width: 1; border.color: main.line
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: root.batGlyph
                color: root.charging ? main.accent : (root.level <= 15 ? "#ff002f" : main.text)
                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 } }
            Text { x: 50; anchors.verticalCenter: parent.verticalCenter; color: main.text
                text: root.level + "%  ·  " + (root.charging ? "Charging" : "On battery")
                font { family: main.font; pixelSize: 13; weight: 600 } }
        }

        Row {
            width: parent.width; spacing: 8
            readonly property real bw: (width - 24) / 4
            Repeater {
                model: [
                    { "key": "lock", "glyph": 0xF033E, "label": "Lock" },
                    { "key": "sleep", "glyph": 0xF04B2, "label": "Sleep" },
                    { "key": "reboot", "glyph": 0xF0709, "label": "Restart" },
                    { "key": "off", "glyph": 0xF0425, "label": "Shut down" }
                ]
                Rectangle {
                    id: pb
                    required property var modelData
                    readonly property bool asking: root.confirm === modelData.key
                    width: parent.bw; height: 58; radius: 16
                    color: asking ? Qt.rgba(main.red.r, main.red.g, main.red.b, 0.25) : (pm.containsMouse ? main.card : Qt.rgba(main.card.r, main.card.g, main.card.b, 0.7))
                    border.width: 1; border.color: asking ? main.red : main.line
                    scale: pm.pressed ? 0.95 : 1
                    Behavior on color { ColorAnimation { duration: main.ms(160) } }
                    Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.cp(pb.modelData.glyph)
                            color: pb.asking ? main.red : main.text; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 } }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: pb.asking ? "Sure?" : pb.modelData.label
                            color: pb.asking ? main.red : main.muted; font { family: main.font; pixelSize: 10; weight: 600 } }
                    }
                    MouseArea {
                        id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const k = pb.modelData.key;
                            if (k === "lock") { root.requestClose(); lockTimer.restart(); }
                            else if (k === "sleep") { root.requestClose(); root.run(["systemctl", "suspend"]); }
                            else if (k === "reboot") root.powerAction(k, ["systemctl", "reboot"]);
                            else root.powerAction(k, ["systemctl", "poweroff"]);
                        }
                    }
                }
            }
        }
    }
}
