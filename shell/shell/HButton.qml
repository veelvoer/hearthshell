// qmllint disable
import QtQuick

// primary = filled accent, otherwise ghost outline.
Rectangle {
    id: root
    property string label: ""
    property bool primary: false
    property real padX: 18
    signal clicked()
    implicitWidth: txt.implicitWidth + padX * 2; implicitHeight: 36
    radius: 12
    color: primary ? (mouse.containsMouse ? Qt.lighter(main.accent, 1.1) : main.accent)
                   : (mouse.containsMouse ? main.line : "transparent")
    border.width: 1
    border.color: primary ? "transparent" : (mouse.containsMouse ? main.accent : main.line)
    scale: mouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: main.ms(160); easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: main.ms(160) } }
    Behavior on border.color { ColorAnimation { duration: main.ms(160) } }

    Text {
        id: txt; anchors.centerIn: parent; text: root.label
        color: root.primary ? main.onAccent : main.text
        font { family: main.font; pixelSize: 13; weight: 600 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
