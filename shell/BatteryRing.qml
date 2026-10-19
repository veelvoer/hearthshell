// qmllint disable
import QtQuick
import QtQuick.Shapes

// A ring that fills with the battery level, drawn around whatever sits in the middle.
Item {
    id: root
    property real level: 100            // 0..100
    property bool charging: false
    property bool present: true
    property color tint: main.accent
    property real stroke: 2
    readonly property color ringColor: charging ? "#6ee7a0" : (level <= 15 ? "#ff3b30" : (level <= 30 ? "#f97316" : tint))
    readonly property real r: Math.min(width, height) / 2 - stroke / 2
    visible: present
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(root.ringColor, 0.22); strokeWidth: root.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r; radiusY: root.r; startAngle: -90; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.ringColor; strokeWidth: root.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r; radiusY: root.r; startAngle: -90
                sweepAngle: Math.max(6, 360 * Math.max(0, Math.min(100, root.level)) / 100)
                Behavior on sweepAngle { NumberAnimation { duration: main.ms(600); easing.type: Easing.OutCubic } }
            }
        }
    }
}
