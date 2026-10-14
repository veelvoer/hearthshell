// qmllint disable
import QtQuick

// UI font choice; each chip is drawn in its own typeface.
Flow {
    id: root
    property string value: "Inter"
    signal picked(string family)
    spacing: 8
    readonly property var installed: Qt.fontFamilies()
    readonly property var choices: ["Inter", "Cantarell", "Montserrat", "Roboto", "Noto Sans", "DejaVu Sans", "Noto Serif"]
        .filter(f => f === "Inter" || installed.indexOf(f) >= 0)

    Repeater {
        model: root.choices
        Rectangle {
            id: chip
            required property string modelData
            readonly property bool sel: root.value === modelData
            width: lbl.implicitWidth + 28; height: 34; radius: 12
            color: sel ? main.accent : (hm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08) : main.page)
            border.width: 1; border.color: sel ? main.accent : main.line
            scale: hm.pressed ? 0.95 : 1
            Behavior on color { ColorAnimation { duration: main.ms(160) } }
            Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
            Text {
                id: lbl; anchors.centerIn: parent
                text: modelData === "Inter" ? "Default" : modelData
                color: chip.sel ? main.onAccent : main.text
                font { family: modelData; pixelSize: 13; weight: 600 }
            }
            MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(chip.modelData) }
        }
    }
}
