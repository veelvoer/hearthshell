// qmllint disable
import QtQuick

// The little rounded square with an icon in it, used at the start of every settings row (iOS-style).
Rectangle {
    id: root
    property string glyph: ""
    property real size: 30
    property color tint: main.accent
    property bool round: false
    property bool filled: false
    width: size; height: size; radius: round ? size / 2 : size * 0.3
    color: filled ? tint : Qt.rgba(tint.r, tint.g, tint.b, 0.16)
    Behavior on color { ColorAnimation { duration: main.ms(180) } }
    Text {
        anchors.centerIn: parent; text: root.glyph; color: root.filled ? main.onAccent : root.tint
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: root.size * 0.55 }
    }
}
