// qmllint disable
import Quickshell
import Quickshell.Networking
import QtQuick

// Wi-Fi menu: ethernet status, saved and nearby networks, inline password entry.
Item {
    id: root
    property bool active: false             // this menu is the open one
    property bool settled: false            // the morph has finished: safe to do heavier work
    property var expanded: null
    property bool typing: false

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired)
    property var nets: []
    readonly property real wantedHeight: 64 + body.implicitHeight + 16

    function resort() {
        if (expanded) return;   // never shuffle rows under someone who is typing a password
        const v = wifi ? wifi.networks.values.slice() : [];
        v.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
        // only rebuild the rows when the order actually changed
        if (v.length === nets.length && v.every((x, i) => x === nets[i])) return;
        nets = v;
    }
    onActiveChanged: if (!active) expanded = null
    onSettledChanged: if (wifi) wifi.scannerEnabled = settled
    Component.onCompleted: resort()
    Component.onDestruction: if (wifi) wifi.scannerEnabled = false
    Connections { target: root.wifi ? root.wifi.networks : null; function onValuesChanged() { root.resort(); } }
    Timer { interval: 3500; running: root.active; repeat: true; onTriggered: root.resort() }

    function glyph(net) {
        const s = net.signalStrength;
        const tier = s >= 0.75 ? 3 : s >= 0.5 ? 2 : s >= 0.25 ? 1 : 0;
        return String.fromCodePoint(0xF091F + tier * 3 + (net.security !== WifiSecurityType.Open ? 1 : 0));
    }

    // ---- header ----
    Text {
        x: 54; y: 15; text: "Wi-Fi"; color: main.text
        font { family: main.serif; pixelSize: 18 }
    }
    HToggle {
        x: parent.width - width - 18; y: 18
        checked: Networking.wifiEnabled
        onToggled: v => Networking.wifiEnabled = v
    }

    Flickable {
        id: flick
        x: 0; y: 60; width: parent.width; height: parent.height - 60
        contentWidth: width; contentHeight: body.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: body
            x: 12; width: parent.width - 24; spacing: 6

            // ethernet
            Item {
                visible: !!root.wired
                width: parent.width; height: visible ? 54 : 0
                Rectangle { anchors.fill: parent; radius: 14; color: main.card
                    border.width: 1; border.color: root.wired && root.wired.connected ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.5) : main.line }
                Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(0xF0200)
                    color: root.wired && root.wired.connected ? main.accent : main.muted
                    font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 } }
                Column {
                    x: 52; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Text { text: "Ethernet"; color: main.text; font { family: main.font; pixelSize: 14; weight: 600 } }
                    Text {
                        color: main.muted; font { family: main.font; pixelSize: 12 }
                        text: !root.wired ? "" : root.wired.connected
                              ? "Connected" + (root.wired.linkSpeed > 0 ? "  ·  " + root.wired.linkSpeed + " Mb/s" : "")
                              : (root.wired.hasLink === false ? "Cable unplugged" : "Not connected")
                    }
                }
            }

            Text {
                visible: !!root.wifi && Networking.wifiEnabled
                text: "NETWORKS"; color: main.muted; leftPadding: 6; topPadding: 4
                font { family: main.font; pixelSize: 11; weight: 700; letterSpacing: 1.2 }
            }
            Text {
                visible: !!root.wifi && !Networking.wifiEnabled
                width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                topPadding: 18; bottomPadding: 18; color: main.muted
                text: "Wi-Fi is turned off."
                font { family: main.font; pixelSize: 13 }
            }
            Text {
                visible: !root.wifi
                width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 18; bottomPadding: 18
                color: main.muted; text: "No Wi-Fi adapter found."
                font { family: main.font; pixelSize: 13 }
            }
            Text {
                visible: !!root.wifi && Networking.wifiEnabled && root.nets.length === 0
                width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 18; bottomPadding: 18
                color: main.muted; text: "Looking for networks…"
                font { family: main.font; pixelSize: 13 }
            }

            Repeater {
                model: Networking.wifiEnabled ? root.nets : []
                NetRow { }
            }
        }
    }

    component NetRow: Item {
        id: row
        required property var modelData
        readonly property var net: modelData
        readonly property bool open: root.expanded === net
        readonly property bool secured: net.security !== WifiSecurityType.Open
        readonly property bool needsPsk: secured && !net.known
        property string failed: ""
        width: parent ? parent.width : 300
        height: 54 + (open ? extra.height + 6 : 0)
        clip: true
        Behavior on height { NumberAnimation { duration: main.ms(280); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }

        Connections {
            target: row.net
            function onConnectionFailed(reason) {
                row.failed = reason === ConnectionFailReason.NoSecrets ? "A password is needed" : "Could not connect";
                if (row.secured) root.expanded = row.net;
            }
            function onConnectedChanged() { if (row.net.connected) row.failed = ""; }
        }

        Rectangle {
            anchors.fill: parent; radius: 14
            color: row.net.connected ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.14)
                   : (hit.containsMouse || row.open ? main.card : "transparent")
            border.width: row.net.connected ? 1 : 0
            border.color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.5)
            Behavior on color { ColorAnimation { duration: main.ms(160) } }
        }
        Text {
            x: 16; y: 14; text: root.glyph(row.net)
            color: row.net.connected ? main.accent : main.text
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 }
        }
        Column {
            x: 52; y: 9; spacing: 1; width: parent.width - 52 - 52
            Text { width: parent.width; elide: Text.ElideRight; text: row.net.name; color: main.text
                font { family: main.font; pixelSize: 14; weight: 600 } }
            Text {
                color: row.failed !== "" ? main.red : (row.net.connected ? main.accent : main.muted)
                font { family: main.font; pixelSize: 12 }
                text: row.failed !== "" ? row.failed
                      : row.net.stateChanging ? "Connecting…"
                      : row.net.connected ? "Connected"
                      : row.net.known ? "Saved" : (row.secured ? "Secured" : "Open")
            }
        }
        // spinner while connecting, tick when connected
        Item {
            x: parent.width - 34; y: 17; width: 20; height: 20
            Rectangle {
                anchors.fill: parent; radius: 10; color: "transparent"; border.width: 2; border.color: main.line
                visible: row.net.stateChanging
                Rectangle { width: 6; height: 6; radius: 3; color: main.accent; x: 7; y: -1 }
                RotationAnimator on rotation { from: 0; to: 360; duration: main.ms(900); loops: Animation.Infinite; running: row.net.stateChanging }
            }
            Text { visible: row.net.connected && !row.net.stateChanging; anchors.centerIn: parent; text: "✓"
                color: main.accent; font { pixelSize: 16; bold: true } }
        }
        MouseArea {
            id: hit
            x: 0; y: 0; width: parent.width; height: 54
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton || row.net.connected || row.needsPsk) {
                    root.expanded = row.open ? null : row.net;
                    if (row.open === false) row.failed = "";
                } else {
                    row.failed = "";
                    row.net.connect();
                }
            }
        }

        Item {
            id: extra
            x: 12; y: 54; width: parent.width - 24
            height: row.needsPsk ? 40 : 34
            opacity: row.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: main.ms(200) } }

            // password entry for secured networks we have no profile for
            Row {
                visible: row.needsPsk; spacing: 8; width: parent.width
                HInput {
                    id: pw
                    width: parent.width - 8 - 86; placeholder: "Password"; echoMode: TextInput.Password
                    onTypingChanged: root.typing = typing
                    onSubmitted: v => { if (v.length > 0) { row.failed = ""; row.net.connectWithPsk(v); } }
                }
                HButton { label: "Connect"; primary: true
                    onClicked: { if (pw.text.length > 0) { row.failed = ""; row.net.connectWithPsk(pw.text); } } }
            }
            Row {
                visible: !row.needsPsk; spacing: 8
                HButton { visible: !row.net.connected; label: "Connect"; primary: true; onClicked: { row.failed = ""; row.net.connect(); } }
                HButton { visible: row.net.connected; label: "Disconnect"; onClicked: row.net.disconnect() }
                HButton { visible: row.net.known; label: "Forget"; onClicked: { row.net.forget(); root.expanded = null; } }
            }
        }
        onOpenChanged: if (open && needsPsk) pw.focusInput()
    }
}
