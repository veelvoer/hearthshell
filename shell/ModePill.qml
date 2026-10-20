import QtQuick

// A pill with a few choices and an accent knob that slides to the chosen one; the same look as the Control Center tiles.
Item {
    id: root
    property var options: []              // [{ glyph: codepoint, label: "Eco" }]
    property int current: 0
    property color tone: main.accent
    signal picked(int index)
    readonly property real cellW: width / Math.max(1, options.length)

    Rectangle {
        anchors.fill: parent; radius: height / 2
        color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
    }
    Rectangle {
        id: knob
        y: 3; height: parent.height - 6; width: root.cellW - 6; radius: height / 2
        x: 3 + root.current * root.cellW
        color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.92)
        Behavior on x { NumberAnimation { duration: main.ms(320); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
    }
    Repeater {
        model: root.options
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool on: root.current === index
            x: index * root.cellW; width: root.cellW; height: root.height
            Row {
                anchors.centerIn: parent; spacing: 7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(cell.modelData.glyph)
                    color: cell.on ? main.bg : (cm.containsMouse ? main.text : main.muted)
                    font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 17 }
                    Behavior on color { ColorAnimation { duration: main.ms(180) } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.cellW > 92
                    text: cell.modelData.label
                    color: cell.on ? main.bg : (cm.containsMouse ? main.text : main.muted)
                    font { family: main.font; pixelSize: 12; weight: 700 }
                    Behavior on color { ColorAnimation { duration: main.ms(180) } }
                }
            }
            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(cell.index) }
        }
    }
}
