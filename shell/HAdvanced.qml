// qmllint disable
import QtQuick

// Collapsible "more options" block: keeps rarely used settings out of the way.
Item {
    id: root
    property string title: "More options"
    property bool open: false
    default property alias content: body.data
    width: parent ? parent.width : 300
    height: 34 + (open ? body.implicitHeight + 10 : 0)
    clip: true
    Behavior on height { NumberAnimation { duration: main.ms(320); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }

    Rectangle {
        id: head
        width: parent.width; height: 30; radius: 10
        color: hit.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: main.ms(160) } }
        Text {
            x: 8; anchors.verticalCenter: parent.verticalCenter; text: root.title
            color: root.open ? main.accent : main.muted
            Behavior on color { ColorAnimation { duration: main.ms(200) } }
            font { family: main.font; pixelSize: 12; weight: 600 }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            text: "›"; color: main.muted; rotation: root.open ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
            font { pixelSize: 18; weight: 600 }
        }
        MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
    }
    Column {
        id: body
        y: 38; width: parent.width; spacing: 4
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: main.ms(240) } }
    }
}
