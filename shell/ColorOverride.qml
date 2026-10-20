import QtQuick

// Pick a colour for one surface: follow the theme, one of a few swatches, or any colour.
Item {
    id: root
    property string label: ""
    property string value: ""                 // "" = follow the theme
    property color themeColor: main.bg
    signal picked(string color)
    property bool open: false
    width: parent ? parent.width : 300
    height: 48 + (open ? 92 : 0)
    clip: true
    Behavior on height { NumberAnimation { duration: main.ms(240); easing.type: Easing.OutCubic } }
    readonly property var swatches: ["#11141a", "#1b1f27", "#232a36", "#2d2438", "#1d2b2a", "#2b241d", "#f2efe9", "#e4e8f0"]

    Text { x: 2; y: 14; text: root.label; color: main.text; font { family: main.font; pixelSize: 13; weight: 500 } }
    Row {
        anchors { right: parent.right; top: parent.top; topMargin: 8 }
        spacing: 6
        Rectangle {
            width: 32; height: 32; radius: 16; color: root.value !== "" ? root.value : root.themeColor
            border.width: 2; border.color: root.value === "" ? main.accent : main.line
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked("") }
        }
        Repeater {
            model: root.swatches.slice(0, 4)
            delegate: Rectangle {
                required property string modelData
                width: 32; height: 32; radius: 16; color: modelData
                border.width: 2; border.color: root.value.toLowerCase() === modelData ? main.accent : main.line
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(modelData) }
            }
        }
        HButton { label: root.open ? "Done" : "More…"; padX: 12; onClicked: root.open = !root.open }
    }
    Column {
        y: 48; spacing: 8; width: parent.width
        visible: root.open
        Row {
            spacing: 6
            Repeater {
                model: root.swatches.slice(4)
                delegate: Rectangle {
                    required property string modelData
                    width: 28; height: 28; radius: 14; color: modelData
                    border.width: 2; border.color: root.value.toLowerCase() === modelData ? main.accent : main.line
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(modelData) }
                }
            }
            HButton { label: "Follow theme"; padX: 12; onClicked: root.picked("") }
        }
        HColorPicker { width: 300; value: root.value !== "" ? root.value : root.themeColor; onPicked: c => root.picked(String(c)) }
    }
}
