// qmllint disable
import QtQuick

// Wi-Fi strength as four little bars (the Dynamite look). level 0..4, off = dimmed with a slash.
Item {
    id: root
    property int level: 0
    property bool off: false
    property color tint: main.icon
    property real size: main.barPx
    implicitWidth: size * 0.95
    implicitHeight: size
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Math.max(1, root.size * 0.09)
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: Math.max(2, root.size * 0.16)
                height: root.size * (0.34 + index * 0.22)
                radius: width / 2
                anchors.bottom: parent.bottom
                color: root.tint
                opacity: root.off ? 0.25 : (index < root.level ? 1 : 0.28)
                Behavior on opacity { NumberAnimation { duration: main.ms(240) } }
            }
        }
    }
}
