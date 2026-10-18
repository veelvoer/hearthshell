// qmllint disable
import QtQuick
import QtQuick.Effects

// A fat pill-shaped slider: the filled part carries the icon, the value sits on the right.
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    property string glyph: ""
    property string valueText: ""
    property bool showChevron: false
    signal moved(real value)
    signal chevronClicked()
    readonly property bool pressed: area.pressed
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    implicitWidth: 300
    implicitHeight: 54

    Rectangle {
        id: track
        anchors.fill: parent; radius: height / 2
        color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
        border.width: 1; border.color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.06)
    }
    Rectangle {
        id: fill
        height: parent.height; radius: height / 2
        width: Math.max(height, root.frac * root.width)
        color: main.accent
        Behavior on width { enabled: !root.pressed; NumberAnimation { duration: main.ms(220); easing.type: Easing.OutCubic } }
        Text {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            text: root.glyph; color: main.bg
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 20 }
        }
    }
    Text {
        anchors { right: parent.right; rightMargin: root.showChevron ? 46 : 18; verticalCenter: parent.verticalCenter }
        text: root.valueText; color: root.frac > 0.86 ? main.bg : main.muted
        font { family: main.font; pixelSize: 12; weight: 600 }
    }
    Rectangle {
        visible: root.showChevron
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        width: 30; height: 30; radius: 15
        color: cm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.14) : "transparent"
        Text { anchors.centerIn: parent; text: "›"; color: main.text; font { pixelSize: 22; weight: 600 } }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chevronClicked() }
    }
    MouseArea {
        id: area
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        function set(mx) { root.moved(root.from + Math.max(0, Math.min(1, mx / root.width)) * (root.to - root.from)); }
        onPressed: mouse => { if (!(root.showChevron && mouse.x > root.width - 46)) set(mouse.x); }
        onPositionChanged: mouse => { if (pressed) set(mouse.x); }
    }
}
