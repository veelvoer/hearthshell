// qmllint disable
import QtQuick

// One-click "look": name, one line of description.
Item {
    id: card
    property string name: ""
    property string desc: ""
    signal picked()
    implicitWidth: 150; implicitHeight: 64

    Item {
        anchors.fill: parent
        scale: m.pressed ? 0.96 : 1
        y: m.containsMouse ? -2 : 0
        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
        Behavior on y { NumberAnimation { duration: main.ms(180); easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent; radius: 14; color: main.page
            border.width: 1; border.color: m.containsMouse ? main.accent : main.line
            Behavior on border.color { ColorAnimation { duration: main.ms(180) } }
            Column {
                x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24; spacing: 2
                Text { text: card.name; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
                Text { width: parent.width; text: card.desc; color: main.muted; elide: Text.ElideRight
                    font { family: main.font; pixelSize: 11 } }
            }
        }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.picked() }
}
