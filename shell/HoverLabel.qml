// qmllint disable
import QtQuick
import QtQuick.Layouts

// Text next to a bar icon. With "Show text only on hover" it folds away until the pointer is over its button.
Item {
    id: root
    property string text: ""
    property bool shown: true          // the module's own "show text" switch
    property var host: null            // the BarButton this label belongs to
    property alias color: label.color
    property alias font: label.font
    property alias elide: label.elide
    property real maxWidth: 10000

    readonly property bool open: shown && (!cfg.labelsOnHover || (!!host && (host.intent || host.morphing)))
    property real openness: open ? 1 : 0
    Behavior on openness { NumberAnimation { duration: main.ms(260); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }

    visible: shown && (openness > 0.01 || open)
    implicitWidth: Math.min(maxWidth, label.implicitWidth) * openness
    implicitHeight: label.implicitHeight
    Layout.leftMargin: -4 * (1 - openness)      // cancels the row spacing while folded
    clip: true

    Text {
        id: label
        text: root.text
        width: Math.min(root.maxWidth, implicitWidth)
        opacity: Math.max(0, (root.openness - 0.2) / 0.8)
        anchors.verticalCenter: parent.verticalCenter
    }
}
