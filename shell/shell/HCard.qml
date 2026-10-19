// qmllint disable
import QtQuick

// Surface that rises in (staggered by `order`) when its page becomes active.
Rectangle {
    id: card
    property bool active: false
    property int order: 0
    property string title: ""
    default property alias content: body.data
    property real padding: 18

    width: parent ? parent.width : 400
    implicitHeight: body.y + body.childrenRect.height + padding
    radius: 18
    color: Qt.rgba(main.card.r, main.card.g, main.card.b, main.panelAlpha < 1 ? 0.72 : 1)
    Behavior on color { ColorAnimation { duration: main.ms(260) } }
    border.width: 1; border.color: main.line

    property bool ready: false
    onActiveChanged: { if (active) { ready = false; delay.restart(); } else { delay.stop(); ready = false; } }
    Component.onCompleted: if (active) delay.restart()
    Timer { id: delay; interval: 70 + card.order * 80; onTriggered: card.ready = true }

    opacity: ready ? 1 : 0
    transform: Translate {
        y: card.ready ? 0 : 12
        Behavior on y { NumberAnimation { duration: main.ms(420); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
    }
    Behavior on opacity { NumberAnimation { duration: main.ms(320); easing.type: Easing.OutCubic } }

    Text {
        id: heading
        visible: card.title !== ""
        x: card.padding; y: card.padding
        text: card.title.toUpperCase(); color: main.muted
        font { family: main.font; pixelSize: 11; weight: 700; letterSpacing: 1.2 }
    }
    Item {
        id: body
        x: card.padding; width: parent.width - card.padding * 2
        y: heading.visible ? card.padding + heading.height + 12 : card.padding
    }
}
