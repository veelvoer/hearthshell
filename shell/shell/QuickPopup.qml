// qmllint disable
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

// Control Center: pill tiles, fat sliders, a now-playing card and the notification list.
// Which parts show, and in what order, is chosen in Settings -> Control Center (cfg.ccOrder / cfg.ccHidden).
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    signal requestMenu(string kind)     // switch to the Wi-Fi or Bluetooth menu
    signal requestClose()
    readonly property real wantedHeight: 62 + flow.implicitHeight + 16

    // ---------------------------------------------------------------- data
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool soundReady: !!sink && sink.ready && !!sink.audio
    readonly property bool muted: soundReady && sink.audio.muted
    readonly property int vol: soundReady ? Math.round(sink.audio.volume * 100) : 0
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && !!n.audio)
    readonly property string sinkName: !sink ? "No output" : (sink.nickname || sink.description || sink.name || "Output")
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    readonly property var wifiNet: wifiDev ? wifiDev.networks.values.find(n => n.connected) : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevs: adapter ? adapter.devices.values.filter(d => d.connected) : []
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.isPresent && battery.isLaptopBattery
    readonly property int level: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: !!battery && battery.state === UPowerDeviceState.Charging
    readonly property var nf: shell ? shell.notifier : null
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }
    property int bright: 0
    property bool brightAvailable: false
    property bool brightDragging: false
    property string nightTool: ""
    property bool nightOn: false

    function cp(n) { return String.fromCodePoint(n); }
    readonly property string batGlyph: charging ? cp(0xF0084) : level >= 100 ? cp(0xF0079) : level < 10 ? cp(0xF0083) : cp(0xF007A + (Math.floor(level / 10) - 1))

    // the parts, in the user's order, minus the hidden ones (and minus what this computer cannot do)
    readonly property var defaultOrder: ["wifi", "bluetooth", "audio", "quiet", "night", "volume", "brightness", "media", "notifications"]
    readonly property var sections: {
        const hidden = shell && shell.cfg.ccHidden ? shell.cfg.ccHidden : [];
        const order = shell && shell.cfg.ccOrder && shell.cfg.ccOrder.length > 0 ? shell.cfg.ccOrder : defaultOrder;
        const out = [];
        for (const id of order) {
            if (hidden.indexOf(id) >= 0) continue;
            if (id === "bluetooth" && !adapter) continue;
            if (id === "brightness" && !brightAvailable) continue;
            if (id === "night" && nightTool === "") continue;
            if (id === "media" && !player) continue;
            out.push(id);
        }
        return out;
    }
    function isTile(id) { return id === "wifi" || id === "bluetooth" || id === "audio" || id === "quiet" || id === "night"; }

    PwObjectTracker { objects: root.sinks.concat([root.sink]) }
    Process {
        id: reader
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                root.brightAvailable = f.length >= 5 && f[1] === "backlight";
                if (root.brightAvailable && !root.brightDragging) root.bright = parseInt(f[3]);
            }
        }
    }
    Process { id: setter }
    Process { id: sh }
    Process {
        id: nightFind
        command: ["sh", "-c", "for t in hyprsunset gammastep wlsunset; do command -v $t >/dev/null && { echo $t; exit; }; done"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.nightTool = text.trim() }
    }
    Process {
        id: nightState
        command: ["pgrep", "-x", root.nightTool || "none"]
        stdout: StdioCollector { onStreamFinished: root.nightOn = text.trim() !== "" }
    }
    Timer { interval: 1200; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: { reader.running = true; if (root.nightTool !== "") nightState.running = true; } }
    Timer { id: lockTimer; interval: 420; onTriggered: if (root.shell) root.shell.lockNow() }
    Timer { interval: 1000; running: root.active && !!root.player && root.player.isPlaying; repeat: true; onTriggered: root.player.positionChanged() }

    function setBrightness(p) {
        bright = Math.round(p);
        setter.command = ["brightnessctl", "-q", "set", bright + "%"];
        setter.running = true;
    }
    function toggleNight() {
        const t = nightTool;
        const start = t === "hyprsunset" ? "hyprsunset -t 3800" : t === "gammastep" ? "gammastep -O 3800" : "wlsunset -t 3800 -T 3801";
        sh.command = ["sh", "-c", nightOn ? "pkill -x " + t : "setsid -f " + start + " >/dev/null 2>&1"];
        sh.running = true;
        nightOn = !nightOn;
    }
    // ---------------------------------------------------------------- header
    Text {
        x: 54; y: 15; text: "Control Center"; color: main.text
        font { family: main.serif; pixelSize: 18 }
    }
    Row {
        anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 12 }
        spacing: 6
        Rectangle {
            visible: root.hasBattery
            height: 30; width: batRow.width + 20; radius: 15
            color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
            Row {
                id: batRow; anchors.centerIn: parent; spacing: 5
                Text { text: root.batGlyph; anchors.verticalCenter: parent.verticalCenter
                    color: root.charging ? main.accent : (root.level <= 15 ? "#ff002f" : main.text)
                    font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 15 } }
                Text { text: root.level + "%"; anchors.verticalCenter: parent.verticalCenter; color: main.text; font { family: main.font; pixelSize: 12; weight: 600 } }
            }
        }
        Rectangle {
            width: 30; height: 30; radius: 15
            color: gm.containsMouse ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.25) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
            Behavior on color { ColorAnimation { duration: main.ms(150) } }
            Text { anchors.centerIn: parent; text: root.cp(0xF0493); color: main.text; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 15 } }
            MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { root.requestClose(); if (root.shell) root.shell.openSettings(); } }
        }
        Rectangle {
            width: 30; height: 30; radius: 15
            color: pm.containsMouse ? Qt.rgba(main.red.r, main.red.g, main.red.b, 0.28) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
            Behavior on color { ColorAnimation { duration: main.ms(150) } }
            Text { anchors.centerIn: parent; text: root.cp(0xF0425); color: pm.containsMouse ? main.red : main.text; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 15 } }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { root.requestClose(); if (root.shell) root.shell.togglePower(); } }
        }
    }

    // ---------------------------------------------------------------- the parts
    // a pill tile: a round icon, a title, a subtitle, and an optional chevron
    component Tile: Item {
        id: tile
        property string glyph: ""
        property string title: ""
        property string sub: ""
        property bool checked: false
        property bool chevron: false
        signal clicked()
        signal chevronClicked()
        height: 58
        scale: tm.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
        Rectangle {
            anchors.fill: parent; radius: height / 2
            color: tile.checked ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.92) : (tm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.12) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07))
            Behavior on color { ColorAnimation { duration: main.ms(200) } }
        }
        Rectangle {
            x: 7; anchors.verticalCenter: parent.verticalCenter; width: 44; height: 44; radius: 22
            color: tile.checked ? Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.16) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
            Behavior on color { ColorAnimation { duration: main.ms(200) } }
            Text {
                anchors.centerIn: parent; text: tile.glyph
                color: tile.checked ? main.bg : main.text
                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 19 }
            }
        }
        Column {
            x: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 1; width: parent.width - 62 - (tile.chevron ? 34 : 12)
            Text { width: parent.width; elide: Text.ElideRight; text: tile.title; color: tile.checked ? main.bg : main.text; font { family: main.font; pixelSize: 13; weight: 700 } }
            Text { width: parent.width; elide: Text.ElideRight; text: tile.sub; color: tile.checked ? Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.72) : main.muted; font { family: main.font; pixelSize: 11 } }
        }
        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked() }
        Item {
            visible: tile.chevron; anchors.right: parent.right; anchors.rightMargin: 4; width: 30; height: parent.height
            Text { anchors.centerIn: parent; text: "›"; color: cm.containsMouse ? (tile.checked ? main.bg : main.accent) : (tile.checked ? main.bg : main.muted)
                font { pixelSize: 22; weight: 600 } }
            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.chevronClicked() }
        }
    }

    Flow {
        id: flow
        x: 12; y: 60; width: parent.width - 24; spacing: 8
        move: Transition { NumberAnimation { properties: "x,y"; duration: main.ms(300); easing.type: Easing.OutCubic } }

        Repeater {
            model: root.sections
            delegate: Loader {
                id: part
                required property string modelData
                readonly property bool tile: root.isTile(modelData)
                width: tile ? (flow.width - flow.spacing) / 2 : flow.width
                sourceComponent: modelData === "wifi" ? wifiC : modelData === "bluetooth" ? btC : modelData === "audio" ? audioC
                    : modelData === "quiet" ? quietC : modelData === "night" ? nightC : modelData === "volume" ? volC
                    : modelData === "brightness" ? brightC : modelData === "media" ? mediaC : notifC
            }
        }
    }

    Component { id: wifiC
        Tile {
            glyph: Networking.wifiEnabled ? root.cp(0xF05A9) : root.cp(0xF05AA)
            title: "Wi-Fi"
            sub: !Networking.wifiEnabled ? "Off" : (root.wifiNet ? root.wifiNet.name : "Not connected")
            checked: Networking.wifiEnabled; chevron: true
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            onChevronClicked: root.requestMenu("network")
        } }
    Component { id: btC
        Tile {
            glyph: !root.adapter || !root.adapter.enabled ? root.cp(0xF00B2) : root.cp(0xF00AF)
            title: "Bluetooth"
            sub: !root.adapter || !root.adapter.enabled ? "Off" : (root.btDevs.length > 0 ? (root.btDevs.length === 1 ? root.btDevs[0].name : root.btDevs.length + " connected") : "On")
            checked: !!root.adapter && root.adapter.enabled; chevron: true
            onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            onChevronClicked: root.requestMenu("bluetooth")
        } }
    Component { id: audioC
        Tile {
            glyph: root.muted ? root.cp(0xF0581) : root.cp(0xF057E)
            title: "Audio"
            sub: root.sinkName
            checked: !root.muted; chevron: true
            onClicked: if (root.soundReady) root.sink.audio.muted = !root.sink.audio.muted
            onChevronClicked: root.requestMenu("sound")
        } }
    Component { id: quietC
        Tile {
            glyph: root.cp(0xF009B)
            title: "Quiet"
            sub: root.nf && root.nf.dnd ? "On" : "Off"
            checked: !!root.nf && root.nf.dnd
            onClicked: if (root.nf) root.nf.dnd = !root.nf.dnd
        } }
    Component { id: nightC
        Tile {
            glyph: root.cp(0xF0594)
            title: "Night Light"
            sub: root.nightOn ? "On" : "Off"
            checked: root.nightOn
            onClicked: root.toggleNight()
        } }
    Component { id: volC
        PillSlider {
            glyph: root.muted ? root.cp(0xF0581) : root.cp(0xF057E)
            from: 0; to: 1; value: root.soundReady ? root.sink.audio.volume : 0
            valueText: root.muted ? "Muted" : root.vol + "%"
            showChevron: true
            onChevronClicked: root.requestMenu("sound")
            onMoved: v => { if (root.soundReady) { root.sink.audio.volume = v; root.sink.audio.muted = false; } }
        } }
    Component { id: brightC
        PillSlider {
            glyph: root.cp(0xF00E0)
            from: 5; to: 100; value: root.bright
            valueText: root.bright + "%"
            onMoved: v => root.setBrightness(v)
            onPressedChanged: root.brightDragging = pressed
            showChevron: true
            onChevronClicked: root.requestMenu("display")
        } }
    Component { id: mediaC
        MediaCard { p: root.player } }
    Component { id: notifC
        Item {
            id: nbox
            readonly property var items: root.nf ? root.nf.history.slice(0, 3) : []
            height: 30 + (items.length > 0 ? items.length * 52 : 40)
            Text { x: 6; y: 4; text: "Notifications"; color: main.muted; font { family: main.font; pixelSize: 12; weight: 600 } }
            Text {
                anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 4 }
                visible: nbox.items.length > 0; text: "Clear all"; color: ca.containsMouse ? main.text : main.accent
                font { family: main.font; pixelSize: 12; weight: 600 }
                MouseArea { id: ca; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.nf) root.nf.clearAll() }
            }
            Text { visible: nbox.items.length === 0; x: 6; y: 30; text: root.nf && root.nf.dnd ? "Quiet mode is on" : "No notifications"; color: main.muted; font { family: main.font; pixelSize: 13 } }
            Column {
                y: 26; width: parent.width; spacing: 6
                Repeater {
                    model: nbox.items
                    delegate: Rectangle {
                        required property var modelData
                        width: nbox.width; height: 46; radius: 18
                        color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                        Column {
                            x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 56
                            Text { width: parent.width; elide: Text.ElideRight; text: modelData.summary; color: main.text; font { family: main.font; pixelSize: 12; weight: 700 } }
                            Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: modelData.body; color: main.muted; font { family: main.font; pixelSize: 11 } }
                        }
                        Text { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: "×"
                            color: xm.containsMouse ? main.red : main.muted; font { pixelSize: 18 }
                            MouseArea { id: xm; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.nf) root.nf.removeHistory(modelData) } }
                    }
                }
            }
        } }
}
