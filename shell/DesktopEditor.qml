import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Full-screen editor for the desktop and the lock screen: drag widgets around, pull a corner to resize,
// add them from the gallery, and open Customize for everything else.
Item {
    id: root
    required property var shell
    visible: false
    property bool open: false
    property string tab: "home"                   // home | lock
    property string selected: ""
    property var targetScreen: null
    property bool gallery: false
    property bool customizing: false
    property bool typing: false
    property bool picking: false
    readonly property string key: tab === "home" ? "homeWidgets" : "lockWidgets"
    readonly property var list: shell.cfg[key] || []
    readonly property var selectedSpec: list.find(w => w.id === selected)
    readonly property var pal: shell.main
    readonly property var defs: shell.widgetDefs

    // ---- history: every change can be taken back
    property var undoStack: []
    property var redoStack: []
    property int undoCount: 0
    property int redoCount: 0
    property string lastTag: ""
    property real lastAt: 0
    function commit(l, tag) {
        const now = Date.now();
        if (!(tag && tag === lastTag && now - lastAt < 800)) {
            undoStack = undoStack.concat([{ "key": key, "list": list }]).slice(-60);
            redoStack = [];
        }
        lastTag = tag || ""; lastAt = now;
        undoCount = undoStack.length; redoCount = 0;
        shell.set(key, l);
    }
    function undo() {
        if (undoStack.length === 0) return;
        const e = undoStack[undoStack.length - 1];
        undoStack = undoStack.slice(0, -1);
        redoStack = redoStack.concat([{ "key": e.key, "list": shell.cfg[e.key] || [] }]);
        lastTag = "";
        undoCount = undoStack.length; redoCount = redoStack.length;
        shell.set(e.key, e.list);
        if (!list.find(w => w.id === selected)) selected = "";
    }
    function redo() {
        if (redoStack.length === 0) return;
        const e = redoStack[redoStack.length - 1];
        redoStack = redoStack.slice(0, -1);
        undoStack = undoStack.concat([{ "key": e.key, "list": shell.cfg[e.key] || [] }]);
        lastTag = "";
        undoCount = undoStack.length; redoCount = redoStack.length;
        shell.set(e.key, e.list);
    }

    function show(t) {
        tab = t === "lock" ? "lock" : "home";
        selected = ""; gallery = false; customizing = false; typing = false;
        undoStack = []; redoStack = []; undoCount = 0; redoCount = 0;
        targetScreen = screenByName(shell.focusedMonitorName());
        open = true;
    }
    function hide() { open = false; selected = ""; gallery = false; customizing = false; }
    function screenByName(n) {
        for (const s of shell.screens) if (s.name === n) return s;
        return shell.screens.length > 0 ? shell.screens[0] : null;
    }

    // ---- changing widgets
    function update(id, patch, tag) { commit(list.map(w => w.id === id ? Object.assign({}, w, patch) : w), tag || ""); }
    function setOption(id, k, v) { const p = {}; p[k] = v; update(id, p, id + ":" + k); }
    function remove(id) { if (selected === id) { selected = ""; customizing = false; } commit(list.filter(w => w.id !== id)); }
    function toFront(id) { const w = list.find(x => x.id === id); if (w) commit(list.filter(x => x.id !== id).concat([w])); }
    function resetWidget(id) {
        const w = list.find(x => x.id === id);
        if (w) commit(list.map(x => x.id === id ? { "id": w.id, "type": w.type, "x": w.x, "y": w.y, "scale": w.scale } : x));
    }
    function duplicate(id) {
        const w = list.find(x => x.id === id);
        if (!w) return;
        const c = Object.assign({}, w, { "id": w.type + "-" + Date.now().toString(36), "x": Math.min(0.95, w.x + 0.02), "y": Math.min(0.95, w.y + 0.03) });
        commit(list.concat([c]));
        selected = c.id;
    }
    function rectOf(w) {
        const d = shell.widgetTypes[w.type], s = targetScreen, k = w.scale * s.height / 1080;
        return { "x": w.x * s.width, "y": w.y * s.height, "w": d.w * k, "h": d.h * k };
    }
    function alignTo(id, cx, cy) {
        const w = list.find(x => x.id === id), s = targetScreen;
        if (!w || !s) return;
        const r = rectOf(w), m = 32;
        const x = cx === 0 ? m : (cx === 1 ? (s.width - r.w) / 2 : s.width - m - r.w);
        const y = cy === 0 ? m + 40 : (cy === 1 ? (s.height - r.h) / 2 : s.height - m - r.h - 120);
        update(id, { "x": Math.round(x / s.width * 10000) / 10000, "y": Math.round(y / s.height * 10000) / 10000 });
    }
    // the free spot nearest the middle of the screen, clear of the other widgets and of the bars at the top and bottom
    function freeSpot(d) {
        const s = targetScreen, k = s.height / 1080, w = d.w * k, h = d.h * k, rects = list.map(rectOf), c = [];
        if (tab === "lock") {      // the clock and the password field of the lock screen stay where they are
            const f = shell.lockFontPx, cy = s.height * shell.cfg.lockClockY, top = cy - shell.stackGap - f * 0.8 - 30, bottom = cy + f * 1.35 + 150;
            rects.push({ "x": s.width / 2 - 200, "y": top, "w": 400, "h": bottom - top });
        }
        for (let gy = 0.1; gy <= 0.84 - h / s.height; gy += 0.03)
            for (let gx = 0.03; gx <= 0.97 - w / s.width; gx += 0.03) c.push([gx, gy]);
        const dist = p => Math.pow(p[0] + w / s.width / 2 - 0.5, 2) + Math.pow(p[1] + h / s.height / 2 - 0.5, 2);
        c.sort((a, b) => dist(a) - dist(b));
        for (const p of c) {
            const r = { "x": p[0] * s.width, "y": p[1] * s.height };
            if (!rects.some(o => r.x < o.x + o.w + 20 && o.x < r.x + w + 20 && r.y < o.y + o.h + 20 && o.y < r.y + h + 20)) return p;
        }
        const n = list.length % 6 * 0.025;
        return [Math.max(0, 0.5 - w / s.width / 2) + n, Math.max(0.1, 0.5 - h / s.height / 2) + n];
    }
    function add(type) {
        const d = shell.widgetTypes[type];
        if (!d || !targetScreen) return;
        const p = freeSpot(d);
        const id = type + "-" + Date.now().toString(36);
        const w = { "id": id, "type": type, "scale": 1, "radius": shell.cfg.widgetRadius,
                    "x": Math.round(p[0] * 10000) / 10000, "y": Math.round(p[1] * 10000) / 10000 };
        if (shell.cfg.widgetStyle !== "auto") w.style = shell.cfg.widgetStyle;
        commit(list.concat([w]));
        selected = id;
        gallery = false;
    }

    // ---- choosing a picture (the editor steps aside while the file dialog is open)
    property string pickId: ""
    property string pickKey: ""
    function pickImage(id, k) { pickId = id; pickKey = k; picking = true; picker.running = true; }
    Process {
        id: picker
        command: ["sh", "-c", "start=\"$HOME/Pictures\"; [ -d \"$start\" ] || start=\"$HOME\"; " +
            "if command -v kdialog >/dev/null 2>&1; then kdialog --title 'Choose an image' --getopenfilename \"$start\" 'Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif *.svg)'; " +
            "elif command -v zenity >/dev/null 2>&1; then zenity --file-selection --title='Choose an image' --filename=\"$start/\"; fi"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p !== "") root.setOption(root.pickId, root.pickKey, p); } }
        onExited: root.picking = false
    }

    LazyLoader {
        active: root.open && !!root.targetScreen
        PanelWindow {
            id: win
            screen: root.targetScreen
            visible: !root.picking
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-editor"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            FocusScope {
                id: scope
                anchors.fill: parent; focus: true
                Keys.onEscapePressed: { if (root.typing) scope.forceActiveFocus(); else if (root.gallery) root.gallery = false; else if (root.customizing) root.customizing = false; else root.hide(); }
                Keys.onPressed: ev => {
                    if (root.typing) return;
                    if ((ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_Z) { if (ev.modifiers & Qt.ShiftModifier) root.redo(); else root.undo(); ev.accepted = true; }
                    else if ((ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_Y) { root.redo(); ev.accepted = true; }
                    else if ((ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_D && root.selected !== "") { root.duplicate(root.selected); ev.accepted = true; }
                    else if ((ev.key === Qt.Key_Delete || ev.key === Qt.Key_Backspace) && root.selected !== "") { root.remove(root.selected); ev.accepted = true; }
                }

                Item {
                    id: stage
                    anchors.fill: parent
                    readonly property real unit: height / 1080
                    property real guideX: -1
                    property real guideY: -1

                    // ---- the backdrop: your wallpaper (blurred like the lock screen on that tab)
                    Image {
                        id: wall
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: root.shell.wallpaperSource
                        sourceSize: Qt.size(stage.width, stage.height); visible: false; layer.enabled: false
                    }
                    MultiEffect {
                        anchors.fill: parent; source: wall
                        blurEnabled: root.tab === "lock"; blur: 1; blurMax: 56
                        Behavior on blur { NumberAnimation { duration: 300 } }
                    }
                    Rectangle { anchors.fill: parent; color: "black"; opacity: root.tab === "lock" ? 0.28 + root.shell.cfg.lockDim : Math.max(0.12, root.shell.cfg.wallDim) }
                    MouseArea { anchors.fill: parent; onClicked: { root.selected = ""; root.gallery = false; root.customizing = false; scope.forceActiveFocus(); } }

                    // ---- lock screen: the parts that always stay where they are
                    Item {
                        id: lockMock
                        anchors.fill: parent; opacity: root.tab === "lock" ? 1 : 0; visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        readonly property real cy: height * root.shell.cfg.lockClockY
                        readonly property real f: root.shell.lockFontPx
                        Text {
                            visible: root.shell.cfg.lockDate; anchors.horizontalCenter: parent.horizontalCenter
                            y: lockMock.cy - root.shell.stackGap - lockMock.f * 0.8
                            text: Qt.formatDateTime(new Date(), "dddd d MMMM"); color: root.pal.muted; opacity: 0.8
                            font { family: root.shell.clockFont; pixelSize: Math.max(14, lockMock.f * 0.2); weight: 500 }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: lockMock.cy - root.shell.stackGap - height / 2
                            text: Qt.formatDateTime(new Date(), "HH"); color: root.pal.text; opacity: 0.8; font { family: root.shell.clockFont; pixelSize: lockMock.f; weight: 600 } }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: lockMock.cy + root.shell.stackGap - height / 2
                            text: Qt.formatDateTime(new Date(), "mm"); color: root.pal.wsa; opacity: 0.8; font { family: root.shell.clockFont; pixelSize: lockMock.f; bold: true } }
                        Rectangle {
                            width: 240; height: 44; radius: 22; anchors.horizontalCenter: parent.horizontalCenter
                            y: lockMock.cy + lockMock.f * 1.35
                            color: Qt.rgba(0.176, 0.208, 0.231, 0.55); border.width: 1; border.color: root.pal.border
                            Text { anchors.centerIn: parent; text: "Password"; color: root.pal.text; opacity: 0.45; font { family: root.shell.clockFont; pixelSize: 14 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; y: lockMock.cy + lockMock.f * 1.35 + 60
                            text: "The clock and password field stay here"; color: root.pal.muted
                            font { family: root.pal.font; pixelSize: 12 }
                        }
                    }

                    // ---- guides
                    Rectangle { visible: stage.guideX >= 0; x: stage.guideX; y: 0; width: 1; height: stage.height; color: root.pal.accent; opacity: 0.8; z: 9 }
                    Rectangle { visible: stage.guideY >= 0; x: 0; y: stage.guideY; width: stage.width; height: 1; color: root.pal.accent; opacity: 0.8; z: 9 }

                    // ---- the widgets
                    Repeater {
                        model: root.list
                        delegate: Item {
                            id: ew
                            required property var modelData
                            readonly property var spec: modelData
                            readonly property var def: root.shell.widgetTypes[spec.type]
                            readonly property bool sel: root.selected === spec.id
                            readonly property bool hot: sel || hh.hovered || mv.pressed || rz.pressed
                            property real px: spec.x * stage.width
                            property real py: spec.y * stage.height
                            property real pscale: spec.scale
                            readonly property real k: pscale * stage.unit
                            visible: !!def
                            x: px; y: py; z: sel ? 6 : 2
                            width: def ? def.w * k : 0; height: def ? def.h * k : 0
                            Item { anchors.fill: parent; anchors.margins: -16; HoverHandler { id: hh } }
                            DesktopWidget {
                                spec: ew.spec; shell: root.shell; live: false; scale: ew.k; transformOrigin: Item.TopLeft
                                originX: ew.px; originY: ew.py; screenW: stage.width; screenH: stage.height
                            }
                            Rectangle {
                                anchors.fill: parent; anchors.margins: -3; radius: Math.max(10, (ew.spec.radius !== undefined ? ew.spec.radius : 26) * ew.k + 3); color: "transparent"
                                border.width: ew.hot ? 2 : 0; border.color: root.pal.accent
                            }
                            MouseArea {
                                id: mv
                                anchors.fill: parent; preventStealing: true; cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property point press
                                property point start
                                onPressed: m => { root.selected = ew.spec.id; root.gallery = false; scope.forceActiveFocus(); press = mapToItem(stage, m.x, m.y); start = Qt.point(ew.px, ew.py); }
                                onDoubleClicked: root.customizing = true
                                onPositionChanged: m => {
                                    if (!pressed) return;
                                    const p = mapToItem(stage, m.x, m.y);
                                    let nx = start.x + p.x - press.x, ny = start.y + p.y - press.y;
                                    const snap = 10, margin = 32;
                                    let gx = -1, gy = -1;
                                    if (Math.abs(nx + ew.width / 2 - stage.width / 2) < snap) { nx = stage.width / 2 - ew.width / 2; gx = stage.width / 2; }
                                    else if (Math.abs(nx - margin) < snap) { nx = margin; gx = margin; }
                                    else if (Math.abs(nx + ew.width - (stage.width - margin)) < snap) { nx = stage.width - margin - ew.width; gx = stage.width - margin; }
                                    if (Math.abs(ny + ew.height / 2 - stage.height / 2) < snap) { ny = stage.height / 2 - ew.height / 2; gy = stage.height / 2; }
                                    else if (Math.abs(ny - margin) < snap) { ny = margin; gy = margin; }
                                    else if (Math.abs(ny + ew.height - (stage.height - margin)) < snap) { ny = stage.height - margin - ew.height; gy = stage.height - margin; }
                                    ew.px = Math.max(0, Math.min(stage.width - ew.width, nx));
                                    ew.py = Math.max(0, Math.min(stage.height - ew.height, ny));
                                    stage.guideX = gx; stage.guideY = gy;
                                }
                                onReleased: finish()
                                onCanceled: finish()
                                function finish() {
                                    stage.guideX = -1; stage.guideY = -1;
                                    const nx = Math.round(ew.px / stage.width * 10000) / 10000, ny = Math.round(ew.py / stage.height * 10000) / 10000;
                                    if (nx !== ew.spec.x || ny !== ew.spec.y) root.update(ew.spec.id, { "x": nx, "y": ny });
                                    else { ew.px = Qt.binding(() => ew.spec.x * stage.width); ew.py = Qt.binding(() => ew.spec.y * stage.height); }
                                }
                            }
                            Rectangle {
                                visible: ew.hot && !mv.pressed
                                width: 24; height: 24; radius: 12; x: ew.width - 12; y: -12; z: 3
                                color: xm.containsMouse ? root.pal.red : Qt.rgba(root.pal.bg.r, root.pal.bg.g, root.pal.bg.b, 0.92)
                                border.width: 1; border.color: root.pal.border
                                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "×"; color: root.pal.text; font { pixelSize: 16; weight: 700 } }
                                MouseArea { id: xm; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.remove(ew.spec.id) }
                            }
                            Rectangle {
                                visible: ew.hot
                                width: 22; height: 22; radius: 11; x: ew.width - 11; y: ew.height - 11; z: 3
                                color: root.pal.accent
                                Text { anchors.centerIn: parent; text: "↘"; color: root.pal.onAccent; font { pixelSize: 13; weight: 700 } }
                                MouseArea {
                                    id: rz
                                    anchors.fill: parent; anchors.margins: -6; preventStealing: true; cursorShape: Qt.SizeFDiagCursor
                                    property real startX
                                    property real startW
                                    property real startScale
                                    onPressed: m => { root.selected = ew.spec.id; startX = mapToItem(stage, m.x, m.y).x; startW = ew.width; startScale = ew.pscale; }
                                    onPositionChanged: m => {
                                        if (!pressed) return;
                                        const w = Math.max(48, startW + mapToItem(stage, m.x, m.y).x - startX);
                                        ew.pscale = Math.max(0.3, Math.min(4, startScale * w / startW));
                                    }
                                    onReleased: root.update(ew.spec.id, { "scale": Math.round(ew.pscale * 100) / 100 })
                                    onCanceled: root.update(ew.spec.id, { "scale": Math.round(ew.pscale * 100) / 100 })
                                }
                            }
                        }
                    }

                    // ---- top bar
                    Row {
                        anchors { top: parent.top; topMargin: 22; left: parent.left; leftMargin: 28 }
                        spacing: 8; z: 20
                        Repeater {
                            model: [{ "g": 0xF054C, "act": "undo" }, { "g": 0xF044E, "act": "redo" }]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool can: modelData.act === "undo" ? root.undoCount > 0 : root.redoCount > 0
                                width: 40; height: 36; radius: 18
                                color: um.containsMouse && can ? Qt.rgba(root.pal.accent.r, root.pal.accent.g, root.pal.accent.b, 0.3) : Qt.rgba(root.pal.bg.r, root.pal.bg.g, root.pal.bg.b, 0.85)
                                border.width: 1; border.color: root.pal.border; opacity: can ? 1 : 0.4
                                Text { anchors.centerIn: parent; text: String.fromCodePoint(modelData.g); color: root.pal.text; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 17 } }
                                MouseArea { id: um; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act === "undo" ? root.undo() : root.redo() }
                            }
                        }
                    }
                    HSegment {
                        anchors { top: parent.top; topMargin: 22; horizontalCenter: parent.horizontalCenter }
                        z: 20; options: ["Desktop", "Lock screen"]; segWidth: 120
                        current: root.tab === "home" ? 0 : 1
                        onPicked: i => { root.tab = i === 0 ? "home" : "lock"; root.selected = ""; root.customizing = false; root.gallery = false; }
                    }
                    Row {
                        anchors { top: parent.top; topMargin: 22; right: parent.right; rightMargin: 28 }
                        spacing: 8; z: 20
                        HButton { label: "Clear"; onClicked: root.commit([]) }
                        HButton { label: "Done"; primary: true; onClicked: root.hide() }
                    }
                    Text {
                        anchors { top: parent.top; topMargin: 70; horizontalCenter: parent.horizontalCenter }
                        text: root.list.length === 0 ? "Press Add widget to start." : "Drag to move. Pull a corner to resize. Double-click a widget to customize it."
                        color: Qt.rgba(1, 1, 1, 0.7); font { family: root.pal.font; pixelSize: 13 }
                    }

                    // ---- the Customize panel
                    WidgetDrawer {
                        editor: root
                        visible: root.customizing && !!root.selectedSpec
                        z: 20; x: stage.width - width - 24; y: 100; height: Math.min(600, stage.height - 100 - 170)
                    }

                    // ---- bottom: the gallery, the settings of the selected widget, and the Add button
                    Column {
                        anchors { bottom: parent.bottom; bottomMargin: 26; horizontalCenter: parent.horizontalCenter }
                        spacing: 12; z: 20

                        Rectangle {
                            visible: root.gallery
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: galleryGrid.width + 32; height: galleryGrid.height + 32; radius: 28
                            color: Qt.rgba(root.pal.bg.r, root.pal.bg.g, root.pal.bg.b, 0.95); border.width: 1; border.color: root.pal.border
                            Grid {
                                id: galleryGrid
                                anchors.centerIn: parent; columns: 4; spacing: 10
                                Repeater {
                                    model: root.shell.widgetOrder
                                    delegate: Rectangle {
                                        id: card
                                        required property string modelData
                                        readonly property var d: root.shell.widgetTypes[modelData]
                                        width: 150; height: 92; radius: 20
                                        color: gm.containsMouse ? Qt.rgba(root.pal.accent.r, root.pal.accent.g, root.pal.accent.b, 0.22) : Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, 0.06)
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text { x: 16; y: 14; text: String.fromCodePoint(card.d.glyph); color: root.pal.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 } }
                                        Text { x: 16; y: 46; text: card.d.label; color: root.pal.text; font { family: root.pal.font; pixelSize: 13; weight: 700 } }
                                        Text { x: 16; y: 66; width: parent.width - 24; elide: Text.ElideRight; text: card.d.desc; color: root.pal.muted; font { family: root.pal.font; pixelSize: 11 } }
                                        MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.add(card.modelData) }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: inspector
                            visible: !!root.selectedSpec
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: inspRow.width + 36; height: 54; radius: 27
                            color: Qt.rgba(root.pal.bg.r, root.pal.bg.g, root.pal.bg.b, 0.94); border.width: 1; border.color: root.pal.border
                            Row {
                                id: inspRow
                                anchors.centerIn: parent; spacing: 18
                                Text { anchors.verticalCenter: parent.verticalCenter; text: root.selectedSpec ? (root.shell.widgetTypes[root.selectedSpec.type] || { "label": "" }).label : ""
                                    color: root.pal.text; font { family: root.pal.font; pixelSize: 13; weight: 700 } }
                                HSegment {
                                    anchors.verticalCenter: parent.verticalCenter
                                    options: root.defs.styles.map(s => s[1]); segWidth: 56
                                    current: { const st = root.selectedSpec ? root.defs.val(root.selectedSpec, "style") : "plain"; return Math.max(0, root.defs.styles.findIndex(s => s[0] === st)); }
                                    onPicked: i => root.setOption(root.selected, "style", root.defs.styles[i][0])
                                }
                                Row { spacing: 8; anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Size"; color: root.pal.muted; font { family: root.pal.font; pixelSize: 12 } }
                                    HSlider { anchors.verticalCenter: parent.verticalCenter; width: 140; from: 0.3; to: 3; value: root.selectedSpec ? root.selectedSpec.scale : 1
                                        onMoved: v => root.setOption(root.selected, "scale", Math.round(v * 100) / 100) } }
                                HButton { anchors.verticalCenter: parent.verticalCenter; label: "Customize"; primary: root.customizing; onClicked: root.customizing = !root.customizing }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: addRow.width + 40; height: 50; radius: 25
                            color: root.gallery || addm.containsMouse ? root.pal.accent : Qt.rgba(root.pal.bg.r, root.pal.bg.g, root.pal.bg.b, 0.94)
                            border.width: 1; border.color: root.pal.border
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Row {
                                id: addRow; anchors.centerIn: parent; spacing: 8
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "+"; color: root.gallery || addm.containsMouse ? root.pal.onAccent : root.pal.accent; font { pixelSize: 22; weight: 600 } }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Add widget"; color: root.gallery || addm.containsMouse ? root.pal.onAccent : root.pal.text; font { family: root.pal.font; pixelSize: 14; weight: 700 } }
                            }
                            MouseArea { id: addm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gallery = !root.gallery }
                        }
                    }
                }
            }
        }
    }
}
