// qmllint disable
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Power menu: lock, log out, sleep, restart, shut down. Restart and shut down ask twice.
PanelWindow {
    id: win
    required property var shell
    readonly property bool wanted: shell.powerOpen && shell.overlayScreen === (screen ? screen.name : "")
    property real k: wanted ? 1 : 0
    Behavior on k { NumberAnimation { duration: main.ms(wanted ? 520 : 240); easing.type: wanted ? Easing.BezierSpline : Easing.OutCubic; easing.bezierCurve: [0.34, 1.18, 0.64, 1, 1, 1] } }

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: wanted || k > 0.005
    mask: Region { item: (wanted || k > 0.005) ? hit : null }

    property int sel: 0
    property string confirm: ""
    readonly property var items: [
        { "key": "lock", "label": "Lock", "glyph": 0xF033E },
        { "key": "logout", "label": "Log Out", "glyph": 0xF0343 },
        { "key": "sleep", "label": "Suspend", "glyph": 0xF04B2 },
        { "key": "reboot", "label": "Reboot", "glyph": 0xF0709 },
        { "key": "off", "label": "Power Off", "glyph": 0xF0425 }
    ]
    onWantedChanged: { if (wanted) { sel = 0; confirm = ""; keys.forceActiveFocus(); } }
    Timer { id: confirmTimer; interval: 3000; onTriggered: win.confirm = "" }
    Timer { id: lockTimer; interval: 380; onTriggered: win.shell.lockNow() }
    Process { id: proc }
    function run(cmd) { proc.command = cmd; proc.running = true; }
    function act(key) {
        if ((key === "reboot" || key === "off") && confirm !== key) { confirm = key; confirmTimer.restart(); return; }
        confirm = "";
        shell.powerOpen = false;
        if (key === "lock") lockTimer.restart();
        else if (key === "logout") run(["sh", "-c", "hyprctl dispatch exit || loginctl terminate-user \"$USER\""]);
        else if (key === "sleep") run(["systemctl", "suspend"]);
        else if (key === "reboot") run(["systemctl", "reboot"]);
        else run(["systemctl", "poweroff"]);
    }

    Item { id: hit; anchors.fill: parent; MouseArea { anchors.fill: parent; onClicked: win.shell.powerOpen = false } }
    FocusScope {
        id: keys
        anchors.fill: parent
        focus: win.wanted
        Keys.onEscapePressed: win.shell.powerOpen = false
        Keys.onLeftPressed: win.sel = (win.sel + win.items.length - 1) % win.items.length
        Keys.onRightPressed: win.sel = (win.sel + 1) % win.items.length
        Keys.onTabPressed: win.sel = (win.sel + 1) % win.items.length
        Keys.onReturnPressed: win.act(win.items[win.sel].key)
        Keys.onEnterPressed: win.act(win.items[win.sel].key)
    }

    Rectangle {
        id: card
        width: row.width + 36; height: 150
        x: (parent.width - width) / 2; y: parent.height * 0.32
        radius: Math.min(28, shell.cfg.barRadius + 13)
        color: Qt.alpha(main.bg, main.menuAlpha)
        border.width: 1; border.color: main.border
        opacity: Math.min(1, win.k * 1.8)
        scale: 0.92 + 0.08 * win.k
        MouseArea { anchors.fill: parent }
        Row {
            id: row
            x: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 10
            Repeater {
                model: win.items
                delegate: Rectangle {
                    id: b
                    required property var modelData
                    required property int index
                    readonly property bool asking: win.confirm === modelData.key
                    readonly property bool on: index === win.sel
                    width: 100; height: 114; radius: 22
                    color: asking ? Qt.rgba(main.red.r, main.red.g, main.red.b, 0.85) : on ? main.accent : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                    border.width: 0
                    scale: bm.pressed ? 0.95 : 1
                    Behavior on color { ColorAnimation { duration: main.ms(160) } }
                    Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
                    Column {
                        anchors.centerIn: parent; spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(b.modelData.glyph)
                            color: (b.on || b.asking) ? main.bg : main.text; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 32 } }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: b.asking ? "Sure?" : b.modelData.label
                            color: (b.on || b.asking) ? main.bg : main.muted; font { family: main.font; pixelSize: 12; weight: 700 } }
                    }
                    MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = b.index; onClicked: win.act(b.modelData.key) }
                }
            }
        }
    }
}
