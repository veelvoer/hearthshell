import QtQuick

// A group of options in the Customize panel: a title you can click to open or close it.
Item {
    id: root
    property string title: ""
    property bool expanded: false
    default property alias content: body.data
    signal toggled()
    width: parent ? parent.width : 300
    height: head.height + (expanded ? body.height + 10 : 0)
    clip: true
    Behavior on height { NumberAnimation { duration: main.ms(220); easing.type: Easing.OutCubic } }

    Rectangle {
        id: head
        width: parent.width; height: 40; radius: 14
        color: hm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.04)
        Behavior on color { ColorAnimation { duration: main.ms(120) } }
        Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: root.title; color: main.text; font { family: main.font; pixelSize: 13; weight: 700 } }
        Text {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: String.fromCodePoint(0xF0142); color: main.muted; rotation: root.expanded ? 90 : 0
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 16 }
            Behavior on rotation { NumberAnimation { duration: main.ms(200); easing.type: Easing.OutCubic } }
        }
        MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
    }
    Item { id: body; x: 4; y: head.height + 8; width: parent.width - 8; height: childrenRect.height }
}
