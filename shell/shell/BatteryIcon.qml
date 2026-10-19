// qmllint disable
import QtQuick

// A drawn battery: outline, rounded fill that follows the level, a nub, and a bolt while charging.
Item {
    id: root
    property real level: 100            // 0..100
    property bool charging: false
    property color tint: main.icon
    property color lowTint: "#ff002f"
    property real size: main.barPx
    implicitWidth: size * 1.55
    implicitHeight: size * 0.8
    readonly property color fillColor: charging ? tint : (level <= 15 ? lowTint : (level <= 30 ? "#f97316" : tint))

    Rectangle {
        id: body
        width: parent.width - root.size * 0.12; height: parent.height
        radius: height * 0.34
        color: "transparent"; border.width: Math.max(1.5, root.size * 0.1); border.color: Qt.alpha(root.fillColor, 0.55)
        Rectangle {
            x: body.border.width + 1.5; y: body.border.width + 1.5
            height: parent.height - 2 * (body.border.width + 1.5)
            width: Math.max(height, (parent.width - 2 * (body.border.width + 1.5)) * Math.max(0, Math.min(100, root.level)) / 100)
            radius: height * 0.3
            color: root.fillColor
            Behavior on width { NumberAnimation { duration: main.ms(500); easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: main.ms(300) } }
        }
        Text {
            visible: root.charging; anchors.centerIn: parent; text: "󱐋"
            color: main.bg; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: root.size * 0.62 }
        }
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right
        width: root.size * 0.12; height: root.size * 0.28; radius: width / 2
        color: Qt.alpha(root.fillColor, 0.55)
    }
}
