// qmllint disable
import QtQuick

// One settings row: an icon tile, the name, and the control on the right. The explanation appears when you rest on the row.
Item {
    id: root
    property string label: ""
    property string desc: ""
    property string icon: ""             // empty = chosen from the label
    default property alias control: slot.data
    width: parent ? parent.width : 300
    height: 48

    readonly property string glyph: icon !== "" ? icon : main.iconFor(label)
    IconTile { id: tile; x: 2; anchors.verticalCenter: parent.verticalCenter; glyph: root.glyph }
    Text {
        id: name
        x: 46; anchors.verticalCenter: parent.verticalCenter
        width: slot.x - x - 12; elide: Text.ElideRight
        text: root.label; color: main.text; font { family: main.font; pixelSize: 14; weight: 600 }
    }
    Item { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }

    // hover explanation
    HoverHandler { id: hov }
    Timer { id: tipTimer; interval: 450; running: hov.hovered && root.desc !== ""; onTriggered: tip.shown = true }
    Connections { target: hov; function onHoveredChanged() { if (!hov.hovered) tip.shown = false; } }
    Rectangle {
        id: tip
        property bool shown: false
        z: 100
        x: 46; y: root.height - 6
        width: Math.min(root.width - 60, tipText.implicitWidth + 24); height: tipText.implicitHeight + 16; radius: 12
        color: Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.98); border.width: 1; border.color: main.line
        opacity: shown ? 1 : 0; visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: main.ms(160); easing.type: Easing.OutCubic } }
        Text { id: tipText; x: 12; y: 8; width: parent.width - 24; text: root.desc; wrapMode: Text.WordWrap; color: main.muted; font { family: main.font; pixelSize: 12 } }
    }
}
