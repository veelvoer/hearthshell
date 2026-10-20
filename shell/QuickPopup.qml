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
    property bool editing: false          // settings preview: every module shown, nothing reacts
    property var shell: null
    readonly property bool typing: false
    signal requestMenu(string kind)     // switch to the Wi-Fi or Bluetooth menu
    signal requestClose()
    readonly property real wantedHeight: 62 + flow.implicitHeight + 16
    readonly property alias gridItem: flow

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
    readonly property var tog: shell ? shell.toggles : ({ "nightOn": false, "gameOn": false, "airplaneOn": false, "caffeineOn": false })
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micReady: !!source && source.ready && !!source.audio
    readonly property bool micMuted: micReady && source.audio.muted
    readonly property int micLevel: micReady ? Math.round(source.audio.volume * 100) : 0
    property real cpuUse: 0
    property real memUse: 0
    property real tempC: 0
    property var lastCpu: null
    readonly property bool wantsSystem: active && sections.indexOf("system") >= 0
    property bool watching: false
    function syncWatch() {
        const w = active && !!shell;
        if (w === watching) return;
        watching = w;
        shell.toggles.watch(w);
    }
    onActiveChanged: syncWatch()
    onShellChanged: syncWatch()
    Component.onCompleted: syncWatch()
    Component.onDestruction: { if (watching && shell) shell.toggles.watch(false); }
    function span(sec) {
        if (!(sec > 0)) return "";
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    function cp(n) { return String.fromCodePoint(n); }
    readonly property string batGlyph: charging ? cp(0xF0084) : level >= 100 ? cp(0xF0079) : level < 10 ? cp(0xF0083) : cp(0xF007A + (Math.floor(level / 10) - 1))

    // the parts, in the user's order, minus the hidden ones (and minus what this computer cannot do)
    readonly property var defaultOrder: ["wifi", "bluetooth", "audio", "quiet", "night", "volume", "brightness", "performance", "media", "notifications"]
    readonly property var sections: {
        const hidden = shell && shell.cfg.ccHidden ? shell.cfg.ccHidden : [];
        const g = shell ? shell.ccGrid : ({ "items": {} });
        const has = id => editing || (id === "bluetooth" ? !!adapter : id === "brightness" ? brightAvailable : id === "media" ? !!player
            : (id === "mic" || id === "micvol") ? !!source : id === "battery" ? hasBattery : true);
        const out = [];
        for (const id of (shell ? shell.ccFull : defaultOrder)) {
            if (hidden.indexOf(id) >= 0 || !g.items[id] || !has(id)) continue;
            out.push(id);
        }
        return out;
    }
    // the grid with the rows that hold nothing (no player, no Bluetooth...) squeezed out
    readonly property var layout: {
        const g = shell ? shell.ccGrid : ({ "cols": 6, "items": {} });
        const used = {};
        let maxRow = 0;
        for (const id of sections) {
            const it = g.items[id];
            for (let j = 0; j < it.h; j++) used[it.y + j] = true;
            maxRow = Math.max(maxRow, it.y + it.h);
        }
        const shift = [];
        let empty = 0;
        for (let r = 0; r < maxRow; r++) { shift[r] = empty; if (!used[r] && !editing) empty++; }
        const out = {};
        for (const id of sections) { const it = g.items[id]; out[id] = { "x": it.x, "y": it.y - shift[it.y], "w": it.w, "h": it.h }; }
        return { "cols": g.cols, "items": out, "rows": maxRow - empty + (editing ? 1 : 0) };
    }
    readonly property var comps: ({ "wifi": wifiC, "bluetooth": btC, "audio": audioC, "quiet": quietC, "night": nightC, "airplane": airplaneC,
        "caffeine": caffeineC, "game": gameC, "mic": micC, "screenshot": shotC, "wallpaper": wallC, "theme": themeC, "battery": batteryC,
        "volume": volC, "micvol": micvolC, "brightness": brightC, "performance": perfC, "system": systemC, "media": mediaC, "notifications": notifC })
    readonly property var occupied: {
        const o = {};
        for (const id of sections) { const it = layout.items[id]; for (let j = 0; j < it.h; j++) for (let i = 0; i < it.w; i++) o[(it.y + j) * 20 + it.x + i] = true; }
        return o;
    }
    readonly property real rowH: flow.cellW
    readonly property real wantedWidth: 24 + layout.cols * 50 + (layout.cols - 1) * cellGap
    readonly property real cellGap: 8

    PwObjectTracker { objects: root.sinks.concat([root.sink, root.source]) }
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
    Timer { interval: 1200; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: reader.running = true }
    Process {
        id: sysRead
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 4) return;
                const c = l[0].trim().split(/\s+/).slice(1).map(Number);
                const total = c.reduce((x, y) => x + y, 0), idle = c[3] + (c[4] || 0);
                if (root.lastCpu && total > root.lastCpu.total) root.cpuUse = Math.max(0, Math.min(1, 1 - (idle - root.lastCpu.idle) / (total - root.lastCpu.total)));
                root.lastCpu = { "total": total, "idle": idle };
                const mt = Number(l[1].replace(/\D/g, "")), ma = Number(l[2].replace(/\D/g, ""));
                if (mt > 0) root.memUse = 1 - ma / mt;
                root.tempC = l.length > 3 ? Number(l[3]) / 1000 : 0;
            }
        }
    }
    Timer { interval: 1500; running: root.wantsSystem; repeat: true; triggeredOnStart: true; onTriggered: sysRead.running = true }
    Timer { id: lockTimer; interval: 420; onTriggered: if (root.shell) root.shell.lockNow() }
    Timer { interval: 1000; running: root.active && !!root.player && root.player.isPlaying; repeat: true; onTriggered: root.player.positionChanged() }

    function setBrightness(p) {
        bright = Math.round(p);
        setter.command = ["brightnessctl", "-q", "set", bright + "%"];
        setter.running = true;
    }
    // ---------------------------------------------------------------- header
    Text {
        x: 54; y: 15; text: "Control Center"; color: main.text
        font { family: main.serif; pixelSize: 18 }
    }
    Row {
        anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 12 }
        spacing: 6
        enabled: !root.editing
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
        property color tone: main.accent
        property bool interactive: true
        signal clicked()
        signal chevronClicked()
        readonly property bool compact: width < 120
        readonly property bool round: width <= height + 4
        readonly property real iconD: Math.min(44, height - 12)
        readonly property color fg: checked ? main.bg : main.text
        scale: tm.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
        Rectangle {
            anchors.fill: parent; radius: tile.height <= 70 ? tile.height / 2 : 30
            color: tile.checked ? Qt.rgba(tile.tone.r, tile.tone.g, tile.tone.b, 0.92) : (tm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.12) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07))
            Behavior on color { ColorAnimation { duration: main.ms(200) } }
        }
        Rectangle {
            visible: !tile.round
            x: tile.compact ? (tile.width - width) / 2 : 6; anchors.verticalCenter: parent.verticalCenter
            width: tile.iconD; height: tile.iconD; radius: tile.iconD / 2
            color: tile.checked ? Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.16) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
            Behavior on color { ColorAnimation { duration: main.ms(200) } }
        }
        Text {
            x: tile.round ? (tile.width - width) / 2 : (tile.compact ? (tile.width - width) / 2 : 6 + (tile.iconD - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            text: tile.glyph; color: tile.fg
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: tile.round ? Math.round(tile.height * 0.4) : Math.round(tile.iconD * 0.45) }
        }
        Column {
            visible: !tile.compact; x: 6 + tile.iconD + 10; anchors.verticalCenter: parent.verticalCenter; spacing: 1
            width: parent.width - x - (tile.chevron ? 34 : 12)
            Text { width: parent.width; elide: Text.ElideRight; text: tile.title; color: tile.fg; font { family: main.font; pixelSize: 13; weight: 700 } }
            Text { width: parent.width; elide: Text.ElideRight; text: tile.sub; color: tile.checked ? Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.72) : main.muted; font { family: main.font; pixelSize: 11 } }
        }
        MouseArea { id: tm; anchors.fill: parent; enabled: tile.interactive; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked() }
        Item {
            visible: tile.chevron && !tile.compact; anchors.right: parent.right; anchors.rightMargin: 4; width: 30; height: parent.height
            Text { anchors.centerIn: parent; text: "›"; color: cm.containsMouse ? (tile.checked ? main.bg : main.accent) : (tile.checked ? main.bg : main.muted)
                font { pixelSize: 22; weight: 600 } }
            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.chevronClicked() }
        }
    }

    readonly property point gridOrigin: Qt.point(12, 60)
    Flickable {
        id: scroller
        x: 12; y: 60; width: parent.width - 24; height: Math.max(0, parent.height - 60 - 12)
        contentWidth: width; contentHeight: flow.implicitHeight
        clip: true; boundsBehavior: Flickable.StopAtBounds
        interactive: !root.editing && contentHeight > height
    Item {
        id: flow
        width: scroller.width
        implicitHeight: root.layout.rows > 0 ? root.layout.rows * (root.rowH + root.cellGap) - root.cellGap : 0
        readonly property real cellW: (width - root.cellGap * (root.layout.cols - 1)) / root.layout.cols

        Repeater {
            model: root.editing ? root.layout.cols * root.layout.rows : 0
            Rectangle {
                required property int index
                visible: !root.occupied[Math.floor(index / root.layout.cols) * 20 + index % root.layout.cols]
                x: (index % root.layout.cols) * (flow.cellW + root.cellGap); y: Math.floor(index / root.layout.cols) * (root.rowH + root.cellGap)
                width: flow.cellW; height: root.rowH; radius: root.rowH / 2
                color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.04)
            }
        }
        Repeater {
            model: root.sections
            delegate: Loader {
                id: part
                required property string modelData
                readonly property var cell: root.layout.items[modelData]
                x: cell ? cell.x * (flow.cellW + root.cellGap) : 0
                y: cell ? cell.y * (root.rowH + root.cellGap) : 0
                width: cell ? cell.w * flow.cellW + (cell.w - 1) * root.cellGap : 0
                height: cell ? cell.h * root.rowH + (cell.h - 1) * root.cellGap : 0
                Behavior on x { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
                enabled: !root.editing
                sourceComponent: root.comps[modelData]
            }
        }
    }
    }

    Component { id: wifiC
        Tile {
            glyph: Networking.wifiEnabled ? root.cp(0xF05A9) : root.cp(0xF05AA)
            title: "Wi-Fi"; tone: main.tone(0)
            sub: !Networking.wifiEnabled ? "Off" : (root.wifiNet ? root.wifiNet.name : "Not connected")
            checked: Networking.wifiEnabled; chevron: true
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            onChevronClicked: root.requestMenu("network")
        } }
    Component { id: btC
        Tile {
            glyph: !root.adapter || !root.adapter.enabled ? root.cp(0xF00B2) : root.cp(0xF00AF)
            title: "Bluetooth"; tone: main.tone(1)
            sub: !root.adapter || !root.adapter.enabled ? "Off" : (root.btDevs.length > 0 ? (root.btDevs.length === 1 ? root.btDevs[0].name : root.btDevs.length + " connected") : "On")
            checked: !!root.adapter && root.adapter.enabled; chevron: true
            onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            onChevronClicked: root.requestMenu("bluetooth")
        } }
    Component { id: audioC
        Tile {
            glyph: root.muted ? root.cp(0xF0581) : root.cp(0xF057E)
            title: "Audio"; tone: main.tone(2)
            sub: root.sinkName
            checked: !root.muted; chevron: true
            onClicked: if (root.soundReady) root.sink.audio.muted = !root.sink.audio.muted
            onChevronClicked: root.requestMenu("sound")
        } }
    Component { id: quietC
        Tile {
            glyph: root.cp(0xF009B)
            title: "Quiet"; tone: main.tone(3)
            sub: root.nf && root.nf.dnd ? "On" : "Off"
            checked: !!root.nf && root.nf.dnd
            onClicked: if (root.nf) root.nf.dnd = !root.nf.dnd
        } }
    Component { id: nightC
        Tile {
            glyph: root.cp(0xF0594)
            title: "Night Light"; tone: main.tone(4)
            sub: root.tog.nightOn ? "On" : "Off"
            checked: root.tog.nightOn
            onClicked: root.tog.toggleNight()
        } }
    Component { id: airplaneC
        Tile {
            glyph: root.cp(root.tog.airplaneOn ? 0xF001E : 0xF001D)
            title: "Airplane"; tone: main.tone(5)
            sub: root.tog.airplaneOn ? "On" : "Off"
            checked: root.tog.airplaneOn
            onClicked: root.tog.toggleAirplane()
        } }
    Component { id: caffeineC
        Tile {
            glyph: root.cp(0xF0176)
            title: "Keep Awake"; tone: main.tone(6)
            sub: root.tog.caffeineOn ? "On" : "Off"
            checked: root.tog.caffeineOn
            onClicked: root.tog.toggleCaffeine()
        } }
    Component { id: gameC
        Tile {
            glyph: root.cp(0xF0297)
            title: "Game Mode"; tone: main.tone(7)
            sub: root.tog.gameOn ? "On" : "Off"
            checked: root.tog.gameOn
            onClicked: root.tog.toggleGame()
        } }
    Component { id: micC
        Tile {
            glyph: root.cp(root.micMuted ? 0xF036D : 0xF036C)
            title: "Microphone"; tone: main.tone(8)
            sub: !root.micReady ? "No input" : (root.micMuted ? "Muted" : root.micLevel + "%")
            checked: root.micReady && !root.micMuted
            onClicked: if (root.micReady) root.source.audio.muted = !root.source.audio.muted
        } }
    Component { id: shotC
        Tile {
            glyph: root.cp(0xF0E51)
            title: "Screenshot"; tone: main.tone(9)
            sub: "Region"
            onClicked: { root.requestClose(); root.tog.screenshot(); }
        } }
    Component { id: wallC
        Tile {
            glyph: root.cp(0xF0E09)
            title: "Wallpaper"; tone: main.tone(10)
            sub: root.shell ? "No. " + root.shell.wallIndex : ""
            chevron: true
            onClicked: root.requestMenu("wallpaper")
            onChevronClicked: root.requestMenu("wallpaper")
        } }
    Component { id: themeC
        Tile {
            readonly property var themes: root.shell ? root.shell.themeList : null
            glyph: root.cp(0xF03D8)
            title: "Theme"; tone: main.tone(11)
            sub: themes && themes.data[root.shell.cfg.theme] ? themes.data[root.shell.cfg.theme].name : ""
            chevron: true
            onClicked: root.requestMenu("theme")
            onChevronClicked: root.requestMenu("theme")
        } }
    Component { id: batteryC
        Tile {
            glyph: root.batGlyph
            title: root.hasBattery ? root.level + "%" : "No battery"; tone: main.tone(12)
            readonly property string remaining: root.hasBattery ? root.span(root.charging ? root.battery.timeToFull : root.battery.timeToEmpty) : ""
            sub: !root.hasBattery ? "" : (root.charging ? "Charging" + (remaining !== "" ? " · " + remaining : "") : (remaining !== "" ? remaining + " left" : "On battery"))
            checked: root.charging
            interactive: false
        } }
    Component { id: volC
        PillSlider {
            glyph: root.muted ? root.cp(0xF0581) : root.cp(0xF057E)
            from: 0; to: 1; value: root.soundReady ? root.sink.audio.volume : 0
            valueText: root.muted ? "Muted" : root.vol + "%"; tone: main.tone(2)
            showChevron: true
            onChevronClicked: root.requestMenu("sound")
            onMoved: v => { if (root.soundReady) { root.sink.audio.volume = v; root.sink.audio.muted = false; } }
        } }
    Component { id: micvolC
        PillSlider {
            glyph: root.cp(root.micMuted ? 0xF036D : 0xF036C)
            from: 0; to: 1; value: root.micReady ? root.source.audio.volume : 0
            valueText: !root.micReady ? "No input" : (root.micMuted ? "Muted" : root.micLevel + "%"); tone: main.tone(8)
            onMoved: v => { if (root.micReady) { root.source.audio.volume = v; root.source.audio.muted = false; } }
        } }
    Component { id: brightC
        PillSlider {
            glyph: root.cp(0xF00E0)
            from: 5; to: 100; value: root.bright
            valueText: root.bright + "%"; tone: main.tone(5)
            onMoved: v => root.setBrightness(v)
            onPressedChanged: root.brightDragging = pressed
            showChevron: true
            onChevronClicked: root.requestMenu("display")
        } }
    Component { id: perfC
        ModePill {
            readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
            options: [{ "glyph": 0xF032A, "label": "Eco" }, { "glyph": 0xF0F85, "label": "Normal" }, { "glyph": 0xF14DE, "label": "Performance" }]
            tone: main.tone(5)
            current: Math.max(0, profiles.indexOf(PowerProfiles.profile))
            onPicked: i => {
                if (i === 2 && !PowerProfiles.hasPerformanceProfile) return;
                PowerProfiles.profile = profiles[i];
            }
        } }
    Component { id: systemC
        Rectangle {
            id: sysBox
            radius: 26; color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
            readonly property var rows: [
                { "name": "Processor", "frac": root.cpuUse, "text": Math.round(root.cpuUse * 100) + "%", "tone": 4 },
                { "name": "Memory", "frac": root.memUse, "text": Math.round(root.memUse * 100) + "%", "tone": 1 },
                { "name": "Temperature", "frac": Math.max(0, Math.min(1, (root.tempC - 30) / 70)), "text": root.tempC > 0 ? Math.round(root.tempC) + "°C" : "n/a", "tone": 7 }
            ]
            Column {
                anchors { fill: parent; leftMargin: 20; rightMargin: 20; topMargin: 12; bottomMargin: 12 }
                spacing: Math.max(4, (height - 3 * 26) / 2)
                Repeater {
                    model: sysBox.rows
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: 26
                        Text { text: modelData.name; color: main.muted; font { family: main.font; pixelSize: 11; weight: 600 } anchors.top: parent.top }
                        Text { text: modelData.text; color: main.text; font { family: main.font; pixelSize: 11; weight: 700 } anchors { top: parent.top; right: parent.right } }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 6; radius: 3; color: main.line
                            Rectangle {
                                height: parent.height; radius: 3; color: main.tone(modelData.tone)
                                width: Math.max(parent.height, parent.width * modelData.frac)
                                Behavior on width { NumberAnimation { duration: main.ms(400); easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        } }
    Component { id: mediaC
        Item {
            MediaCard { width: parent.width; height: parent.height; visible: !!root.player; p: root.player }
            Rectangle {
                anchors.fill: parent; radius: 26; visible: !root.player
                color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                Text { anchors.centerIn: parent; text: "Nothing playing"; color: main.muted; font { family: main.font; pixelSize: 13; weight: 600 } }
            }
        } }
    Component { id: notifC
        Item {
            id: nbox
            readonly property real rowH: 52
            readonly property int fit: Math.max(1, Math.floor((nbox.height - 30) / (rowH + 6)))
            readonly property var items: root.nf ? root.nf.history.slice(0, fit) : []
            function plain(t) { return String(t || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(); }
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
                        id: nrow
                        required property var modelData
                        width: nbox.width; height: nbox.rowH; radius: 22; clip: true
                        color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                        Column {
                            id: ntext
                            x: 18; width: parent.width - 18 - 56; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { width: parent.width; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
                                text: nbox.plain(nrow.modelData.summary); color: main.text; font { family: main.font; pixelSize: 12; weight: 700 } }
                            Text { width: parent.width; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
                                visible: text !== ""; text: nbox.plain(nrow.modelData.body); color: main.muted; font { family: main.font; pixelSize: 11 } }
                        }
                        Rectangle {
                            width: 28; height: 28; radius: 14; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            color: xm.containsMouse ? Qt.rgba(main.red.r, main.red.g, main.red.b, 0.25) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
                            Behavior on color { ColorAnimation { duration: main.ms(120) } }
                            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "×"; color: xm.containsMouse ? main.red : main.muted; font { pixelSize: 17; weight: 600 } }
                            MouseArea { id: xm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.nf) root.nf.removeHistory(nrow.modelData) }
                        }
                    }
                }
            }
        } }
}
