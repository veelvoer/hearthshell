// qmllint disable
import QtQuick

// Hearth-style switch: pill track, sliding knob.
Item {
    id: root
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 44; implicitHeight: 26

    Rectangle {
        anchors.fill: parent; radius: height / 2
        color: root.checked ? main.accent : main.line
        Behavior on color { ColorAnimation { duration: main.ms(200) } }
        border.width: 1; border.color: root.checked ? main.accent : main.line
    }
    Rectangle {
        id: knob
        width: 20; height: 20; radius: 10; y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? main.onAccent : main.text
        scale: mouse.pressed ? 1.12 : 1
        Behavior on x { NumberAnimation { duration: main.ms(240); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
        Behavior on scale { NumberAnimation { duration: main.ms(120); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: main.ms(200) } }
    }
    MouseArea { id: mouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
}
