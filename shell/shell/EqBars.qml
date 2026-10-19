// qmllint disable
import QtQuick

// Little equaliser: bars that dance while `running`, and rest low when paused.
Item {
    id: root
    property bool running: false
    property color tint: main.accent
    property real size: 14
    implicitWidth: size
    implicitHeight: size
    Row {
        anchors.centerIn: parent
        spacing: Math.max(1, root.size * 0.12)
        Repeater {
            model: 4
            Rectangle {
                id: bar
                required property int index
                width: Math.max(2, root.size * 0.16); radius: width / 2; color: root.tint
                anchors.bottom: parent.bottom
                height: root.size * 0.28
                SequentialAnimation on height {
                    running: root.running && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: root.size * (0.55 + 0.4 * ((bar.index * 37) % 5) / 4); duration: 260 + bar.index * 70; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.size * 0.22; duration: 300 + bar.index * 55; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.size * (0.7 - 0.12 * bar.index / 3); duration: 240 + bar.index * 60; easing.type: Easing.InOutSine }
                }
                Behavior on height { enabled: !root.running; NumberAnimation { duration: main.ms(300); easing.type: Easing.OutCubic } }
            }
        }
    }
}
