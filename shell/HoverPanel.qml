import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// The hover dashboard: three lanes of elements, arranged in Settings > Island. Its size follows what is in it.
Item {
    id: root
    required property var isl
    property bool active: false

    readonly property var shell: isl.shell
    readonly property var player: isl.player
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevs: adapter ? adapter.devices.values.filter(d => d.connected) : []
    readonly property var nf: shell ? shell.notifier : null
    readonly property string iconFont: "JetBrainsMono Nerd Font Propo"
    readonly property color faint: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
    readonly property real gap: 16
    readonly property var layout: shell.dash
    readonly property var laneNames: ["left", "center", "right"]
    readonly property var laneW: ({ "left": 160, "center": 268, "right": 160 })
    readonly property var present: laneNames.filter(z => layout[z].length > 0)
    readonly property real wantedW: Math.max(220, 40 + present.reduce((s, z) => s + laneW[z], 0) + gap * Math.max(0, present.length - 1))
    readonly property real wantedH: Math.max(112, Math.min(330, 32 + Math.max(laneH.left, laneH.center, laneH.right)))
    property var laneH: ({ "left": 0, "center": 0, "right": 0 })
    readonly property bool hasStatus: layout.left.concat(layout.center, layout.right).indexOf("status") >= 0

    function cp(n) { return String.fromCodePoint(n); }
    function setLaneH(z, h) { if (laneH[z] === h) return; const m = Object.assign({}, laneH); m[z] = h; laneH = m; }
    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var tog: shell.toggles
    property bool watching: false
    onActiveChanged: { if (active !== watching) { watching = active; tog.watch(active); shell.stats.watch(active); } }
    Component.onDestruction: { if (watching) { tog.watch(false); shell.stats.watch(false); } }
    function freeWorkspace() {
        for (let i = 1; i <= 10; i++) if (!Hyprland.workspaces.values.find(w => w.id === i)) return i;
        return 10;
    }

    // ---------------------------------------------------------------- the lanes
    Repeater {
        model: root.laneNames
        delegate: Item {
            id: lane
            required property string modelData
            readonly property var ids: root.layout[modelData]
            readonly property int pos: root.present.indexOf(modelData)
            visible: ids.length > 0
            x: 20 + (function () { let x = 0; for (let i = 0; i < pos; i++) x += root.laneW[root.present[i]] + root.gap; return x; })()
            y: 16; width: root.laneW[modelData]; height: parent.height - 32
            Column {
                id: stack
                width: parent.width; spacing: 10
                onHeightChanged: root.setLaneH(lane.modelData, height)
                Repeater {
                    model: lane.ids
                    delegate: Loader {
                        required property string modelData
                        width: stack.width
                        sourceComponent: root.parts[modelData]
                    }
                }
            }
        }
    }

    // the Control Center button stays reachable when there is no status element
    Rectangle {
        visible: !root.hasStatus
        width: 24; height: 24; radius: 12; x: parent.width - width - 14; y: 12; z: 5
        color: ccm2.containsMouse ? main.accent : root.faint
        Behavior on color { ColorAnimation { duration: main.ms(150) } }
        Text { anchors.centerIn: parent; text: root.cp(0xF0570); color: ccm2.containsMouse ? main.onAccent : main.text; font { family: root.iconFont; pixelSize: 13 } }
        MouseArea { id: ccm2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.isl.openMenu("quick", root.cp(0xF0570), "") }
    }

    readonly property var parts: ({ "workspaces": wsC, "clock": clockC, "music": musicC, "status": statusC, "toggles": togglesC,
                                    "volume": volumeC, "system": systemC, "date": dateC, "battery": batteryC })

    // ---------------------------------------------------------------- workspaces
    Component { id: wsC
        Item {
            height: wsHead.height + 6 + wsCol.height
            Row {
                id: wsHead
                spacing: 8; width: parent.width
                AppIcon {
                    size: 15; anchors.verticalCenter: parent.verticalCenter
                    appClass: Hyprland.activeToplevel && Hyprland.activeToplevel.lastIpcObject && Hyprland.activeToplevel.lastIpcObject["class"] ? Hyprland.activeToplevel.lastIpcObject["class"] : ""
                }
                Text {
                    width: parent.width - 22; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                    text: Hyprland.activeToplevel && Hyprland.activeToplevel.title !== "" ? Hyprland.activeToplevel.title : "Desktop"
                    color: main.text; font { family: main.font; pixelSize: 12; weight: 600 }
                }
            }
            Column {
                id: wsCol
                y: wsHead.height + 6; spacing: 1; width: parent.width
                Repeater {
                    model: 5
                    delegate: Item {
                        id: wsRow
                        required property int index
                        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                        readonly property bool cur: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1
                        width: wsCol.width; height: 18
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter; x: 1
                            width: wsRow.cur ? 8 : 5; height: wsRow.cur ? 14 : 5; radius: width / 2
                            color: wsRow.cur ? main.accent : (wsRow.ws ? main.text : main.line)
                            Behavior on height { NumberAnimation { duration: main.ms(160); easing.type: Easing.OutCubic } }
                        }
                        Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: wsRow.index + 1
                            color: wsRow.cur || wsRow.ws ? main.text : main.muted; font { family: main.font; pixelSize: 12; weight: wsRow.cur ? 700 : 500 } }
                        AppIcon {
                            readonly property var wins: wsRow.ws ? wsRow.ws.toplevels.values : []
                            readonly property string last: wsRow.ws && wsRow.ws.lastIpcObject && wsRow.ws.lastIpcObject.lastwindow ? String(wsRow.ws.lastIpcObject.lastwindow).replace("0x", "") : ""
                            readonly property var win: wsRow.cur && Hyprland.activeToplevel ? Hyprland.activeToplevel : (wins.find(t => t.address === last) || (wins.length > 0 ? wins[0] : null))
                            visible: !!win; x: 44; anchors.verticalCenter: parent.verticalCenter; size: 15
                            appClass: win && win.lastIpcObject && win.lastIpcObject["class"] ? win.lastIpcObject["class"] : ""
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (wsRow.index + 1) + " })") }
                    }
                }
                Item {
                    width: wsCol.width; height: 18
                    Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "+"; color: main.muted; font { family: main.font; pixelSize: 14 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + root.freeWorkspace() + " })") }
                }
            }
        } }

    // ---------------------------------------------------------------- clock and week
    Component { id: clockC
        Item {
            id: clockBox
            height: 74
            Rectangle {
                anchors.fill: parent; radius: 16
                color: clockMouse.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.10) : root.faint
                Behavior on color { ColorAnimation { duration: main.ms(150) } }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 5
                text: Qt.formatTime(clock.date, cfg.clock24 === false ? "h:mm AP" : "HH:mm"); color: main.text; font { family: main.font; pixelSize: 20; weight: 600 } }
            Row {
                id: week
                anchors.horizontalCenter: parent.horizontalCenter; y: 33; spacing: 0
                readonly property int firstDow: cfg.weekMonday ? 1 : 0
                readonly property date start: { const d = new Date(clock.date); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - ((d.getDay() - firstDow + 7) % 7)); return d; }
                Repeater {
                    model: 7
                    delegate: Item {
                        id: dayCell
                        required property int index
                        readonly property date day: new Date(week.start.getFullYear(), week.start.getMonth(), week.start.getDate() + index)
                        readonly property bool today: day.toDateString() === clock.date.toDateString()
                        width: clockBox.width / 7.6; height: 36
                        Text { anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.locale().dayName(dayCell.day.getDay(), Locale.ShortFormat).substring(0, dayCell.today ? 3 : 1).toUpperCase()
                            color: dayCell.today ? main.text : main.muted; font { family: main.font; pixelSize: 9; weight: 600 } }
                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 13; width: 22; height: 22; radius: 11; color: dayCell.today ? main.accent : "transparent"
                            Text { anchors.centerIn: parent; text: dayCell.day.getDate()
                                color: dayCell.today ? main.onAccent : (dayCell.day.getDay() === 0 || dayCell.day.getDay() === 6 ? main.muted : main.text)
                                font { family: main.font; pixelSize: 11; weight: dayCell.today ? 700 : 500 } } }
                    }
                }
            }
            MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.isl.openMenu("calendar", root.cp(0xF00ED), "") }
        } }

    // ---------------------------------------------------------------- music
    Component { id: musicC
        Item {
            id: mediaRow
            height: 38
            Rectangle {
                id: art
                width: 34; height: 34; radius: 10; color: root.faint; clip: true; anchors.verticalCenter: parent.verticalCenter
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""; visible: status === Image.Ready }
                Text { anchors.centerIn: parent; text: root.cp(0xF075A); color: main.muted; visible: !(root.player && root.player.trackArtUrl); font { family: root.iconFont; pixelSize: 16 } }
            }
            readonly property real ctlW: root.player ? 78 : 0
            Column {
                x: art.width + 10; width: parent.width - art.width - 10 - mediaRow.ctlW; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                Text { width: parent.width; elide: Text.ElideRight; text: root.player ? (root.player.trackTitle || "Unknown") : "Nothing playing"
                    color: root.player ? main.text : main.muted; font { family: main.font; pixelSize: 12; weight: 700 } }
                Text { width: parent.width; elide: Text.ElideRight; visible: !!root.player; text: root.player ? (root.player.trackArtist || "") : ""; color: main.muted; font { family: main.font; pixelSize: 10 } }
                Rectangle {
                    visible: !!root.player && root.player.length > 0
                    width: parent.width; height: 3; radius: 1.5; color: main.line
                    Rectangle { height: parent.height; radius: 1.5; color: main.accent
                        width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0 }
                    FrameAnimation { running: root.active && !!root.player && root.player.isPlaying; onTriggered: root.player.positionChanged() }
                }
            }
            Row {
                visible: !!root.player; anchors { right: parent.right; verticalCenter: parent.verticalCenter } spacing: 6
                Repeater {
                    model: [{ "g": 0xF04AE, "act": "prev" }, { "g": 0, "act": "toggle" }, { "g": 0xF04AD, "act": "next" }]
                    delegate: Item {
                        id: ctl
                        required property var modelData
                        width: 22; height: 22
                        Text { anchors.centerIn: parent
                            text: ctl.modelData.act === "toggle" ? root.cp(root.player && root.player.isPlaying ? 0xF03E4 : 0xF040A) : root.cp(ctl.modelData.g)
                            color: cm.containsMouse ? main.accent : main.text; font { family: root.iconFont; pixelSize: ctl.modelData.act === "toggle" ? 18 : 14 } }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!root.player) return; if (ctl.modelData.act === "prev") root.player.previous(); else if (ctl.modelData.act === "next") root.player.next(); else root.player.togglePlaying(); } }
                    }
                }
            }
        } }

    // ---------------------------------------------------------------- status
    Component { id: statusC
        Item {
            id: st
            height: 22 + stCol.height
            Text { text: "Status"; color: main.text; font { family: main.font; pixelSize: 12; weight: 700 } }
            Rectangle {
                width: 24; height: 24; radius: 12; x: parent.width - width; y: -4
                color: ccm.containsMouse ? main.accent : root.faint
                Behavior on color { ColorAnimation { duration: main.ms(150) } }
                Text { anchors.centerIn: parent; text: root.cp(0xF0570); color: ccm.containsMouse ? main.onAccent : main.text; font { family: root.iconFont; pixelSize: 13 } }
                MouseArea { id: ccm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.isl.openMenu("quick", root.cp(0xF0570), "") }
            }
            Column {
                id: stCol
                y: 22; spacing: 3; width: parent.width
                StatusRow { width: st.width; glyph: root.isl.charging ? root.cp(0xF0084) : root.cp(0xF0079); text1: root.isl.hasBattery ? root.isl.level + "%" : "AC"
                    text2: !root.isl.hasBattery ? "" : (root.isl.charging ? "plugged in" : "on battery") }
                StatusRow { width: st.width; glyph: root.cp(0xF05A9); text1: root.isl.wifiNet ? root.isl.wifiNet.name : "Wi-Fi off"
                    text2: root.isl.wifiNet ? Math.round(root.isl.wifiNet.signalStrength * 100) + "%" : ""; dim: !root.isl.wifiNet }
                StatusRow { width: st.width; glyph: root.cp(root.adapter && root.adapter.enabled ? 0xF00AF : 0xF00B2)
                    text1: !root.adapter || !root.adapter.enabled ? "Bluetooth off" : (root.btDevs.length > 0 ? root.btDevs[0].name : "Bluetooth on"); dim: !root.adapter || !root.adapter.enabled }
                StatusRow { width: st.width; glyph: root.isl.muted ? root.cp(0xF0581) : root.cp(0xF057E); text1: root.isl.muted ? "Muted" : root.isl.volPct + "%"; text2: "output"; dim: root.isl.muted }
                StatusRow { width: st.width; glyph: root.cp(root.nf && root.nf.dnd ? 0xF009B : 0xF009A)
                    text1: root.nf && root.nf.dnd ? "Quiet" : (root.nf && root.nf.history.length > 0 ? root.nf.history.length + " notifications" : "No notifications")
                    dim: !root.nf || root.nf.history.length === 0 }
            }
        } }

    // ---------------------------------------------------------------- quick switches
    Component { id: togglesC
        Row {
            spacing: 6
            Repeater {
                model: [{ "label": "Night", "g": 0xF0594, "key": "night" }, { "label": "Game", "g": 0xF0297, "key": "game" }]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: modelData.key === "night" ? root.tog.nightOn : root.tog.gameOn
                    height: 22; width: 77; radius: 11
                    color: on ? main.accent : (cmo.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.14) : root.faint)
                    Behavior on color { ColorAnimation { duration: main.ms(150) } }
                    Row { anchors.centerIn: parent; spacing: 4
                        Text { text: root.cp(chip.modelData.g); color: chip.on ? main.onAccent : main.text; font { family: root.iconFont; pixelSize: 10 } anchors.verticalCenter: parent.verticalCenter }
                        Text { text: chip.modelData.label; color: chip.on ? main.onAccent : main.text; font { family: main.font; pixelSize: 10; weight: 600 } anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: cmo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: chip.modelData.key === "night" ? root.tog.toggleNight() : root.tog.toggleGame() }
                }
            }
        } }

    // ---------------------------------------------------------------- volume
    Component { id: volumeC
        Item {
            height: 30
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool ok: !!sink && sink.ready && !!sink.audio
            PwObjectTracker { objects: [parent.sink] }
            Text { x: 0; anchors.verticalCenter: parent.verticalCenter; text: root.cp(root.isl.muted ? 0xF0581 : 0xF057E); color: main.accent; font { family: root.iconFont; pixelSize: 15 } }
            HSlider { x: 24; width: parent.width - 24 - 34; anchors.verticalCenter: parent.verticalCenter; from: 0; to: 1; value: parent.ok ? parent.sink.audio.volume : 0
                onMoved: v => { if (parent.ok) { parent.sink.audio.volume = v; parent.sink.audio.muted = false; } } }
            Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: root.isl.volPct + "%"; color: main.muted; font { family: main.font; pixelSize: 10; weight: 600 } }
        } }

    // ---------------------------------------------------------------- system
    Component { id: systemC
        Column {
            spacing: 5
            Repeater {
                model: [{ "n": "CPU", "f": root.shell.stats.cpu, "t": 4 }, { "n": "Memory", "f": root.shell.stats.mem, "t": 1 }]
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: 24
                    Text { text: modelData.n; color: main.muted; font { family: main.font; pixelSize: 10; weight: 600 } }
                    Text { anchors.right: parent.right; text: Math.round(modelData.f * 100) + "%"; color: main.text; font { family: main.font; pixelSize: 10; weight: 700 } }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 5; radius: 2.5; color: main.line
                        Rectangle { height: parent.height; radius: 2.5; color: main.tone(modelData.t); width: Math.max(parent.height, parent.width * modelData.f) } }
                }
            }
        } }

    // ---------------------------------------------------------------- date
    Component { id: dateC
        Column {
            Text { text: Qt.formatDate(clock.date, "dddd"); color: main.text; font { family: main.font; pixelSize: 16; weight: 700 } }
            Text { text: Qt.formatDate(clock.date, "d MMMM yyyy"); color: main.muted; font { family: main.font; pixelSize: 11 } }
        } }

    // ---------------------------------------------------------------- battery
    Component { id: batteryC
        Item {
            height: 38
            BatteryRing { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; stroke: 4
                level: root.isl.level; charging: root.isl.charging; present: root.isl.hasBattery; tint: main.accent }
            Column { x: 44; anchors.verticalCenter: parent.verticalCenter
                Text { text: root.isl.hasBattery ? root.isl.level + "%" : "AC power"; color: main.text; font { family: main.font; pixelSize: 14; weight: 700 } }
                Text { text: !root.isl.hasBattery ? "" : (root.isl.charging ? "Charging" : "On battery"); color: main.muted; font { family: main.font; pixelSize: 10 } } }
        } }
}
