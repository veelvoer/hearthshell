// qmllint disable
import QtQuick

// Round "back" arrow in the top-left of a menu opened from the quick settings menu.
Item {
    id: root
    signal clicked()
    width: 34; height: 34
    scale: area.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: main.ms(150); easing.type: Easing.OutBack } }
    Rectangle {
        anchors.fill: parent; radius: width / 2
        color: area.containsMouse ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.22) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
        Behavior on color { ColorAnimation { duration: main.ms(150) } }
    }
    Text {
        anchors.centerIn: parent; text: String.fromCodePoint(0xF004D); color: main.accent
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
