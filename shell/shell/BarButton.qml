// qmllint disable
import QtQuick
import QtQuick.Layouts

// Shared base for bar modules: padded, hoverable, scroll-aware.
Rectangle {
    id: root
    property bool interactive: true
    property bool morphing: false          // a popup menu belongs to this button (shown highlighted)
    default property alias content: row.data
    signal clicked()
    signal rightClicked()
    signal scrolled(int dir)               // +1 = up, -1 = down

    // modules supply these; Bar sets them when it loads the module
    property var bar: null
    property string zone: ""
    // icon colour follows the bar's icon setting: theme accent, plain text, or one colour per module
    property string toneName: ""
    readonly property color iconColor: main.iconMode === "text" ? main.text
        : (main.iconMode === "colour" && toneName !== "" ? main[toneName] : main.icon)

    implicitWidth: row.implicitWidth + 10
    implicitHeight: main.barPx + 11
    radius: 8
    color: morphing ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.20)
         : interactive && mouse.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.10) : "transparent"
    Behavior on color { ColorAnimation { duration: main.ms(160) } }
    scale: interactive && mouse.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: main.ms(180); easing.type: Easing.OutBack } }

    readonly property bool hovered: hoverTrack.hovered
    // "hover intent": the text slides out after a short rest on the button and folds away a moment after leaving,
    // so sweeping the pointer across the bar doesn't make everything jump around
    property bool intent: false
    onHoveredChanged: { if (hovered) { intentOff.stop(); intentOn.restart(); } else { intentOn.stop(); intentOff.restart(); } }
    Timer { id: intentOn; interval: 170; onTriggered: root.intent = true }
    Timer { id: intentOff; interval: 320; onTriggered: root.intent = false }
    HoverHandler { id: hoverTrack }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.rightClicked(); else root.clicked(); }
        onWheel: wheel => { if (wheel.angleDelta.y !== 0) root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1); }
    }
}
