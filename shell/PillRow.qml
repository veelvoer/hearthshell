import QtQuick

// A round row in the menus: icon, title, optional subtitle, and it lights up when switched on.
Item {
    id: root
    property string glyph: ""
    property string title: ""
    property string sub: ""
    property bool checked: false
    property bool interactive: true
    signal clicked()
    height: 48
    Rectangle {
        anchors.fill: parent; radius: height / 2
        color: root.checked ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.92) : (m.containsMouse && root.interactive ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.12) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07))
        Behavior on color { ColorAnimation { duration: main.ms(180) } }
    }
    Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: root.glyph; color: root.checked ? main.bg : main.text
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 } }
    Column {
        x: 50; width: parent.width - 66; anchors.verticalCenter: parent.verticalCenter
        Text { width: parent.width; elide: Text.ElideRight; text: root.title; color: root.checked ? main.bg : main.text; font { family: main.font; pixelSize: 13; weight: 700 } }
        Text { width: parent.width; elide: Text.ElideRight; visible: root.sub !== ""; text: root.sub; color: root.checked ? Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.72) : main.muted; font { family: main.font; pixelSize: 11 } }
    }
    MouseArea { id: m; anchors.fill: parent; enabled: root.interactive; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
