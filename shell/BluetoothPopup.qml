// qmllint disable
import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Bluetooth menu: adapter switch, discovery, paired and nearby devices.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    property var expanded: null
    readonly property bool typing: false

    readonly property var adapter: Bluetooth.defaultAdapter
    property var devs: []
    readonly property real wantedWidth: shell ? shell.menuWidth("bluetooth") : 360
    readonly property real wantedHeight: 64 + body.implicitHeight + 16

    // nameless devices show up as their MAC address; keep them out of the list
    readonly property var macLike: /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/

    function resort() {
        if (expanded) return;
        const v = adapter ? adapter.devices.values.filter(d => d.name && d.name !== "" && (d.paired || d.connected || !macLike.test(d.name))).slice() : [];
        v.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
        if (v.length === devs.length && v.every((x, i) => x === devs[i])) return;
        devs = v;
    }
    onActiveChanged: if (!active) expanded = null
    onSettledChanged: if (adapter && adapter.enabled) adapter.discovering = settled
    Component.onCompleted: resort()
    Component.onDestruction: if (adapter) adapter.discovering = false
    Connections { target: root.adapter ? root.adapter.devices : null; function onValuesChanged() { root.resort(); } }
    Connections { target: root.adapter; function onEnabledChanged() { if (root.adapter.enabled && root.settled) root.adapter.discovering = true; } }
    Timer { interval: 3000; running: root.active; repeat: true; onTriggered: root.resort() }

    function glyph(icon) {
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0) return String.fromCodePoint(0xF02CB);
        if (icon.indexOf("audio") >= 0) return String.fromCodePoint(0xF04C3);
        if (icon.indexOf("keyboard") >= 0) return String.fromCodePoint(0xF030C);
        if (icon.indexOf("mouse") >= 0) return String.fromCodePoint(0xF037D);
        if (icon.indexOf("gaming") >= 0 || icon.indexOf("joystick") >= 0) return String.fromCodePoint(0xF0297);
        if (icon.indexOf("phone") >= 0) return String.fromCodePoint(0xF011C);
        if (icon.indexOf("computer") >= 0) return String.fromCodePoint(0xF0379);
        return String.fromCodePoint(0xF00AF);
    }

    Text {
        x: 54; y: 15; text: "Bluetooth"; color: main.text
        font { family: main.serif; pixelSize: 18 }
    }
    HToggle {
        x: parent.width - width - 18; y: 18
        visible: !!root.adapter
        checked: !!root.adapter && root.adapter.enabled
        onToggled: v => { if (root.adapter) root.adapter.enabled = v; }
    }

    Flickable {
        x: 0; y: 60; width: parent.width; height: parent.height - 60
        contentWidth: width; contentHeight: body.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: body
            x: 12; width: parent.width - 24; spacing: 6

            Row {
                visible: !!root.adapter && root.adapter.enabled
                width: parent.width; height: visible ? 24 : 0
                Text {
                    width: parent.width - scanLabel.width - 6; leftPadding: 6; anchors.verticalCenter: parent.verticalCenter
                    text: "DEVICES"; color: main.muted
                    font { family: main.font; pixelSize: 11; weight: 700; letterSpacing: 1.2 }
                }
                Text {
                    id: scanLabel; anchors.verticalCenter: parent.verticalCenter
                    text: root.adapter && root.adapter.discovering ? "Scanning…" : "Idle"
                    color: root.adapter && root.adapter.discovering ? main.accent : main.muted
                    font { family: main.font; pixelSize: 11; weight: 600 }
                    SequentialAnimation on opacity {
                        running: !!root.adapter && root.adapter.discovering; loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: main.ms(700) } NumberAnimation { to: 1; duration: main.ms(700) }
                    }
                }
            }
            Text {
                visible: !root.adapter
                width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 18; bottomPadding: 18
                color: main.muted; text: "No Bluetooth adapter found."; font { family: main.font; pixelSize: 13 }
            }
            Text {
                visible: !!root.adapter && !root.adapter.enabled
                width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 18; bottomPadding: 18
                color: main.muted; text: "Bluetooth is turned off."; font { family: main.font; pixelSize: 13 }
            }
            Text {
                visible: !!root.adapter && root.adapter.enabled && root.devs.length === 0
                width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 18; bottomPadding: 18
                color: main.muted; text: "Looking for devices…"; font { family: main.font; pixelSize: 13 }
            }
            Repeater {
                model: root.adapter && root.adapter.enabled ? root.devs : []
                DevRow { }
            }
        }
    }

    component DevRow: Item {
        id: row
        required property var modelData
        readonly property var dev: modelData
        readonly property bool open: root.expanded === dev
        property bool wantConnect: false
        width: parent ? parent.width : 300
        height: 54 + (open ? 40 : 0)
        clip: true
        Behavior on height { NumberAnimation { duration: main.ms(280); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }

        // after a fresh pairing, finish by connecting
        Connections { target: row.dev; function onPairedChanged() { if (row.wantConnect && row.dev.paired && !row.dev.connected) { row.dev.connect(); row.wantConnect = false; } } }

        Rectangle {
            anchors.fill: parent; radius: 14
            color: row.dev.connected ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.14)
                   : (hit.containsMouse || row.open ? main.card : "transparent")
            border.width: row.dev.connected ? 1 : 0
            border.color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.5)
            Behavior on color { ColorAnimation { duration: main.ms(160) } }
        }
        Text { x: 16; y: 13; text: root.glyph(row.dev.icon || ""); color: row.dev.connected ? main.accent : main.text
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 } }
        Column {
            x: 52; y: 9; spacing: 1; width: parent.width - 52 - 52
            Text { width: parent.width; elide: Text.ElideRight; text: row.dev.name; color: main.text
                font { family: main.font; pixelSize: 14; weight: 600 } }
            Text {
                color: row.dev.connected ? main.accent : main.muted
                font { family: main.font; pixelSize: 12 }
                text: row.dev.pairing ? "Pairing…"
                      : row.dev.connected ? "Connected" + (row.dev.batteryAvailable ? "  ·  " + Math.round(row.dev.battery * 100) + "%" : "")
                      : row.dev.paired ? "Paired" : "Available"
            }
        }
        Item {
            x: parent.width - 34; y: 17; width: 20; height: 20
            Rectangle {
                anchors.fill: parent; radius: 10; color: "transparent"; border.width: 2; border.color: main.line
                visible: row.dev.pairing
                Rectangle { width: 6; height: 6; radius: 3; color: main.accent; x: 7; y: -1 }
                RotationAnimator on rotation { from: 0; to: 360; duration: main.ms(900); loops: Animation.Infinite; running: row.dev.pairing }
            }
            Text { visible: row.dev.connected && !row.dev.pairing; anchors.centerIn: parent; text: "✓"
                color: main.accent; font { pixelSize: 16; bold: true } }
        }
        MouseArea {
            id: hit
            x: 0; y: 0; width: parent.width; height: 54
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) { root.expanded = row.open ? null : row.dev; return; }
                if (row.dev.connected) row.dev.disconnect();
                else if (row.dev.paired) row.dev.connect();
                else { row.wantConnect = true; row.dev.pair(); }
            }
        }
        Row {
            x: 12; y: 54; spacing: 8; opacity: row.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: main.ms(200) } }
            HButton { visible: !row.dev.connected; label: "Connect"; primary: true
                onClicked: { if (row.dev.paired) row.dev.connect(); else { row.wantConnect = true; row.dev.pair(); } } }
            HButton { visible: row.dev.connected; label: "Disconnect"; onClicked: row.dev.disconnect() }
            HButton { visible: row.dev.paired; label: "Forget"; onClicked: { row.dev.forget(); root.expanded = null; } }
        }
    }
}
