import QtQuick

// An exact number: minus, the value, plus. Hold a button to count quickly.
Item {
    id: root
    property int value: 0
    property int from: 0
    property int to: 99
    property string unit: ""
    signal moved(int value)
    implicitWidth: 132; implicitHeight: 34
    width: implicitWidth; height: implicitHeight

    function step(d) { const v = Math.max(from, Math.min(to, value + d)); if (v !== value) moved(v); }

    Rectangle { anchors.fill: parent; radius: height / 2; color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07) }
    Repeater {
        model: [-1, 1]
        delegate: Rectangle {
            id: btn
            required property int modelData
            readonly property bool can: modelData < 0 ? root.value > root.from : root.value < root.to
            width: 30; height: 30; radius: 15; y: 2
            x: modelData < 0 ? 2 : root.width - width - 2
            color: bm.pressed && can ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.4) : (bm.containsMouse && can ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.14) : "transparent")
            opacity: can ? 1 : 0.35
            Behavior on color { ColorAnimation { duration: main.ms(120) } }
            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: btn.modelData < 0 ? "−" : "+"; color: main.text; font { family: main.font; pixelSize: 18; weight: 600 } }
            MouseArea {
                id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.step(btn.modelData)
                onPressAndHold: rep.start()
                onReleased: rep.stop()
                onCanceled: rep.stop()
            }
            Timer { id: rep; interval: 110; repeat: true; onTriggered: root.step(btn.modelData) }
        }
    }
    Text { anchors.centerIn: parent; text: root.value + root.unit; color: main.text; font { family: main.font; pixelSize: 13; weight: 700 } }
}
