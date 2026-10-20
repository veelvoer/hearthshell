import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// The content of one desktop or lock-screen widget, drawn at its design size and scaled by whoever places it.
// Every look and option comes from the widget's entry in WidgetDefs.
Item {
    id: root
    required property var spec
    required property var shell
    property bool live: true                       // false inside the editor: nothing reacts
    // where this widget sits on the screen: frosted glass blurs exactly the piece of wallpaper behind it
    property real originX: 0
    property real originY: 0
    property real screenW: 0
    property real screenH: 0
    property string backdropUrl: ""
    readonly property real sc: scale > 0 ? scale : 1
    readonly property var pal: shell.main
    readonly property var defs: shell.widgetDefs
    readonly property var def: defs.types[spec.type] || ({ "w": 200, "h": 100, "style": "plain" })
    function v(k) { return defs.val(spec, k); }
    function cp(n) { return String.fromCodePoint(n); }

    // ---- the look every widget shares
    readonly property string style: v("style")
    readonly property real rad: v("radius")
    readonly property string tint: v("tint")
    readonly property color fg: tint === "accent" ? pal.accent : (tint === "soft" ? Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.7) : pal.text)
    readonly property color fg2: tint === "accent" ? Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.7)
        : (tint === "soft" ? Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.45) : pal.muted)
    function fam(key) {
        const f = v(key);
        return f === "serif" ? pal.serif : (f === "mono" ? "monospace" : shell.clockFont);
    }
    function hAlign(key) { const a = v(key); return a === "left" ? Text.AlignLeft : (a === "right" ? Text.AlignRight : Text.AlignHCenter); }

    width: def.w; height: def.h
    opacity: v("opacity")

    SystemClock { id: clk; precision: SystemClock.Seconds }
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.isPresent && battery.isLaptopBattery
    readonly property int level: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: !!battery && battery.state === UPowerDeviceState.Charging
    readonly property bool paperNote: spec.type === "note" && v("paper") !== "theme"

    Component.onCompleted: if (spec.type === "system") shell.stats.watch(true)
    Component.onDestruction: if (spec.type === "system") shell.stats.watch(false)

    // ---- the surface behind the content
    SoftShadow {
        visible: v("shadow") && (root.style !== "plain" || root.paperNote)
        width: parent.width; height: parent.height; radius: root.rad; strength: 0.5; offsetY: 6
    }
    Loader { id: frostLoader; active: root.style === "glass" && root.screenW > 0; anchors.fill: parent
        sourceComponent: Item {
            id: fr
            readonly property real m: 36
            Item {
                id: bd; visible: false; width: root.screenW / root.sc; height: root.screenH / root.sc
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(root.screenW, root.screenH)
                    source: root.backdropUrl !== "" ? root.backdropUrl : root.shell.wallpaperSource }
                Rectangle { anchors.fill: parent; color: "black"; opacity: root.backdropUrl !== "" ? 0.12 : root.shell.cfg.wallDim }
            }
            ShaderEffectSource {
                id: crop; visible: false
                sourceItem: bd
                sourceRect: Qt.rect(root.originX / root.sc - fr.m, root.originY / root.sc - fr.m, root.width + fr.m * 2, root.height + fr.m * 2)
                textureSize: Qt.size(root.width + fr.m * 2, root.height + fr.m * 2)
            }
            Item {
                x: 0; y: 0; width: root.width; height: root.height
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: frMask }
                MultiEffect {
                    x: -fr.m; y: -fr.m; width: root.width + fr.m * 2; height: root.height + fr.m * 2
                    source: crop; autoPaddingEnabled: false
                    blurEnabled: true; blur: root.v("frost"); blurMax: 64
                    saturation: 0.15
                }
            }
            Item { id: frMask; width: root.width; height: root.height; visible: false; layer.enabled: true
                Rectangle { anchors.fill: parent; radius: root.rad } }
        }
    }
    Rectangle {
        anchors.fill: parent; radius: root.rad
        visible: root.style !== "plain" && !root.paperNote
        color: root.style === "outline" ? "transparent" : Qt.rgba(root.pal.bg.r, root.pal.bg.g, root.pal.bg.b, root.v("bgAlpha"))
        border.width: root.style === "outline" ? 2 : 1
        border.color: root.style === "outline" ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.8) : Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, root.style === "glass" ? 0.18 : 0.1)
    }
    Rectangle {
        anchors.fill: parent; radius: root.rad; visible: root.paperNote
        color: ({ "yellow": "#f7e48b", "mint": "#bfe8cf", "sky": "#bcd9f2", "rose": "#f2c5d3" })[root.v("paper")] || "transparent"
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ({ "clock": clockC, "analog": analogC, "date": dateC, "greeting": greetingC, "text": textC, "countdown": countdownC,
                            "calendar": calendarC, "media": mediaC, "system": systemC, "battery": batteryC, "note": noteC, "image": imageC })[root.spec.type]
    }

    function dateLine(kind) { return Qt.formatDate(clk.date, kind === "short" ? "d MMM" : (kind === "numeric" ? "dd/MM/yyyy" : "d MMMM yyyy")); }

    // ------------------------------------------------------------------ clock
    Component { id: clockC
        Column {
            anchors.verticalCenter: parent.verticalCenter; x: 12; width: parent.width - 24; spacing: -2
            readonly property string hour: root.v("hour")
            readonly property bool h24: hour === "24" || (hour === "theme" && root.shell.cfg.clock24)
            Text {
                width: parent.width; height: 124; fontSizeMode: Text.Fit; minimumPixelSize: 30
                horizontalAlignment: root.hAlign("align"); verticalAlignment: Text.AlignVCenter
                text: Qt.formatDateTime(clk.date, (parent.h24 ? "HH:mm" : "h:mm") + (root.v("seconds") ? ":ss" : ""))
                color: root.fg; font { family: root.fam("font"); pixelSize: 112; weight: Number(root.v("weight")) }
            }
            Text {
                visible: root.v("showDate"); width: parent.width; horizontalAlignment: root.hAlign("align")
                text: root.v("dateFmt") === "long" ? Qt.formatDate(clk.date, "dddd d MMMM") : (root.v("dateFmt") === "short" ? Qt.formatDate(clk.date, "ddd d MMM") : Qt.formatDate(clk.date, "dd/MM/yyyy"))
                color: root.fg2; font { family: root.fam("font"); pixelSize: 22; weight: 500 }
            }
        } }

    // ------------------------------------------------------------------ analog clock
    Component { id: analogC
        Item {
            id: dial
            readonly property real r: Math.min(width, height) / 2 - 6
            readonly property real hours: (clk.date.getHours() % 12) + clk.date.getMinutes() / 60
            Rectangle {
                anchors.centerIn: parent; width: dial.r * 2; height: width; radius: width / 2; visible: root.v("face")
                color: Qt.rgba(root.pal.bg.r, root.pal.bg.g, root.pal.bg.b, 0.55)
                border.width: 2; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.25)
            }
            Repeater {
                model: root.v("ticks") ? 12 : 0
                Item {
                    required property int index
                    anchors.centerIn: parent; width: 0; height: 0; rotation: index * 30
                    Rectangle { x: -(index % 3 === 0 ? 2 : 1); y: -dial.r + 8; width: index % 3 === 0 ? 4 : 2; height: index % 3 === 0 ? 14 : 8; radius: 2; color: root.fg2 }
                }
            }
            Repeater {
                model: root.v("numbers") ? 12 : 0
                Text {
                    required property int index
                    readonly property real a: (index + 1) * Math.PI / 6
                    x: dial.width / 2 + Math.sin(a) * dial.r * 0.72 - width / 2
                    y: dial.height / 2 - Math.cos(a) * dial.r * 0.72 - height / 2
                    text: index + 1; color: root.fg; font { family: root.pal.font; pixelSize: 22; weight: 600 }
                }
            }
            Item { anchors.centerIn: parent; width: 0; height: 0; rotation: dial.hours * 30
                Rectangle { x: -4; y: -dial.r * 0.5; width: 8; height: dial.r * 0.5 + 6; radius: 4; color: root.fg } }
            Item { anchors.centerIn: parent; width: 0; height: 0; rotation: (clk.date.getMinutes() + clk.date.getSeconds() / 60) * 6
                Rectangle { x: -3; y: -dial.r * 0.76; width: 6; height: dial.r * 0.76 + 6; radius: 3; color: root.fg } }
            Item { anchors.centerIn: parent; width: 0; height: 0; rotation: clk.date.getSeconds() * 6; visible: root.v("secondHand")
                Rectangle { x: -1; y: -dial.r * 0.86; width: 2; height: dial.r * 0.86 + 14; radius: 1; color: root.pal.accent } }
            Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: root.pal.accent }
        } }

    // ------------------------------------------------------------------ date
    Component { id: dateC
        Item {
            readonly property bool oneLine: root.v("layout") === "inline"
            Text {
                visible: parent.oneLine; anchors.centerIn: parent; width: parent.width - 24; horizontalAlignment: root.hAlign("align")
                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 16
                text: Qt.formatDate(clk.date, "dddd") + "  " + (root.v("fmt") === "long" ? Qt.formatDate(clk.date, "d MMMM") : root.dateLine(root.v("fmt")))
                color: root.fg; font { family: root.fam("font"); pixelSize: 40; weight: 600 }
            }
            Column {
                visible: !parent.oneLine; anchors.centerIn: parent; width: parent.width - 24; spacing: 0
                Text { width: parent.width; horizontalAlignment: root.hAlign("align"); text: Qt.formatDate(clk.date, "dddd"); color: root.fg; font { family: root.fam("font"); pixelSize: 46; weight: 600 } }
                Text { width: parent.width; horizontalAlignment: root.hAlign("align"); text: root.dateLine(root.v("fmt")); color: root.fg2; font { family: root.fam("font"); pixelSize: 20; weight: 500 } }
            }
        } }

    // ------------------------------------------------------------------ greeting
    Component { id: greetingC
        Column {
            anchors.centerIn: parent; width: parent.width - 24; spacing: 2
            readonly property int h: clk.date.getHours()
            Text {
                width: parent.width; horizontalAlignment: root.hAlign("align"); fontSizeMode: Text.HorizontalFit; minimumPixelSize: 16
                text: (parent.h < 5 ? "Good night" : parent.h < 12 ? "Good morning" : parent.h < 18 ? "Good afternoon" : "Good evening") + ", " + (root.v("name") !== "" ? root.v("name") : Quickshell.env("USER"))
                color: root.fg; font { family: root.shell.clockFont; pixelSize: 38; weight: Number(root.v("weight")) }
            }
            Text { visible: root.v("showDate"); width: parent.width; horizontalAlignment: root.hAlign("align")
                text: Qt.formatDate(clk.date, "dddd d MMMM"); color: root.fg2; font { family: root.shell.clockFont; pixelSize: 18; weight: 500 } }
        } }

    // ------------------------------------------------------------------ text
    Component { id: textC
        Text {
            x: 12; y: 8; width: parent.width - 24; height: parent.height - 16
            wrapMode: Text.WordWrap; fontSizeMode: Text.Fit; minimumPixelSize: 12
            horizontalAlignment: root.hAlign("align"); verticalAlignment: Text.AlignVCenter
            text: root.v("text"); color: root.fg
            font { family: root.fam("font"); pixelSize: root.v("size"); weight: Number(root.v("weight")) }
        } }

    // ------------------------------------------------------------------ countdown
    Component { id: countdownC
        Item {
            readonly property var target: root.v("date") !== "" ? new Date(root.v("date") + "T00:00:00") : null
            readonly property bool valid: !!target && !isNaN(target.getTime())
            readonly property int days: valid ? Math.round((target.getTime() - new Date(clk.date.getFullYear(), clk.date.getMonth(), clk.date.getDate()).getTime()) / 86400000) : 0
            Column {
                anchors.centerIn: parent; width: parent.width - 32; spacing: 0
                Text {
                    width: parent.width; horizontalAlignment: root.hAlign("align"); fontSizeMode: Text.HorizontalFit; minimumPixelSize: 20
                    text: parent.parent.valid ? Math.abs(parent.parent.days) : "Set a date"
                    color: parent.parent.valid ? root.pal.accent : root.fg2; font { family: root.shell.clockFont; pixelSize: parent.parent.valid ? 76 : 32; weight: 700 }
                }
                Text {
                    width: parent.width; horizontalAlignment: root.hAlign("align"); elide: Text.ElideRight
                    visible: parent.parent.valid
                    text: (Math.abs(parent.parent.days) === 1 ? "day " : "days ") + (parent.parent.days >= 0 ? "until " : "since ") + root.v("label")
                    color: root.fg; font { family: root.shell.clockFont; pixelSize: 18; weight: 500 }
                }
            }
        } }

    // ------------------------------------------------------------------ calendar
    Component { id: calendarC
        Item {
            id: cal
            readonly property date today: clk.date
            readonly property int firstDow: root.shell.cfg.weekMonday ? 1 : 0
            readonly property date first: new Date(today.getFullYear(), today.getMonth(), 1)
            readonly property int lead: (first.getDay() - firstDow + 7) % 7
            readonly property int days: new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
            readonly property int prevDays: new Date(today.getFullYear(), today.getMonth(), 0).getDate()
            readonly property bool wk: root.v("weekNumbers")
            readonly property real shiftY: root.v("header") ? 0 : -30
            readonly property real gx: wk ? 38 : 14
            function weekOf(d) {
                const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
                const n = t.getUTCDay() || 7;
                t.setUTCDate(t.getUTCDate() + 4 - n);
                return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
            }
            Text { visible: root.v("header"); x: 20; y: 14; text: Qt.formatDate(cal.today, "MMMM yyyy"); color: root.fg; font { family: root.pal.font; pixelSize: 17; weight: 700 } }
            Row {
                x: cal.gx; y: 46 + cal.shiftY; width: parent.width - cal.gx - 14
                Repeater {
                    model: 7
                    Text {
                        required property int index
                        width: parent.width / 7; horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((cal.firstDow + index) % 7, Locale.ShortFormat).slice(0, 1).toUpperCase()
                        color: root.fg2; font { family: root.pal.font; pixelSize: 11; weight: 700 }
                    }
                }
            }
            Column {
                visible: cal.wk; x: 14; y: 68 + cal.shiftY
                Repeater {
                    model: 6
                    Text {
                        required property int index
                        width: 22; height: 33; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: cal.weekOf(new Date(cal.today.getFullYear(), cal.today.getMonth(), index * 7 - cal.lead + 4))
                        color: root.fg2; font { family: root.pal.font; pixelSize: 10; weight: 600 }
                    }
                }
            }
            Grid {
                x: cal.gx; y: 68 + cal.shiftY; width: parent.width - cal.gx - 14; columns: 7
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property int day: index - cal.lead + 1
                        readonly property bool inMonth: day >= 1 && day <= cal.days
                        readonly property bool isToday: inMonth && day === cal.today.getDate()
                        readonly property string hl: root.v("highlight")
                        width: parent.width / 7; height: 33
                        Rectangle {
                            anchors.centerIn: parent; width: 28; height: 28; radius: parent.hl === "square" ? 8 : 14
                            visible: parent.isToday && parent.hl !== "dot"; color: root.pal.accent
                        }
                        Rectangle {
                            visible: parent.isToday && parent.hl === "dot"; width: 5; height: 5; radius: 2.5; color: root.pal.accent
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: parent.inMonth || root.v("neighbors")
                            text: parent.inMonth ? parent.day : (parent.day < 1 ? cal.prevDays + parent.day : parent.day - cal.days)
                            color: parent.isToday && parent.hl !== "dot" ? root.pal.onAccent : (parent.inMonth ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.28))
                            font { family: root.pal.font; pixelSize: 13; weight: parent.isToday ? 700 : 500 }
                        }
                    }
                }
            }
        } }

    // ------------------------------------------------------------------ music
    Component { id: mediaC
        Item {
            id: mc
            readonly property var p: root.player
            readonly property bool art: root.v("art")
            readonly property real tx: art ? 116 : 22
            visible: !(root.live && root.v("autoHide") && !p)
            Timer { interval: 1000; running: root.live && !!mc.p && mc.p.isPlaying; repeat: true; onTriggered: mc.p.positionChanged() }
            Rectangle {
                visible: mc.art; x: 16; y: 16; width: 84; height: 84; radius: Math.min(20, root.rad); clip: true
                color: Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, 0.08)
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready; source: mc.p && mc.p.trackArtUrl ? mc.p.trackArtUrl : "" }
                Text { anchors.centerIn: parent; text: root.cp(0xF075A); color: root.fg2; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 30 }
                    visible: !(mc.p && mc.p.trackArtUrl) }
            }
            Column {
                x: mc.tx; y: 18; width: parent.width - mc.tx - 16; spacing: 1
                Text { width: parent.width; elide: Text.ElideRight; text: mc.p ? (mc.p.trackTitle || "Unknown") : "Nothing playing"
                    color: mc.p ? root.fg : root.fg2; font { family: root.pal.font; pixelSize: 16; weight: 700 } }
                Text { width: parent.width; elide: Text.ElideRight; visible: !!mc.p; text: mc.p ? (mc.p.trackArtist || "") : ""
                    color: root.fg2; font { family: root.pal.font; pixelSize: 13 } }
            }
            Rectangle {
                visible: root.v("progress") && !!mc.p && mc.p.length > 0
                x: mc.tx; y: 66; width: parent.width - mc.tx - 16; height: 4; radius: 2; color: root.pal.line
                Rectangle { height: parent.height; radius: 2; color: root.pal.accent
                    width: mc.p && mc.p.length > 0 ? parent.width * Math.min(1, mc.p.position / mc.p.length) : 0 }
            }
            Row {
                visible: root.v("controls") && !!mc.p
                x: mc.tx + (parent.width - mc.tx - 16 - width) / 2; y: 76; spacing: 14
                Repeater {
                    model: ["prev", "toggle", "next"]
                    Item {
                        required property string modelData
                        width: 26; height: 26
                        Text { anchors.centerIn: parent
                            text: root.cp(modelData === "prev" ? 0xF04AE : modelData === "next" ? 0xF04AD : (root.player && root.player.isPlaying ? 0xF03E4 : 0xF040A))
                            color: bm.containsMouse ? root.pal.accent : root.fg; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: modelData === "toggle" ? 22 : 17 } }
                        MouseArea { id: bm; anchors.fill: parent; enabled: root.live; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!root.player) return; if (modelData === "prev") root.player.previous(); else if (modelData === "next") root.player.next(); else root.player.togglePlaying(); } }
                    }
                }
            }
        } }

    // ------------------------------------------------------------------ system
    Component { id: systemC
        Item {
            id: sysBox
            readonly property var st: root.shell.stats
            readonly property var rows: {
                const r = [];
                if (root.v("cpu")) r.push({ "name": "Processor", "short": "CPU", "frac": st.cpu, "text": Math.round(st.cpu * 100) + "%", "tone": 4 });
                if (root.v("memory")) r.push({ "name": "Memory", "short": "Memory", "frac": st.mem, "text": Math.round(st.mem * 100) + "%", "tone": 1 });
                if (root.v("temp")) r.push({ "name": "Temperature", "short": "Temp", "frac": Math.max(0, Math.min(1, (st.temp - 30) / 70)), "text": st.temp > 0 ? Math.round(st.temp) + "°C" : "n/a", "tone": 7 });
                if (root.v("disk")) r.push({ "name": "Disk", "short": "Disk", "frac": st.disk, "text": Math.round(st.disk * 100) + "%", "tone": 2 });
                return r;
            }
            readonly property bool bars: root.v("view") === "bars"
            readonly property real rowH: Math.min(34, (height - 30 - (rows.length - 1) * 6) / Math.max(1, rows.length))
            Column {
                visible: sysBox.bars
                anchors { fill: parent; leftMargin: 22; rightMargin: 22; topMargin: 16; bottomMargin: 14 }
                spacing: 6
                Repeater {
                    model: sysBox.rows
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: sysBox.rowH
                        Text { text: modelData.name; color: root.fg2; font { family: root.pal.font; pixelSize: 12; weight: 600 } anchors.top: parent.top }
                        Text { text: modelData.text; color: root.fg; font { family: root.pal.font; pixelSize: 12; weight: 700 } anchors { top: parent.top; right: parent.right } }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 7; radius: 3.5; color: root.pal.line
                            Rectangle { height: parent.height; radius: 3.5; color: root.pal.tone(modelData.tone); width: Math.max(parent.height, parent.width * modelData.frac)
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                        }
                    }
                }
            }
            Row {
                visible: !sysBox.bars
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 8
                Repeater {
                    model: sysBox.rows
                    delegate: Column {
                        required property var modelData
                        width: (sysBox.width - 28 - (sysBox.rows.length - 1) * 8) / Math.max(1, sysBox.rows.length); spacing: 0
                        anchors.verticalCenter: parent.verticalCenter
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 12
                            text: modelData.text; color: root.pal.tone(modelData.tone); font { family: root.pal.font; pixelSize: 30; weight: 700 } }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.short; color: root.fg2; font { family: root.pal.font; pixelSize: 11; weight: 600 } }
                    }
                }
            }
        } }

    // ------------------------------------------------------------------ battery
    Component { id: batteryC
        Item {
            readonly property bool ring: root.v("view") === "ring"
            BatteryRing {
                visible: parent.ring
                anchors.centerIn: parent; width: 112; height: 112; stroke: 9
                level: root.level; charging: root.charging; present: true; tint: root.pal.accent
            }
            Column {
                visible: parent.ring
                anchors.centerIn: parent; spacing: 0
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.hasBattery ? root.level + "%" : "AC"; color: root.fg; font { family: root.pal.font; pixelSize: 30; weight: 700 } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; visible: root.hasBattery && root.v("showState"); text: root.charging ? "Charging" : "Battery"; color: root.fg2; font { family: root.pal.font; pixelSize: 11 } }
            }
            Column {
                visible: !parent.ring
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 18 }
                spacing: 8
                Text { text: root.hasBattery ? root.level + "%" : "AC"; color: root.fg; font { family: root.pal.font; pixelSize: 34; weight: 700 } }
                Rectangle {
                    width: parent.width; height: 12; radius: 6; color: root.pal.line
                    Rectangle { height: parent.height; radius: 6; width: Math.max(parent.height, parent.width * root.level / 100)
                        color: root.charging ? "#6ee7a0" : (root.level <= 15 ? "#ff3b30" : root.pal.accent) }
                }
                Text { visible: root.hasBattery && root.v("showState"); text: root.charging ? "Charging" : "On battery"; color: root.fg2; font { family: root.pal.font; pixelSize: 11 } }
            }
        } }

    // ------------------------------------------------------------------ note
    Component { id: noteC
        Item {
            TextEdit {
                id: edit
                x: 18; y: 16; width: parent.width - 36; height: parent.height - 32
                readOnly: !root.live; enabled: root.live; wrapMode: TextEdit.Wrap
                color: root.paperNote ? "#2b2b2b" : root.fg
                selectionColor: root.pal.accent; selectedTextColor: root.pal.onAccent
                font { family: root.v("mono") ? "monospace" : root.pal.font; pixelSize: root.v("textSize") }
                Component.onCompleted: text = (root.shell.cfg.widgetNotes || {})[root.spec.id] || ""
                onTextChanged: if (activeFocus) save.restart()
                Timer { id: save; interval: 700; onTriggered: root.shell.setNote(root.spec.id, edit.text) }
                Text { visible: edit.text === ""; text: "Write a note…"; color: root.paperNote ? "#6b6b6b" : root.fg2; font: edit.font }
            }
        } }

    // ------------------------------------------------------------------ picture
    Component { id: imageC
        Item {
            id: pic
            readonly property string path: root.v("path")
            Image {
                id: img
                anchors.fill: parent; visible: false; asynchronous: true; layer.enabled: true
                fillMode: root.v("fit") === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                sourceSize: Qt.size(parent.width * 2, parent.height * 2)
                source: pic.path !== "" ? "file://" + pic.path : ""
            }
            Item { id: imask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: root.rad } }
            MultiEffect { anchors.fill: parent; source: img; maskEnabled: true; maskSource: imask; visible: pic.path !== "" && img.status === Image.Ready }
            Rectangle {
                anchors.fill: parent; radius: root.rad; color: "transparent"; visible: pic.path === "" || img.status !== Image.Ready
                border.width: 2; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.3)
                Column {
                    anchors.centerIn: parent; spacing: 6
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.cp(0xF02E9); color: root.fg2; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 36 } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Choose an image"; color: root.fg2; font { family: root.pal.font; pixelSize: 14; weight: 600 } }
                }
            }
        } }
}
