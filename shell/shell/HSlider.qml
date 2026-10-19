// qmllint disable
import QtQuick

Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    signal moved(real value)
    readonly property bool pressed: drag.pressed
    implicitWidth: 200; implicitHeight: 26
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))

    Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: main.line }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter; height: 6; radius: 3; color: main.accent
        width: handle.x + handle.width / 2
    }
    Rectangle {
        id: handle
        width: 18; height: 18; radius: 9; anchors.verticalCenter: parent.verticalCenter
        x: root.frac * (root.width - width)
        color: main.text; border.width: 3; border.color: main.accent
        scale: drag.pressed ? 1.15 : (drag.containsMouse ? 1.08 : 1)
        Behavior on scale { NumberAnimation { duration: main.ms(140); easing.type: Easing.OutBack } }
    }
    MouseArea {
        id: drag
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        function set(mx) {
            const f = Math.max(0, Math.min(1, (mx - handle.width / 2) / (root.width - handle.width)));
            root.moved(root.from + f * (root.to - root.from));
        }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x) }
    }
}
