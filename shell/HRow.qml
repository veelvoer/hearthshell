// qmllint disable
import QtQuick

// Label + description on the left, control on the right.
Item {
    id: root
    property string label: ""
    property string desc: ""
    default property alias control: slot.data
    width: parent ? parent.width : 300
    height: Math.max(44, col.implicitHeight + 6)

    Column {
        id: col
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.right: slot.left; anchors.rightMargin: 16
        spacing: 2
        Text { text: root.label; color: main.text; font { family: main.font; pixelSize: 14; weight: 600 } }
        Text {
            visible: root.desc !== ""; text: root.desc; color: main.muted; width: parent.width; wrapMode: Text.WordWrap
            font { family: main.font; pixelSize: 12 }
        }
    }
    Item { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
}
