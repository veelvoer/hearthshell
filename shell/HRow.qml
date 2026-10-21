// qmllint disable
import QtQuick

// One settings row: an icon tile, the name, and the control on the right. The explanation appears when you rest on the row.
Item {
    id: root
    property string label: ""
    property string desc: ""
    property string icon: ""
    property bool available: true             // false = this setting makes no sense for the current setup, so it is not shown or searchable
    property string keywords: ""
    visible: available
    property real labelCenter: height / 2   // where the label and the control are centred, measured from the top of the row
    default property alias control: slot.data
    width: parent ? parent.width : 300
    height: 44

    readonly property string glyph: icon !== "" ? icon : main.iconFor(label)

    // searching: the row tells the page it sits on that it exists, and can flash when you land on it
    property real flashK: 0
    function flash() { flashAnim.restart(); }
    SequentialAnimation { id: flashAnim
        NumberAnimation { target: root; property: "flashK"; to: 1; duration: 160; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 900 }
        NumberAnimation { target: root; property: "flashK"; to: 0; duration: 700; easing.type: Easing.InOutCubic } }
    Rectangle { x: -6; y: 2; width: parent.width + 12; height: parent.height - 4; radius: 12; z: -1
        color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.16 * root.flashK); visible: root.flashK > 0.01 }
    Component.onCompleted: {
        if (root.label === "") return;
        let p = parent;
        while (p) { if (p.isSettingsPage === true) { p.registerRow(root); break; } p = p.parent; }
    }
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
