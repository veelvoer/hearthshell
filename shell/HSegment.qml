// qmllint disable
import QtQuick

// Segmented choice with a sliding highlight.
Rectangle {
    id: root
    property var options: []
    property int current: 0
    property real segWidth: 64
    signal picked(int index)
    implicitWidth: options.length * segWidth + 6; implicitHeight: 34
    radius: 12; color: main.page; border.width: 1; border.color: main.line

    Rectangle {
        y: 3; height: parent.height - 6; width: root.segWidth; radius: 9; color: main.accent
        x: 3 + root.current * root.segWidth
        Behavior on x { NumberAnimation { duration: main.ms(300); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
    }
    Repeater {
        model: root.options
        Item {
            required property int index
            required property string modelData
            x: 3 + index * root.segWidth; y: 0; width: root.segWidth; height: root.height
            Text {
                anchors.centerIn: parent; text: modelData
                color: root.current === index ? main.onAccent : (m.containsMouse ? main.text : main.muted)
                Behavior on color { ColorAnimation { duration: main.ms(180) } }
                font { family: main.font; pixelSize: 12; weight: 600 }
            }
            MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(index) }
        }
    }
}
