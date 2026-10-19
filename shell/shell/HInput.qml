// qmllint disable
import QtQuick

// Single-line text field in the Hearth style.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property alias font: input.font
    property alias echoMode: input.echoMode
    readonly property bool typing: input.activeFocus
    signal edited(string value)
    signal submitted(string value)
    function release() { input.focus = false; }
    function focusInput() { input.forceActiveFocus(); }

    implicitWidth: 200; implicitHeight: 36
    radius: 12; color: main.page
    border.width: 1; border.color: input.activeFocus ? main.accent : main.line
    Behavior on border.color { ColorAnimation { duration: main.ms(160) } }

    Text {
        anchors.verticalCenter: parent.verticalCenter; x: 12
        visible: input.text === "" && !input.activeFocus
        text: root.placeholder; color: main.muted
        font { family: main.font; pixelSize: 13 }
    }
    TextInput {
        id: input
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: main.text; selectionColor: main.accent; selectedTextColor: main.onAccent
        selectByMouse: true; clip: true
        font { family: main.font; pixelSize: 13 }
        onTextEdited: root.edited(text)
        onAccepted: { root.submitted(text); focus = false; }
    }
}
