// qmllint disable
import QtQuick

// Settings group: a small label above a rounded surface that rises in (staggered by `order`) when its page becomes active.
Item {
    id: card
    property bool active: false
    property int order: 0
    property string title: ""
    default property alias content: body.data
    property real padding: 12
    property bool available: true
    visible: available
    property bool collapsible: false          // secondary cards start folded, so a page shows only what matters first
    property bool expanded: !collapsible
    readonly property real openK: expanded ? 1 : 0

    width: parent ? parent.width : 400
    readonly property real topOffset: title !== "" ? 24 : 0
    implicitHeight: topOffset + surface.height + (collapsible ? 0 : 0)

    property real shownK: openK
    Behavior on shownK { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
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

    Item {
        visible: card.title !== ""; x: 0; y: 0; width: parent.width; height: 22
        Text { x: 8; y: 2; text: card.title; color: card.collapsible && tm.containsMouse ? main.text : main.muted
            font { family: main.font; pixelSize: 11; weight: 600 } }
        Text { visible: card.collapsible; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: "›"; color: main.muted; rotation: card.expanded ? 90 : 0
            font { pixelSize: 16; weight: 600 }
            Behavior on rotation { NumberAnimation { duration: main.ms(220); easing.type: Easing.OutCubic } } }
        MouseArea { id: tm; anchors.fill: parent; enabled: card.collapsible; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.expanded = !card.expanded }
    }
    Rectangle {
        id: surface
        y: card.topOffset; width: parent.width
        height: (body.childrenRect.height + card.padding * 2) * card.shownK
        clip: card.collapsible
        visible: height > 0.5
        radius: 16
        color: Qt.rgba(main.card.r, main.card.g, main.card.b, main.panelAlpha < 1 ? 0.72 : 1)
        Behavior on color { ColorAnimation { duration: main.ms(260) } }
        Item {
            id: body
            x: card.padding; y: card.padding; width: parent.width - card.padding * 2
        }
    }
}
