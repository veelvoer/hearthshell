// qmllint disable
import QtQuick

// A cheap soft shadow: a few stacked, slightly bigger rounded rectangles. (A blurred shadow effect on a shape that
// resizes every frame is expensive and made the island stutter.) Sit it behind the shape and bind its geometry to it.
Item {
    id: root
    property real radius: 12
    property real strength: 0.34
    property real offsetY: 3
    property int steps: 6
    Repeater {
        model: root.steps
        Rectangle {
            required property int index
            readonly property real grow: (index + 1) * 2.4
            x: -grow; y: root.offsetY - grow + 1
            width: root.width + grow * 2; height: root.height + grow * 2
            radius: root.radius + grow
            color: Qt.rgba(0, 0, 0, root.strength / root.steps * (1 - index / (root.steps + 1)))
        }
    }
}
