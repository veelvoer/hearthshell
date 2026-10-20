// qmllint disable
import QtQuick

// One settings row: an icon tile, the name, and the control on the right. The explanation appears when you rest on the row.
Item {
    id: root
    property string label: ""
    property string desc: ""
    property string icon: ""
    property real labelCenter: height / 2   // where the label and the control are centred, measured from the top of the row
    default property alias control: slot.data
    width: parent ? parent.width : 300
    height: 44

    readonly property string glyph: icon !== "" ? icon : main.iconFor(label)
    // a hairline between rows, never above the first or below the last
    Rectangle {
        visible: root.y > 0.5
        x: 0; y: 0; width: parent.width; height: 1
        color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.06)
    }
    Text {
        id: name
        x: 2; y: root.labelCenter - height / 2
        width: slot.x - x - 12; elide: Text.ElideRight
        text: root.label; color: main.text; font { family: main.font; pixelSize: 13; weight: 500 }
    }
    Item { id: slot; anchors.right: parent.right; y: root.labelCenter - height / 2; width: childrenRect.width; height: childrenRect.height }
}
