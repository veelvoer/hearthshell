// qmllint disable
import QtQuick

// Hue / saturation / value picker made of three gradient tracks.
Item {
    id: root
    property color value: "#ffffff"
    signal picked(color c)

    property real h: 0
    property real s: 0
    property real v: 1
    property bool dragging: false
    implicitWidth: 320; implicitHeight: 3 * 26

    function sync() {
        if (dragging) return;
        if (value.hsvHue >= 0) h = value.hsvHue;
        s = value.hsvSaturation;
        v = value.hsvValue;
    }
    onValueChanged: sync()
    Component.onCompleted: sync()
    function emit() { root.picked(Qt.hsva(h, s, v, 1)); }

    component Track: Item {
        id: track
        property real pos: 0
        property color c0: "black"
        property color c1: "white"
        property bool rainbow: false
        signal moved(real p)
        width: root.width; height: 18

        Rectangle {
            anchors.fill: parent; radius: 9; visible: !track.rainbow
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: track.c0 }
                GradientStop { position: 1; color: track.c1 }
            }
        }
        Rectangle {
            anchors.fill: parent; radius: 9; visible: track.rainbow
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.000; color: "#ff0000" }
                GradientStop { position: 0.167; color: "#ffff00" }
                GradientStop { position: 0.333; color: "#00ff00" }
                GradientStop { position: 0.500; color: "#00ffff" }
                GradientStop { position: 0.667; color: "#0000ff" }
                GradientStop { position: 0.833; color: "#ff00ff" }
                GradientStop { position: 1.000; color: "#ff0000" }
            }
        }
        Rectangle {
            width: 20; height: 20; radius: 10; anchors.verticalCenter: parent.verticalCenter
            x: track.pos * (track.width - width)
            color: Qt.hsva(root.h, root.s, root.v, 1)
            border.width: 3; border.color: "white"
            scale: m.pressed ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: main.ms(140); easing.type: Easing.OutBack } }
        }
        MouseArea {
            id: m; anchors.fill: parent; preventStealing: true; cursorShape: Qt.PointingHandCursor
            function set(mx) { track.moved(Math.max(0, Math.min(1, (mx - 10) / (track.width - 20)))); }
            onPressed: mouse => { root.dragging = true; set(mouse.x); }
            onPositionChanged: mouse => { if (pressed) set(mouse.x); }
            onReleased: root.dragging = false
        }
    }

    Column {
        spacing: 8
        Track { rainbow: true; pos: root.h; onMoved: p => { root.h = p >= 1 ? 0.999 : p; root.emit(); } }
        Track { c0: Qt.hsva(root.h, 0, root.v, 1); c1: Qt.hsva(root.h, 1, root.v, 1); pos: root.s
            onMoved: p => { root.s = p; root.emit(); } }
        Track { c0: "black"; c1: Qt.hsva(root.h, root.s, 1, 1); pos: root.v
            onMoved: p => { root.v = p; root.emit(); } }
    }
}
