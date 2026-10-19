// qmllint disable
import QtQuick

// The little rounded square with an icon in it, used at the start of every settings row (iOS-style).
Rectangle {
    id: root
    property string glyph: ""
    property real size: 30
    property color tint: main.accent
    width: size; height: size; radius: size * 0.3
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.16)
    Text {
        anchors.centerIn: parent; text: root.glyph; color: root.tint
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: root.size * 0.55 }
    }
}
