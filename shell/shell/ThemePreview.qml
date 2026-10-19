// qmllint disable
import QtQuick

// Miniature desktop (bar + terminal) drawn in a draft theme's colours.
Rectangle {
    id: root
    property color bg: "#222"
    property color text: "#eee"
    property color accent: "#8f8"
    property color accent2: "#88f"
    property color muted: "#555"
    implicitWidth: 260; implicitHeight: 150
    radius: 14; color: Qt.darker(bg, 1.4)
    border.width: 1; border.color: main.line
    Behavior on color { ColorAnimation { duration: main.ms(200) } }

    Rectangle {   // bar
        x: 10; y: 10; width: parent.width - 20; height: 18; radius: 9; color: root.bg
        border.width: 1; border.color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.16)
        Row {
            x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            Repeater {
                model: 4
                Rectangle { required property int index; width: 10; height: 8; radius: 3
                    color: index === 1 ? root.accent : root.muted }
            }
        }
        Rectangle { anchors.centerIn: parent; width: 22; height: 4; radius: 2; color: root.text }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            Rectangle { width: 8; height: 8; radius: 4; color: root.accent2 }
            Rectangle { width: 8; height: 8; radius: 4; color: root.accent }
        }
    }
    Rectangle {   // terminal
        x: 10; y: 38; width: parent.width - 20; height: parent.height - 48; radius: 10; color: root.bg
        border.width: 2; border.color: root.accent
        Column {
            x: 12; y: 12; spacing: 7
            Row { spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 70; height: 5; radius: 2; color: root.text }
                Rectangle { width: 30; height: 5; radius: 2; color: root.accent2 }
            }
            Rectangle { width: 120; height: 5; radius: 2; color: root.muted }
            Rectangle { width: 90; height: 5; radius: 2; color: root.text; opacity: 0.8 }
            Rectangle { width: 54; height: 5; radius: 2; color: root.accent }
        }
    }
}
