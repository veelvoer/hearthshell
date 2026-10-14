// qmllint disable
import QtQuick

// Accent colour override: "theme default" plus a handful of swatches (and a custom slot).
Flow {
    id: root
    property string value: ""            // "" = the theme's own accent
    property bool customOpen: false
    signal picked(string color)
    signal customRequested()
    spacing: 10
    readonly property var swatches: ["#ff7188", "#ff9f5a", "#ffd36a", "#a7c080", "#62c98c", "#3fd0dc", "#4bb9e8", "#7aa2f7", "#bd93f9", "#f5a3d4"]

    component Dot: Item {
        id: dot
        property color fill: "white"
        property bool sel: false
        property bool ring: false
        signal clicked()
        width: 30; height: 30
        scale: dm.pressed ? 0.88 : (dm.containsMouse ? 1.12 : 1)
        Behavior on scale { NumberAnimation { duration: main.ms(180); easing.type: Easing.OutBack } }
        Rectangle { anchors.fill: parent; radius: 15; color: dot.ring ? "transparent" : dot.fill
            border.width: dot.ring ? 2 : 0; border.color: main.muted }
        Rectangle {   // selection ring
            anchors.centerIn: parent; width: 38; height: 38; radius: 19; color: "transparent"
            border.width: 2; border.color: main.text; opacity: dot.sel ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: main.ms(180) } }
        }
        Text { visible: dot.ring; anchors.centerIn: parent; text: "A"; color: main.muted
            font { family: main.font; pixelSize: 13; weight: 700 } }
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dot.clicked() }
    }

    Dot { ring: true; sel: root.value === ""; onClicked: root.picked("") }
    Repeater {
        model: root.swatches
        Dot {
            required property string modelData
            fill: modelData; sel: root.value.toLowerCase() === modelData
            onClicked: root.picked(modelData)
        }
    }
    Dot {
        fill: root.value !== "" && root.swatches.indexOf(root.value.toLowerCase()) < 0 ? root.value : main.line
        sel: root.value !== "" && root.swatches.indexOf(root.value.toLowerCase()) < 0
        onClicked: root.customRequested()
        Text { anchors.centerIn: parent; text: "+"; color: main.text; font { pixelSize: 18; weight: 600 } }
    }
}
