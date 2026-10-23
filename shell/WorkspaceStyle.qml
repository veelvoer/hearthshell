import Quickshell.Hyprland
import QtQuick

// The three animated workspace indicators: bars (a carousel of ticks), scroll (a window of numbers) and stretch (dots with a ring that stretches).
// Everything is driven by one smoothly moving position, so a switch glides and can be interrupted at any moment.
Item {
    id: root
    property string kind: "bars"            // bars | scroll | stretch
    property int slots: Math.max(1, cfg.wsCount)   // exactly how many entries are visible at once
    property real unit: 1                   // overall size
    // the line starts at workspace 1 and grows with the workspaces that exist (Hyprland makes new ones as you scroll)
    readonly property int total: Math.max(1, slots, highest, active + 1)
    readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id - 1 : 0
    readonly property real step: (kind === "scroll" ? 20 : 18) * unit
    readonly property int shown: kind === "stretch" ? slots : slots
    readonly property int highest: {
        let h = 0;
        for (const w of Hyprland.workspaces.values) h = Math.max(h, w.id);
        return h;
    }
    implicitWidth: kind === "stretch" ? shown * step : slots * step
    implicitHeight: Math.round((main.barPx + 9) * unit)
    clip: true

    // the active workspace as one smoothly moving position: fast scrolling just keeps moving it, so nothing is skipped
    property real pos: 0
    Behavior on pos { NumberAnimation { duration: main.ms(380); easing.type: Easing.OutCubic } }
    onActiveChanged: { pos = active; head = active; tail = active; }
    Component.onCompleted: { pos = active; head = active; tail = active; }
    // stretch: the head of the ring leads and the tail follows, so the ring stretches while it moves
    property real head: active
    property real tail: active
    Behavior on head { NumberAnimation { duration: main.ms(240); easing.type: Easing.OutCubic } }
    Behavior on tail { NumberAnimation { duration: main.ms(460); easing.type: Easing.OutCubic } }

    function has(i) { return !!Hyprland.workspaces.values.find(w => w.id === i + 1); }
    function go(i) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + (i + 1) + " })"); }
    function near(i) { return Math.max(0, 1 - Math.abs(i - pos)); }
    // The visible window slides along the line but never past its ends, so workspace 1 sits at the left edge and the last one at the right.
    readonly property real half: (slots - 1) / 2
    // endless to the right (Hyprland makes a workspace as soon as you go there), with workspace 1 as the left end
    readonly property int lineCount: Math.max(slots, highest, active + 1) + slots
    readonly property real centre: Math.max(half, pos)
    // edge fade for the carousels
    function fade(i) { return Math.max(0, Math.min(1, slots / 2 + 0.2 - Math.abs(i - centre))); }

    // ------------------------------------------------------------ bars + scroll
    Repeater {
        model: root.kind === "stretch" ? 0 : root.lineCount
        delegate: Item {
            id: cell
            required property int index
            readonly property int abs: index
            readonly property int ws: index
            readonly property real near: root.near(abs)
            x: root.width / 2 + (abs - root.centre) * root.step - root.step / 2
            width: root.step; height: root.height
            opacity: root.fade(abs) * (root.has(ws) || near > 0.3 ? 1 : 0.5)
            visible: opacity > 0.01

            Rectangle {
                visible: root.kind === "bars"
                anchors.centerIn: parent
                width: 2 * root.unit + near * 1.2 * root.unit; height: (6 + near * 9) * root.unit; radius: width / 2
                color: Qt.tint(root.has(cell.ws) ? main.text : main.muted, Qt.rgba(main.wsa.r, main.wsa.g, main.wsa.b, near))
            }
            Text {
                visible: root.kind === "scroll"
                anchors.centerIn: parent
                text: cell.ws + 1
                color: Qt.tint(root.has(cell.ws) ? main.text : main.muted, Qt.rgba(main.wsa.r, main.wsa.g, main.wsa.b, near * 0.9))
                font { family: main.font; pixelSize: Math.round(main.barPx * (0.66 + 0.42 * near) * root.unit); weight: near > 0.5 ? 700 : 500 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.go(cell.ws) }
        }
    }

    // ------------------------------------------------------------ stretch
    Item {
        visible: root.kind === "stretch"
        anchors.fill: parent
        readonly property real first: Math.max(0, Math.min(root.total - root.shown, Math.round(root.active) - Math.floor(root.shown / 2)))
        function cx(i) { return (i - first + 0.5) * root.step; }
        readonly property real h: 10 * root.unit

        // the line left behind the ring; when the first workspaces have scrolled out of view it fades in from the left
        Rectangle {
            readonly property real x0: Math.max(0, parent.cx(0))
            x: x0; y: (parent.height - height) / 2
            width: Math.max(0, parent.cx(root.head) - x0); height: Math.max(1, 1.5 * root.unit); radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: parent.parent.first > 0 ? "transparent" : Qt.rgba(main.wsa.r, main.wsa.g, main.wsa.b, 0.75) }
                GradientStop { position: Math.min(0.9, 22 / Math.max(22, parent.width)); color: Qt.rgba(main.wsa.r, main.wsa.g, main.wsa.b, 0.75) }
                GradientStop { position: 1; color: Qt.rgba(main.wsa.r, main.wsa.g, main.wsa.b, 0.75) }
            }
        }
        Repeater {
            model: root.shown
            delegate: Rectangle {
                required property int index
                readonly property int ws: index + parent.first
                readonly property bool lit: root.has(ws)
                x: parent.cx(ws) - width / 2; y: (parent.height - height) / 2
                width: (lit ? 5 : 4) * root.unit; height: width; radius: width / 2
                color: ws <= root.head + 0.01 ? main.wsa : (lit ? main.text : main.muted)
                opacity: lit || ws <= root.head ? 1 : 0.6
                Behavior on color { ColorAnimation { duration: main.ms(200) } }
            }
        }
        // the ring, stretched between tail and head
        Rectangle {
            readonly property real a: Math.min(root.tail, root.head)
            readonly property real b: Math.max(root.tail, root.head)
            x: parent.cx(a) - parent.h / 2; y: (parent.height - height) / 2
            width: parent.cx(b) - parent.cx(a) + parent.h; height: parent.h; radius: height / 2
            color: Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.9)
            border.width: Math.max(1.2, 1.5 * root.unit); border.color: main.wsa
        }
        Repeater {
            model: root.shown
            delegate: MouseArea {
                required property int index
                x: index * root.step; width: root.step; height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(index + parent.first)
            }
        }
    }
}
