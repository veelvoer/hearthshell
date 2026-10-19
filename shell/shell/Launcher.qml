// qmllint disable
import Quickshell
import Quickshell.Wayland
import QtQuick

// Built-in app launcher: type to filter, arrows to move, Enter to start. Opens centred, with the same spring as the island.
PanelWindow {
    id: win
    required property var shell
    readonly property bool wanted: shell.launcherOpen && shell.overlayScreen === (screen ? screen.name : "")
    property real k: wanted ? 1 : 0
    Behavior on k { NumberAnimation { duration: main.ms(wanted ? 520 : 260); easing.type: wanted ? Easing.BezierSpline : Easing.OutCubic; easing.bezierCurve: [0.34, 1.18, 0.64, 1, 1, 1] } }

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: wanted || k > 0.005
    mask: Region { item: (wanted || k > 0.005) ? hit : null }

    property string query: ""
    property int sel: 0
    readonly property var all: {
        const out = [];
        for (const e of DesktopEntries.applications.values) if (!e.noDisplay) out.push(e);
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "") return all.slice(0, 60);
        const scored = [];
        for (const e of all) {
            const n = e.name.toLowerCase();
            let s = -1;
            if (n.startsWith(q)) s = 0;
            else if (n.includes(" " + q)) s = 1;
            else if (n.includes(q)) s = 2;
            else if ((e.genericName || "").toLowerCase().includes(q) || (e.keywords || []).join(" ").toLowerCase().includes(q)) s = 3;
            if (s >= 0) scored.push({ "e": e, "s": s });
        }
        scored.sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name));
        return scored.slice(0, 60).map(x => x.e);
    }
    onWantedChanged: { if (wanted) { query = ""; sel = 0; input.text = ""; input.forceActiveFocus(); } }
    onResultsChanged: sel = 0
    function launch(e) { if (!e) return; shell.launcherOpen = false; e.execute(); }

    Item { id: hit; anchors.fill: parent; MouseArea { anchors.fill: parent; onClicked: win.shell.launcherOpen = false } }

    Rectangle {
        id: card
        width: 560
        height: 76 + Math.min(list.contentHeight, 8 * 52) + (list.count > 0 ? 14 : 0)
        Behavior on height { NumberAnimation { duration: main.ms(300); easing.type: Easing.OutCubic } }
        x: (parent.width - width) / 2
        y: parent.height * 0.2
        radius: Math.min(26, shell.cfg.barRadius + 11)
        color: Qt.alpha(main.bg, main.menuAlpha)
        border.width: 1; border.color: main.border
        opacity: Math.min(1, win.k * 1.8)
        scale: 0.94 + 0.06 * win.k
        transformOrigin: Item.Top
        clip: true
        MouseArea { anchors.fill: parent }

        Text {
            x: 22; y: 22; text: String.fromCodePoint(0xF0349); color: main.accent
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 }
        }
        TextInput {
            id: input
            x: 58; y: 20; width: parent.width - 80; height: 32
            color: main.text; font { family: main.font; pixelSize: 18 }
            selectByMouse: true; clip: true
            onTextChanged: win.query = text
            Keys.onEscapePressed: win.shell.launcherOpen = false
            Keys.onDownPressed: win.sel = Math.min(win.results.length - 1, win.sel + 1)
            Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
            Keys.onReturnPressed: win.launch(win.results[win.sel])
            Keys.onEnterPressed: win.launch(win.results[win.sel])
            Text { visible: input.text === ""; text: "Search apps"; color: main.muted; font: input.font; opacity: 0.7 }
        }
        Rectangle { x: 18; y: 64; width: parent.width - 36; height: 1; color: main.line; visible: list.count > 0 }
        ListView {
            id: list
            x: 10; y: 70; width: parent.width - 20; height: Math.min(contentHeight, 8 * 52)
            model: win.visible ? win.results : []; clip: true; spacing: 0; currentIndex: win.sel
            highlightMoveDuration: 140
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width; height: 52; radius: 14
                color: index === win.sel ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.20) : (rm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07) : "transparent")
                Behavior on color { ColorAnimation { duration: main.ms(120) } }
                Image {
                    x: 12; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30
                    source: Quickshell.iconPath(modelData.icon, "application-x-executable"); sourceSize: Qt.size(60, 60)
                    asynchronous: true; smooth: true
                }
                Column {
                    x: 54; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.name; color: main.text; font { family: main.font; pixelSize: 14; weight: 600 } }
                    Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: modelData.comment || modelData.genericName || ""; color: main.muted; font { family: main.font; pixelSize: 11 } }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; onEntered: win.sel = index; onClicked: win.launch(modelData) }
            }
        }
        Text {
            visible: input.text !== "" && win.results.length === 0
            anchors.horizontalCenter: parent.horizontalCenter; y: 74; text: "No apps match"; color: main.muted
            font { family: main.font; pixelSize: 13 }
        }
    }
}
