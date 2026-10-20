import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris

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
    readonly property real colGap: 16

    function cp(n) { return String.fromCodePoint(n); }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    readonly property var tog: shell.toggles
    property bool watching: false
    onActiveChanged: { if (active !== watching) { watching = active; tog.watch(active); } }
    Component.onDestruction: { if (watching) tog.watch(false); }
    function freeWorkspace() {
        for (let i = 1; i <= 10; i++) if (!Hyprland.workspaces.values.find(w => w.id === i)) return i;
        return 10;
    }

    // ------------------------------------------------------------ left: window + workspaces
    Item {
        id: leftCol
        x: 20; y: 16; width: 160; height: parent.height - 32

        Row {
            id: winRow
            spacing: 8; width: parent.width
            AppIcon {
                size: 15; anchors.verticalCenter: parent.verticalCenter
                appClass: Hyprland.activeToplevel && Hyprland.activeToplevel.lastIpcObject && Hyprland.activeToplevel.lastIpcObject["class"] ? Hyprland.activeToplevel.lastIpcObject["class"] : ""
            }
            Text {
                width: parent.width - 22; elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                text: Hyprland.activeToplevel && Hyprland.activeToplevel.title !== "" ? Hyprland.activeToplevel.title : "Desktop"
                color: main.text; font { family: main.font; pixelSize: 12; weight: 600 }
            }
        }
        Column {
            y: 28; spacing: 1; width: parent.width
            Repeater {
                model: 5
                delegate: Item {
                    id: wsRow
                    required property int index
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                    readonly property bool cur: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1
                    width: leftCol.width; height: 18
                    visible: index < 5
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: wsRow.cur ? 8 : 5; height: wsRow.cur ? 14 : 5; radius: width / 2
                        x: 1
                        color: wsRow.cur ? main.accent : (wsRow.ws ? main.text : main.line)
                        Behavior on height { NumberAnimation { duration: main.ms(160); easing.type: Easing.OutCubic } }
                    }
                    Text {
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        text: wsRow.index + 1
                        color: wsRow.cur ? main.text : (wsRow.ws ? main.text : main.muted)
                        font { family: main.font; pixelSize: 12; weight: wsRow.cur ? 700 : 500 }
                    }
                    AppIcon {
                        id: wsIcon
                        readonly property var wins: wsRow.ws ? wsRow.ws.toplevels.values : []
                        readonly property string last: wsRow.ws && wsRow.ws.lastIpcObject && wsRow.ws.lastIpcObject.lastwindow ? String(wsRow.ws.lastIpcObject.lastwindow).replace("0x", "") : ""
                        readonly property var win: wsRow.cur && Hyprland.activeToplevel ? Hyprland.activeToplevel
                            : (wins.find(t => t.address === last) || (wins.length > 0 ? wins[0] : null))
                        visible: !!win
                        x: 44; anchors.verticalCenter: parent.verticalCenter; size: 15
                        appClass: win && win.lastIpcObject && win.lastIpcObject["class"] ? win.lastIpcObject["class"] : ""
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (wsRow.index + 1) + " })")
                    }
                }
            }
            Item {
                width: leftCol.width; height: 18
                Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "+"; color: main.muted; font { family: main.font; pixelSize: 14 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + root.freeWorkspace() + " })") }
            }
        }
    }

    // ------------------------------------------------------------ centre: clock, week, media
    Item {
        id: centre
        x: leftCol.x + leftCol.width + root.colGap; y: 14
        width: right.x - x - root.colGap; height: parent.height - 28

        Item {
            id: clockBox
            width: parent.width; height: 74
            Rectangle {
                anchors.fill: parent; radius: 16
                color: clockMouse.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.10) : root.faint
                Behavior on color { ColorAnimation { duration: main.ms(150) } }
            }
            Text {
                id: bigClock
                anchors.horizontalCenter: parent.horizontalCenter; y: 5
                text: Qt.formatTime(clock.date, cfg.clock24 === false ? "h:mm AP" : "HH:mm")
                color: main.text; font { family: main.font; pixelSize: 20; weight: 600 }
            }
            Row {
                id: week
                anchors.horizontalCenter: parent.horizontalCenter; y: 33
                spacing: 0
                readonly property int firstDow: cfg.weekMonday ? 1 : 0
                readonly property date start: {
                    const d = new Date(clock.date);
                    d.setHours(0, 0, 0, 0);
                    d.setDate(d.getDate() - ((d.getDay() - firstDow + 7) % 7));
                    return d;
                }
                Repeater {
                    model: 7
                    delegate: Item {
                        id: dayCell
                        required property int index
                        readonly property date day: new Date(week.start.getFullYear(), week.start.getMonth(), week.start.getDate() + index)
                        readonly property bool today: day.toDateString() === clock.date.toDateString()
                        width: clockBox.width / 7.6; height: 36
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 0
                            text: Qt.locale().dayName(dayCell.day.getDay(), Locale.ShortFormat).substring(0, dayCell.today ? 3 : 1).toUpperCase()
                            color: dayCell.today ? main.text : main.muted
                            font { family: main.font; pixelSize: 9; weight: 600 }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 13
                            width: 22; height: 22; radius: 11
                            color: dayCell.today ? main.accent : "transparent"
                            Text {
                                anchors.centerIn: parent; text: dayCell.day.getDate()
                                color: dayCell.today ? main.onAccent : (dayCell.day.getDay() === 0 || dayCell.day.getDay() === 6 ? main.muted : main.text)
                                font { family: main.font; pixelSize: 11; weight: dayCell.today ? 700 : 500 }
                            }
                        }
                    }
                }
            }
            MouseArea {
                id: clockMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.isl.openMenu("calendar", root.cp(0xF00ED), "")
            }
        }

        Item {
            id: mediaRow
            y: clockBox.height + 10; width: parent.width; height: parent.height - y
            Rectangle {
                id: art
                width: 34; height: 34; radius: 10; color: root.faint; clip: true
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent; text: root.cp(0xF075A); color: main.muted
                    visible: !(root.player && root.player.trackArtUrl)
                    font { family: root.iconFont; pixelSize: 16 }
                }
            }
            Column {
                x: art.width + 10; width: parent.width - art.width - 10 - 78
                anchors.verticalCenter: parent.verticalCenter; spacing: 1
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: root.player ? (root.player.trackTitle || "Unknown") : "Nothing playing"
                    color: root.player ? main.text : main.muted; font { family: main.font; pixelSize: 12; weight: 700 }
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    visible: !!root.player; text: root.player ? (root.player.trackArtist || "") : ""
                    color: main.muted; font { family: main.font; pixelSize: 10 }
                }
                Rectangle {
                    visible: !!root.player && root.player.length > 0
                    width: parent.width; height: 3; radius: 1.5; color: main.line
                    Rectangle {
                        height: parent.height; radius: 1.5; color: main.accent
                        width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                    }
                    FrameAnimation { running: root.active && !!root.player && root.player.isPlaying; onTriggered: root.player.positionChanged() }
                }
            }
            Row {
                visible: !!root.player
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6
                Repeater {
                    model: [
                        { "g": 0xF04AE, "act": "prev" },
                        { "g": 0, "act": "toggle" },
                        { "g": 0xF04AD, "act": "next" }
                    ]
                    delegate: Item {
                        id: ctl
                        required property var modelData
                        width: 22; height: 22
                        Text {
                            anchors.centerIn: parent
                            text: ctl.modelData.act === "toggle" ? root.cp(root.player && root.player.isPlaying ? 0xF03E4 : 0xF040A) : root.cp(ctl.modelData.g)
                            color: cm.containsMouse ? main.accent : main.text
                            font { family: root.iconFont; pixelSize: ctl.modelData.act === "toggle" ? 18 : 14 }
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.player) return;
                                if (ctl.modelData.act === "prev") root.player.previous();
                                else if (ctl.modelData.act === "next") root.player.next();
                                else root.player.togglePlaying();
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ right: status
    Item {
        id: right
        width: 160; x: parent.width - width - 20; y: 16; height: parent.height - 32

        Text { text: "Status"; color: main.text; font { family: main.font; pixelSize: 12; weight: 700 } }
        Rectangle {
            id: ccBtn
            width: 24; height: 24; radius: 12; x: parent.width - width; y: -4
            color: ccm.containsMouse ? main.accent : root.faint
            Behavior on color { ColorAnimation { duration: main.ms(150) } }
            Text {
                anchors.centerIn: parent; text: root.cp(0xF0570)
                color: ccm.containsMouse ? main.onAccent : main.text
                font { family: root.iconFont; pixelSize: 13 }
            }
            MouseArea {
                id: ccm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.isl.openMenu("quick", root.cp(0xF0570), "")
            }
        }
        Column {
            y: 22; spacing: 3; width: parent.width
            StatusRow {
                width: right.width
                glyph: root.isl.charging ? root.cp(0xF0084) : root.cp(0xF0079)
                text1: root.isl.hasBattery ? root.isl.level + "%" : "AC"
                text2: !root.isl.hasBattery ? "" : (root.isl.charging ? "plugged in" : "on battery")
            }
            StatusRow {
                width: right.width
                glyph: root.cp(0xF05A9)
                text1: root.isl.wifiNet ? root.isl.wifiNet.name : "Wi-Fi off"
                text2: root.isl.wifiNet ? Math.round(root.isl.wifiNet.signalStrength * 100) + "%" : ""
                dim: !root.isl.wifiNet
            }
            StatusRow {
                width: right.width
                glyph: root.cp(root.adapter && root.adapter.enabled ? 0xF00AF : 0xF00B2)
                text1: !root.adapter || !root.adapter.enabled ? "Bluetooth off" : (root.btDevs.length > 0 ? root.btDevs[0].name : "Bluetooth on")
                dim: !root.adapter || !root.adapter.enabled
            }
            StatusRow {
                width: right.width
                glyph: root.isl.muted ? root.cp(0xF0581) : root.cp(0xF057E)
                text1: root.isl.muted ? "Muted" : root.isl.volPct + "%"
                text2: "output"
                dim: root.isl.muted
            }
            StatusRow {
                width: right.width
                glyph: root.cp(root.nf && root.nf.dnd ? 0xF009B : 0xF009A)
                text1: root.nf && root.nf.dnd ? "Quiet" : (root.nf && root.nf.history.length > 0 ? root.nf.history.length + " notifications" : "No notifications")
                dim: !root.nf || root.nf.history.length === 0
            }
        }
        Row {
            anchors.bottom: parent.bottom; spacing: 6
            Repeater {
                model: [
                    { "label": "Night", "g": 0xF0594, "key": "night" },
                    { "label": "Game", "g": 0xF0297, "key": "game" }
                ]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: modelData.key === "night" ? root.tog.nightOn : root.tog.gameOn
                    height: 22; width: 77; radius: 11
                    color: on ? main.accent : (cmo.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.14) : root.faint)
                    Behavior on color { ColorAnimation { duration: main.ms(150) } }
                    Row {
                        id: cl; anchors.centerIn: parent; spacing: 4
                        Text { id: gl; text: root.cp(chip.modelData.g); color: chip.on ? main.onAccent : main.text; font { family: root.iconFont; pixelSize: 10 } anchors.verticalCenter: parent.verticalCenter }
                        Text { id: lb; text: chip.modelData.label; color: chip.on ? main.onAccent : main.text; font { family: main.font; pixelSize: 10; weight: 600 } anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: cmo
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: chip.modelData.key === "night" ? root.tog.toggleNight() : root.tog.toggleGame()
                    }
                }
            }
        }
    }
}
