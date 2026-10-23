import QtQuick

// The bar as three lanes (left, middle, right) with its modules as chips you drag between them.
// Modules that are off wait in the tray underneath; drag one up to turn it on, or drag a chip down to turn it off.
Item {
    id: root
    required property var shell
    readonly property var mods: shell.cfg.modules
    readonly property var zones: ["left", "center", "right"]
    readonly property var zoneNames: ({ "left": "Left", "center": "Middle", "right": "Right" })
    readonly property real laneLabelW: 70
    width: parent ? parent.width : 400
    height: lanes.height + 16 + trayLabel.height + 8 + tray.height
    property string dragId: ""
    property point dragAt
    property string hoverZone: ""
    readonly property var unused: shell.moduleOrder.filter(id => shell.zoneOf(id) === "")
    function laneItem(z) { return z === "left" ? laneL : (z === "center" ? laneM : laneR); }

    // where would a chip dropped at (x, y) land? Chips before the pointer (earlier row, or same row and further left) come first.
    function target(x, y) {
        for (const z of zones) {
            const it = laneItem(z), r = it.mapToItem(root, 0, 0);
            if (y >= r.y - 4 && y <= r.y + it.height + 4) {
                let idx = 0;
                for (const c of it.chipItems()) {
                    if (c.chipId === dragId) continue;
                    const cr = c.mapToItem(root, 0, 0), cy = cr.y + c.height / 2, cx = cr.x + c.width / 2;
                    if (cy < y - c.height / 2 || (Math.abs(cy - y) <= c.height / 2 && cx < x)) idx++;
                }
                return { "zone": z, "index": idx };
            }
        }
        return { "zone": "", "index": -1 };
    }
    function drop() {
        if (dragId === "") return;
        const t = target(dragAt.x, dragAt.y), id = dragId;
        if (t.zone !== "") shell.placeModule(id, t.zone, t.index);
        else if (dragAt.y > lanes.height + 4) shell.placeModule(id, "", -1);
        dragId = ""; hoverZone = "";
    }
    function move(x, y) { dragAt = Qt.point(x, y); hoverZone = target(x, y).zone; }

    // ------------------------------------------------------------ the three lanes of the bar
    Column {
        id: lanes
        width: parent.width; spacing: 8
        Repeater {
            model: root.zones
            delegate: Rectangle {
                id: lane
                required property string modelData
                readonly property bool hot: root.hoverZone === modelData && root.dragId !== ""
                function chipItems() { const out = []; for (let i = 0; i < flow.children.length; i++) if (flow.children[i].chipId !== undefined) out.push(flow.children[i]); return out; }
                Component.onCompleted: { if (modelData === "left") laneL = lane; else if (modelData === "center") laneM = lane; else laneR = lane; }
                width: parent.width; height: Math.max(56, flow.height + 22); radius: 18
                color: hot ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.13) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.045)
                border.width: hot ? 2 : 0; border.color: main.accent
                Behavior on color { ColorAnimation { duration: main.ms(120) } }
                Behavior on height { NumberAnimation { duration: main.ms(180); easing.type: Easing.OutCubic } }
                Text { x: 16; y: 20; text: root.zoneNames[lane.modelData]; color: main.muted; font { family: main.font; pixelSize: 12; weight: 700 } }
                Flow {
                    id: flow
                    x: root.laneLabelW + 8; y: 11; width: parent.width - x - 12; spacing: 6
                    Repeater { model: root.mods[lane.modelData]; delegate: Chip { chipId: modelData; inBar: true } }
                }
                Text { visible: root.mods[lane.modelData].length === 0; x: root.laneLabelW + 14; y: 20; text: "Drop modules here"; color: main.muted; opacity: 0.55; font { family: main.font; pixelSize: 12 } }
            }
        }
    }
    property Item laneL
    property Item laneM
    property Item laneR

    // ------------------------------------------------------------ the tray of modules that are off
    Text { id: trayLabel; y: lanes.height + 16; text: root.unused.length > 0 ? "Not on the bar  ·  drag one up" : "Every module is on the bar"; color: main.muted; font { family: main.font; pixelSize: 11; weight: 600 } }
    Flow {
        id: tray
        y: trayLabel.y + trayLabel.height + 8; width: parent.width; spacing: 6
        Repeater { model: root.unused; delegate: Chip { chipId: modelData; inBar: false } }
    }

    // ------------------------------------------------------------ one module as a chip
    component Chip: Rectangle {
        id: chip
        property string chipId: ""
        property bool inBar: true
        readonly property var info: root.shell.moduleInfo[chipId]
        readonly property bool lifted: root.dragId === chipId
        height: 34; width: lab.implicitWidth + 44; radius: 17
        color: lifted ? "transparent" : (cm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.16) : Qt.rgba(main.text.r, main.text.g, main.text.b, inBar ? 0.1 : 0.06))
        border.width: inBar ? 0 : 1; border.color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.14)
        opacity: lifted ? 0.35 : 1
        Behavior on color { ColorAnimation { duration: main.ms(120) } }
        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: main.iconFor(chip.info.label); color: chip.inBar ? main.accent : main.muted
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 15 } }
        Text { id: lab; x: 34; anchors.verticalCenter: parent.verticalCenter; text: chip.info.label; color: chip.inBar ? main.text : main.muted
            font { family: main.font; pixelSize: 12; weight: 600 } }
        MouseArea {
            id: cm
            anchors.fill: parent; hoverEnabled: true; preventStealing: true; cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: m => { const p = mapToItem(root, m.x, m.y); root.dragId = chip.chipId; root.dragAt = p; }
            onPositionChanged: m => { if (pressed) { const p = mapToItem(root, m.x, m.y); root.move(p.x, p.y); } }
            onReleased: root.drop()
            onCanceled: { root.dragId = ""; root.hoverZone = ""; }
        }
    }

    // the chip that follows the pointer
    Rectangle {
        visible: root.dragId !== ""
        z: 20; x: root.dragAt.x - width / 2; y: root.dragAt.y - height / 2
        height: 36; width: gl.implicitWidth + 44; radius: 18
        color: main.accent; opacity: 0.95
        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: root.dragId !== "" ? main.iconFor(root.shell.moduleInfo[root.dragId].label) : ""; color: main.onAccent
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 15 } }
        Text { id: gl; x: 34; anchors.verticalCenter: parent.verticalCenter; text: root.dragId !== "" ? root.shell.moduleInfo[root.dragId].label : ""; color: main.onAccent
            font { family: main.font; pixelSize: 12; weight: 700 } }
    }
}
