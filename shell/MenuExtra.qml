import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

// The optional extra sections of the island menus (switched on in Settings > Menus). One file, one Component per section.
MenuSection {
    id: root
    readonly property string key: menu + "." + section
    function cp(n) { return String.fromCodePoint(n); }
    function weekOf(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sinkOk: !!sink && sink.ready && !!sink.audio
    readonly property bool srcOk: !!source && source.ready && !!source.audio
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    readonly property var wifiNet: wifiDev ? wifiDev.networks.values.find(n => n.connected) : null
    readonly property var nf: shell ? shell.notifier : null
    readonly property var tog: shell ? shell.toggles : null
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: { for (const p of players) if (p.isPlaying) return p; return players.length > 0 ? players[0] : null; }
    PwObjectTracker { objects: [root.sink, root.source] }
    Process { id: sh }
    function run(cmd) { sh.command = cmd; sh.running = false; sh.running = true; }
    SystemClock { id: clk; precision: SystemClock.Seconds }
    Component.onCompleted: if (tog) tog.watch(true)
    Component.onDestruction: if (tog) tog.watch(false)

    Loader { width: parent.width; sourceComponent: ({
        "network.airplane": airplaneC, "network.speed": speedC, "network.ping": pingC,
        "bluetooth.btBattery": btBatteryC,
        "sound.micvol": micvolC, "sound.mutes": mutesC, "sound.appMixer": appMixerC,
        "display.nightlight": nightC, "display.cast": castC,
        "notifications.timeout": notifTimeoutC, "notifications.quiet": quietC,
        "calendar.clock": bigClockC, "calendar.weekInfo": dateFinderC,
        "media.volume": mediaVolC, "media.source": mediaSourceC, "media.position": mediaPosC,
        "theme.accent": accentC, "theme.font": fontC, "theme.glass": glassC,
        "wallpaper.dim": dimC, "wallpaper.blur": blurC, "wallpaper.fit": fitC })[root.key] }

    // ---- shared pieces
    component Line: Item {
        id: ln
        property string label: ""
        property string value: ""
        height: 22
        Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: ln.label; color: main.muted; font { family: main.font; pixelSize: 12 } }
        Text { anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } text: ln.value; color: main.text; font { family: main.font; pixelSize: 12; weight: 600 } }
    }

    // ---- Wi-Fi
    Component { id: airplaneC; PillRow { glyph: root.cp(root.tog && root.tog.airplaneOn ? 0xF001E : 0xF001D); title: "Airplane mode"; sub: root.tog && root.tog.airplaneOn ? "On" : "Off"; checked: !!root.tog && root.tog.airplaneOn
        onClicked: root.tog.toggleAirplane() } }

    Component { id: speedC
        Row { id: spd; spacing: 8; width: parent.width
            property real down: 0
            property real up: 0
            property real lastRx: -1
            property real lastTx: 0
            property real lastAt: 0
            function fmt(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : (b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s"); }
            function parse(t) {
                let rx = 0, tx = 0;
                for (const l of t.split("\n")) {
                    const c = l.indexOf(":");
                    if (c < 0) continue;
                    const n = l.slice(0, c).trim();
                    if (n === "lo" || /^(veth|docker|virbr|br-|tun|tap)/.test(n)) continue;
                    const f = l.slice(c + 1).trim().split(/\s+/);
                    rx += Number(f[0]) || 0; tx += Number(f[8]) || 0;
                }
                const now = Date.now();
                if (lastRx >= 0 && now > lastAt) { const dt = (now - lastAt) / 1000; down = Math.max(0, (rx - lastRx) / dt); up = Math.max(0, (tx - lastTx) / dt); }
                lastRx = rx; lastTx = tx; lastAt = now;
            }
            Process { id: nd; command: ["cat", "/proc/net/dev"]; stdout: StdioCollector { onStreamFinished: spd.parse(text) } }
            Timer { interval: 1000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: { nd.running = false; nd.running = true; } }
            Repeater {
                model: [{ "g": 0xF0ED, "t": "Download" }, { "g": 0xF0EE, "t": "Upload" }]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: (spd.width - 8) / 2; height: 54; radius: 16
                    color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: root.cp(modelData.g); color: main.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 } }
                    Column { x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52; spacing: 1
                        Text { width: parent.width; elide: Text.ElideRight; text: spd.fmt(index === 0 ? spd.down : spd.up); color: main.text; font { family: main.font; pixelSize: 13; weight: 700 } }
                        Text { text: modelData.t; color: main.muted; font { family: main.font; pixelSize: 11 } } }
                }
            }
        } }
    Component { id: pingC
        Rectangle { id: pg; width: parent.width; height: 54; radius: 16; color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
            property var hist: []
            property real last: -1
            function add(v) { const h = hist.slice(-23); h.push(v); hist = h; last = v; }
            Process { id: pp; command: ["ping", "-c", "1", "-W", "1", "1.1.1.1"]
                stdout: StdioCollector { onStreamFinished: { const r = /time=([0-9.]+)/.exec(text); pg.add(r ? Number(r[1]) : -1); } } }
            Timer { interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: { pp.running = false; pp.running = true; } }
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: root.cp(0xF0002); color: main.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 } }
            Column { x: 46; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                Text { text: pg.last < 0 ? (pg.hist.length === 0 ? "Measuring…" : "No answer") : Math.round(pg.last) + " ms"; color: main.text; font { family: main.font; pixelSize: 13; weight: 700 } }
                Text { text: "Latency to 1.1.1.1"; color: main.muted; font { family: main.font; pixelSize: 11 } } }
            Row { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } spacing: 3; height: 26
                Repeater { model: 24
                    delegate: Rectangle { required property int index
                        readonly property real v: { const k = index - (24 - pg.hist.length); return k >= 0 ? pg.hist[k] : -2; }
                        anchors.bottom: parent.bottom; width: 3; radius: 1.5
                        height: v === -2 ? 3 : (v < 0 ? 26 : Math.max(4, Math.min(26, v / 2)))
                        color: v === -2 ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.10) : (v < 0 ? Qt.rgba(1, 0.35, 0.35, 0.8) : main.accent) } } }
        } }

    // ---- Bluetooth
    Component { id: btBatteryC
        Column { id: bb; spacing: 6; width: parent.width
            readonly property var devs: root.adapter ? root.adapter.devices.values.filter(d => d.connected) : []
            Text { visible: bb.devs.length === 0; leftPadding: 6; text: "No device connected"; color: main.muted; font { family: main.font; pixelSize: 12 } }
            Repeater { model: bb.devs
                delegate: Rectangle { required property var modelData
                    width: bb.width; height: 54; radius: 16; color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: root.shell ? root.shell.btGlyph(modelData.icon, modelData.name) : ""; color: main.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 } }
                    Text { x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 50 - 120; elide: Text.ElideRight; text: modelData.name; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
                    Text { visible: !modelData.batteryAvailable; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: "No battery info"; color: main.muted; font { family: main.font; pixelSize: 11 } }
                    Row { visible: modelData.batteryAvailable; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } spacing: 8
                        Rectangle { width: 44; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.12)
                            Rectangle { width: Math.max(8, parent.width * modelData.battery); height: parent.height; radius: 4; color: modelData.battery < 0.2 ? "#e5645c" : main.accent } }
                        Text { text: Math.round(modelData.battery * 100) + "%"; color: main.text; font { family: main.font; pixelSize: 12; weight: 700 } } }
                } }
        } }

    // ---- Sound
    Component { id: micvolC; PillSlider { width: parent.width; glyph: root.cp(root.srcOk && root.source.audio.muted ? 0xF036D : 0xF036C); from: 0; to: 1; value: root.srcOk ? root.source.audio.volume : 0
        valueText: !root.srcOk ? "No input" : (root.source.audio.muted ? "Muted" : Math.round(root.source.audio.volume * 100) + "%")
        onMoved: v => { if (root.srcOk) { root.source.audio.volume = v; root.source.audio.muted = false; } } } }
    Component { id: mutesC
        Row { spacing: 8; width: parent.width
            PillRow { width: (parent.width - 8) / 2; glyph: root.cp(root.sinkOk && root.sink.audio.muted ? 0xF0581 : 0xF057E); title: "Speakers"; sub: root.sinkOk && root.sink.audio.muted ? "Muted" : "On"; checked: root.sinkOk && root.sink.audio.muted
                onClicked: if (root.sinkOk) root.sink.audio.muted = !root.sink.audio.muted }
            PillRow { width: (parent.width - 8) / 2; glyph: root.cp(root.srcOk && root.source.audio.muted ? 0xF036D : 0xF036C); title: "Microphone"; sub: root.srcOk && root.source.audio.muted ? "Muted" : "On"; checked: root.srcOk && root.source.audio.muted
                onClicked: if (root.srcOk) root.source.audio.muted = !root.source.audio.muted } } }
    Component { id: appMixerC
        Column { id: am; spacing: 4; width: parent.width
            readonly property var apps: Pipewire.nodes.values.filter(n => n.isSink && n.isStream && !!n.audio).slice(0, 6)
            PwObjectTracker { objects: am.apps }
            function nameOf(n) { const p = n.properties || {}; return p["application.name"] || p["media.name"] || n.nickname || n.name || "App"; }
            Text { visible: am.apps.length === 0; leftPadding: 6; text: "No app is playing sound"; color: main.muted; font { family: main.font; pixelSize: 12 } }
            Repeater { model: am.apps
                delegate: Item { required property var modelData
                    width: am.width; height: 40
                    Rectangle { id: mb; width: 30; height: 30; radius: 15; anchors.verticalCenter: parent.verticalCenter
                        color: modelData.audio.muted ? Qt.rgba(1, 0.35, 0.35, 0.25) : (mm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.14) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07))
                        Text { anchors.centerIn: parent; text: root.cp(modelData.audio.muted ? 0xF0581 : 0xF057E); color: modelData.audio.muted ? "#e5645c" : main.text; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 15 } }
                        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.audio.muted = !modelData.audio.muted } }
                    Text { x: 40; width: 86; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: am.nameOf(modelData); color: main.text; font { family: main.font; pixelSize: 12; weight: 600 } }
                    HSlider { x: 132; width: parent.width - 132 - 44; anchors.verticalCenter: parent.verticalCenter; from: 0; to: 1; value: modelData.audio.volume; onMoved: v => { modelData.audio.volume = v; modelData.audio.muted = false; } }
                    Text { anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } text: Math.round(modelData.audio.volume * 100) + "%"; color: main.muted; font { family: main.font; pixelSize: 11; weight: 600 } }
                } }
        } }

    // ---- Display
    Component { id: nightC; PillRow { glyph: root.cp(0xF0594); title: "Night Light"; sub: root.tog && root.tog.nightOn ? "On" : "Off"; checked: !!root.tog && root.tog.nightOn; onClicked: root.tog.toggleNight() } }
    Component { id: castC
        Column { id: ct; spacing: 6; width: parent.width
            property var found: []
            property bool scanning: false
            property bool hasApp: false
            function parse(t) {
                const out = [], seen = {};
                for (const l of t.split("\n")) {
                    if (l[0] !== "=") continue;
                    const f = l.split(";");
                    const kind = f[4] === "_googlecast._tcp" ? "Chromecast" : "AirPlay";
                    let name = (f[3] || "").replace(/\\032/g, " ");
                    const fn = /"fn=([^"]+)"/.exec(l);
                    if (fn) name = fn[1];
                    if (!name || seen[name]) continue;
                    seen[name] = true; out.push({ "name": name, "kind": kind });
                }
                found = out;
            }
            Process { id: app; command: ["sh", "-c", "command -v gnome-network-displays"]; running: true; onExited: code => ct.hasApp = code === 0 }
            Process { id: scan; command: ["sh", "-c", "avahi-browse -rtp _googlecast._tcp; avahi-browse -rtp _airplay._tcp"]
                onRunningChanged: ct.scanning = running
                stdout: StdioCollector { onStreamFinished: ct.parse(text) } }
            Timer { interval: 20000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: { if (!scan.running) scan.running = true; } }
            Text { leftPadding: 6; text: ct.scanning && ct.found.length === 0 ? "Looking for displays…" : (ct.found.length === 0 ? "No displays found on this network" : "Displays on this network"); color: main.muted; font { family: main.font; pixelSize: 12 } }
            Repeater { model: ct.found
                delegate: PillRow { required property var modelData; width: ct.width; glyph: root.cp(0xF0118); title: modelData.name; sub: modelData.kind
                    onClicked: root.run(ct.hasApp ? ["gnome-network-displays"] : ["sh", "-c", "true"]) } }
            PillRow { width: ct.width; glyph: root.cp(0xF0118); title: "Other wireless displays"; sub: ct.hasApp ? "Open the casting app" : "Needs gnome-network-displays"
                onClicked: if (ct.hasApp) root.run(["gnome-network-displays"]) }
        } }

    // ---- Notifications
    Component { id: notifTimeoutC
        Item { height: 44
            Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: "Pop-up time"; color: main.text; font { family: main.font; pixelSize: 12; weight: 600 } }
            HStepper { anchors { right: parent.right; verticalCenter: parent.verticalCenter } implicitWidth: 116; width: 116; from: 2; to: 20; unit: " s"; value: root.shell ? root.shell.cfg.notifTimeout : 6
                onMoved: v => root.shell.set("notifTimeout", v) } } }
    Component { id: quietC; PillRow { glyph: root.cp(root.nf && root.nf.dnd ? 0xF009B : 0xF009A); title: "Quiet mode"; sub: root.nf && root.nf.dnd ? "On" : "Off"; checked: !!root.nf && root.nf.dnd
        onClicked: if (root.nf) root.nf.dnd = !root.nf.dnd } }

    // ---- Calendar
    Component { id: bigClockC
        Column { width: parent.width
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Qt.formatTime(clk.date, root.shell && root.shell.cfg.clock24 === false ? "h:mm AP" : "HH:mm"); color: main.text; font { family: main.font; pixelSize: 34; weight: 300 } }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(clk.date, "dddd d MMMM"); color: main.accent; font { family: main.font; pixelSize: 13; weight: 600 } } } }
    Component { id: dateFinderC
        Column { id: df; spacing: 6; width: parent.width
            readonly property string stored: root.shell ? (root.shell.menuOpt("calendar", "target") || "") : ""
            readonly property date now: clk.date
            readonly property var parts: { const p = /^(\d+)-(\d+)-(\d+)$/.exec(stored); return p ? [Number(p[1]), Number(p[2]), Number(p[3])] : [now.getFullYear(), now.getMonth() + 1, now.getDate()]; }
            readonly property int dim: new Date(parts[0], parts[1], 0).getDate()
            readonly property date target: new Date(parts[0], parts[1] - 1, Math.min(parts[2], dim))
            readonly property date startToday: new Date(now.getFullYear(), now.getMonth(), now.getDate())
            readonly property int diff: Math.round((target - startToday) / 86400000)
            readonly property int dayOfYear: Math.round((target - new Date(target.getFullYear(), 0, 0)) / 86400000)
            function pick(y, mo, d) { const dm = new Date(y, mo, 0).getDate(); root.shell.setMenuOpt("calendar", "target", y + "-" + mo + "-" + Math.min(d, dm)); }
            Text { leftPadding: 6; text: "Pick a date"; color: main.muted; font { family: main.font; pixelSize: 12 } }
            Row { spacing: 6; width: parent.width
                HStepper { implicitWidth: (df.width - 12) * 0.28; width: implicitWidth; from: 1; to: df.dim; value: Math.min(df.parts[2], df.dim); onMoved: v => df.pick(df.parts[0], df.parts[1], v) }
                HStepper { implicitWidth: (df.width - 12) * 0.28; width: implicitWidth; from: 1; to: 12; value: df.parts[1]; onMoved: v => df.pick(df.parts[0], v, df.parts[2]) }
                HStepper { implicitWidth: (df.width - 12) * 0.44; width: implicitWidth; from: 1970; to: 2200; value: df.parts[0]; onMoved: v => df.pick(v, df.parts[1], df.parts[2]) }
            }
            Column { width: parent.width; spacing: 2
                Line { width: parent.width; label: "Date"; value: Qt.formatDate(df.target, "dddd d MMMM yyyy") }
                Line { width: parent.width; label: "From today"; value: df.diff === 0 ? "Today" : (df.diff > 0 ? "In " + df.diff + (df.diff === 1 ? " day" : " days") : -df.diff + (df.diff === -1 ? " day ago" : " days ago")) }
                Line { width: parent.width; label: "Week number"; value: root.weekOf(df.target) }
                Line { width: parent.width; label: "Day of the year"; value: df.dayOfYear }
                Line { width: parent.width; label: "Days left that year"; value: Math.round((new Date(df.target.getFullYear(), 11, 31) - df.target) / 86400000) } }
        } }

    // ---- Now playing
    Component { id: mediaVolC; PillSlider { width: parent.width; glyph: root.cp(0xF057E); from: 0; to: 1; value: root.sinkOk ? root.sink.audio.volume : 0
        valueText: root.sinkOk ? Math.round(root.sink.audio.volume * 100) + "%" : ""
        onMoved: v => { if (root.sinkOk) { root.sink.audio.volume = v; root.sink.audio.muted = false; } } } }
    Component { id: mediaSourceC
        Column { spacing: 2
            Line { width: parent.width; label: "Player"; value: root.player ? (root.player.identity || "-") : "Nothing open" }
            Line { width: parent.width; label: "Album"; value: root.player && root.player.trackAlbum ? root.player.trackAlbum : "-" }
            Line { width: parent.width; label: "Status"; value: root.player ? (root.player.isPlaying ? "Playing" : "Paused") : "-" } } }
    Component { id: mediaPosC
        PillSlider { width: parent.width; glyph: root.cp(0xF075A); from: 0; to: root.player && root.player.length > 0 ? root.player.length : 1
            value: root.player ? Math.min(root.player.position, to) : 0
            function fmt(s) { s = Math.max(0, Math.round(s)); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60); }
            valueText: root.player ? fmt(root.player.position) + " / " + (root.player.length > 0 ? fmt(root.player.length) : "-:--") : "0:00"
            onMoved: v => { if (root.player && root.player.canSeek) root.player.position = v; }
            Timer { interval: 1000; running: !!root.player && root.player.isPlaying; repeat: true; onTriggered: root.player.positionChanged() } } }

    // ---- Theme
    Component { id: accentC; AccentChips { width: parent.width; value: root.shell.cfg.accent; onPicked: c => root.shell.set("accent", c); onCustomRequested: root.shell.openSettings() } }
    Component { id: fontC; FontChips { width: parent.width; value: root.shell.cfg.font; onPicked: f => root.shell.set("font", f) } }
    Component { id: glassC; PillRow { glyph: root.cp(0xF05CC); title: "Frosted glass"; sub: root.shell.cfg.glassBar ? "On" : "Off"; checked: root.shell.cfg.glassBar
        onClicked: root.shell.set("glassBar", !root.shell.cfg.glassBar) } }

    // ---- Wallpaper
    Component { id: dimC; PillSlider { width: parent.width; glyph: root.cp(0xF00DF); from: 0; to: 0.7; value: root.shell.cfg.wallDim; valueText: "Dim " + Math.round(root.shell.cfg.wallDim * 100) + "%"; onMoved: v => root.shell.set("wallDim", Math.round(v * 20) / 20) } }
    Component { id: blurC; PillSlider { width: parent.width; glyph: root.cp(0xF0E09); from: 0; to: 1; value: root.shell.cfg.wallBlur; valueText: "Blur " + Math.round(root.shell.cfg.wallBlur * 100) + "%"; onMoved: v => root.shell.set("wallBlur", Math.round(v * 20) / 20) } }
    Component { id: fitC
        Row { width: parent.width; spacing: 6
            Repeater { model: [["fill", "Fill the screen"], ["fit", "Show whole image"]]
                delegate: Rectangle { required property var modelData; readonly property bool on: root.shell.cfg.wallFit === modelData[0]
                    width: (parent.width - 6) / 2; height: 40; radius: 20
                    color: on ? main.accent : (fm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.14) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07))
                    Text { anchors.centerIn: parent; text: modelData[1]; color: on ? main.onAccent : main.text; font { family: main.font; pixelSize: 12; weight: 700 } }
                    MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shell.set("wallFit", modelData[0]) } } } } }
}
