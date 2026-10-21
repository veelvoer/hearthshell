// qmllint disable
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Settings overlay: one per screen, shown on the focused monitor.
PanelWindow {
    id: win
    required property var shell
    property bool wanted: false
    property int page: 0
    readonly property var cfg: shell.cfg
    function put(key, value) { shell.set(key, value); }
    // what each page is about, for the search box (the page names themselves always count)
    readonly property var pageWords: [
        "theme colour color wallpaper preset look accent text font background",
        "creator custom theme make extract palette",
        "bar island style top bottom opacity roundness height gap clock seconds 24 hour calendar monday icons drawn workspace dots pills numbers split three pieces bounce spring",
        "modules launcher volume brightness network bluetooth battery media notifications bell power quick text hover labels",
        "windows gaps border corner rounding inactive opacity focus shadow",
        "input mouse touchpad keyboard scroll natural tap speed repeat",
        "glass frosted blur transparent terminal browser files editors",
        "system kitty fish rofi gtk hyprlock firefox yazi dolphin cava micro lodica terminal lock screen",
        "control center tiles wifi bluetooth audio quiet night light volume brightness media order",
        "notifications popups quiet do not disturb timeout daemon mako dunst",
        "shortcuts keys keybind hotkey bind control center theme wallpaper calendar launcher power lock super alt",
        "desktop home lock screen widgets clock calendar media notes system customize edit layout wallpaper",
        "updates update version github upgrade new release check restore backup",
        "about shortcuts reset defaults keys"]
    property string query: ""
    // the sidebar groups the pages; page numbers stay as they are, only the order they are shown in changes
    // what the current setup is, so a setting that makes no sense here can stay out of sight
    readonly property bool isIsland: cfg.barStyle === "island"
    readonly property bool isPill: cfg.barStyle === "pill" || cfg.barStyle === "island"
    readonly property bool dash: isIsland && cfg.islandPanel && !cfg.islandSplit
    function hasMod(id) { const m = cfg.modules || ({}); return (m.left || []).indexOf(id) >= 0 || (m.center || []).indexOf(id) >= 0 || (m.right || []).indexOf(id) >= 0; }
    readonly property var navOrder: [0, 1, 6, 2, 3, 8, 9, 11, 4, 5, 7, 10, 12, 13]
    readonly property var navGroups: [{ "label": "Look", "from": 0 }, { "label": "Shell", "from": 3 }, { "label": "System", "from": 8 }, { "label": "App", "from": 12 }]
    function groupOf(pos) { let g = 0; for (let i = 0; i < navGroups.length; i++) if (navGroups[i].from <= pos) g = i; return g; }
    function navY(page) { const pos = navOrder.indexOf(page); return 84 + pos * 34 + groupOf(pos) * 26; }
    function navStep(d) { const n = navOrder.length; return navOrder[(navOrder.indexOf(page) + d + n) % n]; }
    readonly property var pageIcons: [0xF03D8, 0xF0A1F, 0xF0572, 0xF003B, 0xF05B1, 0xF037D, 0xF05CC, 0xF0493, 0xF0570, 0xF009A, 0xF030C, 0xF0379, 0xF06B0, 0xF02FD]
    onWantedChanged: if (!wanted) { query = ""; search.text = ""; }
    function matches(i) {
        const q = query.trim().toLowerCase();
        return q === "" || pages[i].toLowerCase().indexOf(q) >= 0 || pageWords[i].indexOf(q) >= 0;
    }
    // ---- searching individual settings: every row registers itself here when it is created
    property var rowList: []
    property var results: []
    property int pendingScroll: 0
    function registerRow(row, page, pageItem) { rowList.push({ "row": row, "page": page, "pageItem": pageItem }); }
    function ancestors(row) {
        const out = []; let p = row.parent;
        while (p) { out.push(p); if (p.isSettingsPage === true) break; p = p.parent; }
        return out;
    }
    function usable(entry) {
        try {
            const r = entry.row;
            if (!r || r.available === false) return false;
            for (const a of ancestors(r)) if (a.available === false) return false;
            return true;
        } catch (e) { return false; }
    }
    function cardTitle(row) { for (const a of ancestors(row)) if (a.title !== undefined && a.collapsible !== undefined) return a.title; return ""; }
    function runSearch() {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0) { results = []; return; }
        const out = [];
        for (let i = 0; i < pages.length; i++) {
            const hay = pages[i].toLowerCase() + " " + pageWords[i];
            if (words.every(w => hay.indexOf(w) >= 0)) out.push({ "kind": "page", "page": i, "label": pages[i], "sub": "Page", "desc": "" });
        }
        const seen = {};
        for (const e of rowList) {
            if (!usable(e)) continue;
            const r = e.row;
            const hay = (r.label + " " + r.desc + " " + r.keywords + " " + pages[e.page] + " " + cardTitle(r)).toLowerCase();
            if (!words.every(w => hay.indexOf(w) >= 0)) continue;
            const key = e.page + "|" + r.label;
            if (seen[key]) continue;
            seen[key] = true;
            const ct = cardTitle(r);
            out.push({ "kind": "row", "page": e.page, "label": r.label, "sub": pages[e.page] + (ct !== "" ? "  ›  " + ct : ""), "desc": r.desc, "row": r, "pageItem": e.pageItem });
        }
        results = out.slice(0, 40);
    }
    onQueryChanged: runSearch()
    function goTo(res) {
        query = ""; search.text = "";
        page = res.page;
        if (res.kind === "row") {
            for (const a of ancestors(res.row)) if (a.collapsible === true) a.expanded = true;
            scrollTarget = res;
            scrollTimer.restart();
        }
    }
    property var scrollTarget: null
    Timer { id: scrollTimer; interval: 420
        onTriggered: {
            const t = win.scrollTarget; if (!t) return;
            win.scrollTarget = null;
            try {
                const y = t.row.mapToItem(t.pageItem.contentItem, 0, 0).y;
                t.pageItem.contentY = Math.max(0, Math.min(Math.max(0, t.pageItem.contentHeight - t.pageItem.height), y - 90));
                t.row.flash();
            } catch (e) { }
        } }
    function firstMatch() { for (let i = 0; i < pages.length; i++) if (matches(i)) return i; return -1; }
    readonly property var pages: ["Appearance", "Creator", "Bar & Island", "Modules", "Windows", "Input", "Glass", "System", "Control Center", "Notifications", "Shortcuts", "Desktop", "Updates", "About"]
    property bool typing: false
    property bool accentPicker: false
    property string presetName: ""
    property string confirmDelete: ""
    readonly property var customIds: shell.themeList.order.filter(id => shell.themeList.data[id].custom)

    // ---- theme creator draft ----
    property string draftName: ""
    property int editIdx: 2
    property var draft: ({ "bg": "#1e1e2e", "text": "#cdd6f4", "accent": "#cba6f7", "accent2": "#89b4fa", "muted": "#45475a" })
    readonly property var colorKeys: [["bg", "Background"], ["text", "Text"], ["accent", "Accent"], ["accent2", "Accent 2"], ["muted", "Muted"]]
    function setDraft(key, value) { const d = Object.assign({}, draft); d[key] = String(value); draft = d; }
    function copyCurrent() {
        const t = shell.themeList.data[cfg.theme];
        draft = { "bg": t.bg, "text": t.text, "accent": t.wsa, "accent2": t.icon, "muted": t.wso };
    }
    readonly property var ease: [0.2, 0.8, 0.2, 1, 1, 1]

    color: "transparent"
    // The bar stays visible and usable while you edit it: the dimming starts below it (or above it when the
    // bar is at the bottom), and clicks in the bar's strip go to the bar.
    readonly property bool barBottom: shell.cfg.barPos === "bottom"
    readonly property real barZone: shell.barTopMargin + shell.barHeight + 10
    property real scrimK: wanted ? 0.5 : 0
    Behavior on scrimK { NumberAnimation { duration: main.ms(280); easing.type: Easing.OutCubic } }
    visible: wanted || scrimK > 0.005
    mask: Region { item: inputArea }
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        id: inputArea
        x: 0; width: parent.width
        y: win.barBottom ? 0 : win.barZone
        height: parent.height - win.barZone
    }
    // Nothing around the panel changes while it is open (no dimming, no blur): this only catches clicks outside it.
    Item {
        id: scrim
        x: 0; width: parent.width; y: inputArea.y; height: inputArea.height
        MouseArea { anchors.fill: parent; onClicked: win.shell.closeSettings() }
    }

    FocusScope {
        anchors.fill: parent
        focus: win.wanted
        id: keyScope
        Keys.onEscapePressed: { if (win.typing) { keyScope.forceActiveFocus(); } else { win.shell.closeSettings(); } }
        Keys.onPressed: ev => {
            if (win.typing) return;
            if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab) { win.page = win.navStep(1); ev.accepted = true; }
            else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) { win.page = win.navStep(-1); ev.accepted = true; }
            else if (ev.key === Qt.Key_Slash || (ev.key === Qt.Key_F && (ev.modifiers & Qt.ControlModifier))) { search.focusInput(); ev.accepted = true; }
        }

        Rectangle {
            id: panel
            width: Math.min(880, parent.width - 60)
            height: Math.min(700, parent.height - win.barZone - 40)
            x: (parent.width - width) / 2
            y: (win.barBottom ? 0 : win.barZone) + (parent.height - win.barZone - height) / 2
            radius: 24; color: Qt.rgba(main.panelBase.r, main.panelBase.g, main.panelBase.b, main.panelAlpha)
            Behavior on color { ColorAnimation { duration: main.ms(260) } }
            border.width: 1; border.color: main.line
            opacity: win.wanted ? 1 : 0
            scale: win.wanted ? 1 : 0.96
            transform: Translate { y: win.wanted ? 0 : 14
                Behavior on y { NumberAnimation { duration: main.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } } }
            Behavior on opacity { NumberAnimation { duration: win.wanted ? 260 : 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: main.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } }
            MouseArea { anchors.fill: parent }   // swallow clicks

            // ---------------- sidebar ----------------
            Item {
                id: nav
                x: 0; y: 0; width: 210; height: parent.height
                HInput {
                    id: search
                    x: 14; y: 14; width: nav.width - 28; height: 34
                    placeholder: "Search settings"
                    onEdited: v => win.query = v
                    onSubmitted: v => { if (win.results.length > 0) win.goTo(win.results[0]); }
                    onTypingChanged: win.typing = typing
                }
                Rectangle {   // sliding selection pill
                    x: 14; width: nav.width - 28; height: 34; radius: 12
                    y: win.navY(win.page) - 1
                    color: main.card
                    Behavior on y { NumberAnimation { duration: main.ms(340); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } }
                }
                Repeater {
                    model: win.navGroups
                    Text {
                        required property var modelData
                        x: 26; y: win.navY(win.navOrder[modelData.from]) - 22
                        text: modelData.label.toUpperCase(); color: main.muted
                        font { family: main.font; pixelSize: 10; weight: 700; letterSpacing: 1.2 }
                    }
                }
                Repeater {
                    model: win.pages
                    Item {
                        required property int index
                        required property string modelData
                        x: 14; y: win.navY(index); width: nav.width - 28; height: 32
                        IconTile {
                            x: 8; anchors.verticalCenter: parent.verticalCenter; size: 26; round: true; filled: win.page === index
                            glyph: String.fromCodePoint(win.pageIcons[index])
                            tint: win.page === index ? main.tone(index) : main.text
                            Behavior on tint { ColorAnimation { duration: main.ms(180) } }
                        }
                        Text {
                            x: 44; anchors.verticalCenter: parent.verticalCenter; text: modelData
                            color: win.page === index || hover.containsMouse ? main.text : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.82)
                            Behavior on color { ColorAnimation { duration: main.ms(180) } }
                            font { family: main.font; pixelSize: 14; weight: 600 }
                        }
                        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.page = index }
                    }
                }
                Text {
                    x: 28; anchors.bottom: parent.bottom; anchors.bottomMargin: 26
                    text: "Esc to close"; color: main.muted; font { family: main.font; pixelSize: 12 }
                }
            }
            Rectangle {
                x: nav.width; y: 16; width: 1; height: parent.height - 32
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.12; color: main.line }
                    GradientStop { position: 0.88; color: main.line }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // ---------------- pages ----------------
            Item {
                id: content
                x: nav.width + 1; width: parent.width - x; height: parent.height

                // search results replace the page while you type
                Rectangle {
                    id: resultsView
                    z: 12; x: 0; y: 50; width: parent.width; height: parent.height - 50 - 14
                    visible: win.query.trim() !== ""
                    color: Qt.rgba(main.panelBase.r, main.panelBase.g, main.panelBase.b, 1)
                    Text { visible: win.results.length === 0; x: 32; y: 20; text: "Nothing matches \"" + win.query.trim() + "\""; color: main.muted; font { family: main.font; pixelSize: 14 } }
                    Flickable {
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                        contentWidth: width; contentHeight: resCol.height + 20; clip: true; boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: resCol; width: parent.width; spacing: 4
                            Repeater {
                                model: win.results
                                delegate: Rectangle {
                                    id: rr
                                    required property var modelData
                                    required property int index
                                    width: resCol.width; height: rcol.height + 20; radius: 14
                                    color: rm.containsMouse || index === 0 ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07) : "transparent"
                                    Behavior on color { ColorAnimation { duration: main.ms(120) } }
                                    IconTile { x: 8; anchors.verticalCenter: parent.verticalCenter; size: 32; round: true
                                        glyph: String.fromCodePoint(win.pageIcons[rr.modelData.page]); tint: main.tone(rr.modelData.page) }
                                    Column {
                                        id: rcol; x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52 - 12; spacing: 2
                                        Text { width: parent.width; elide: Text.ElideRight; text: rr.modelData.label; color: main.text; font { family: main.font; pixelSize: 14; weight: 600 } }
                                        Text { width: parent.width; elide: Text.ElideRight; text: rr.modelData.sub; color: main.accent; font { family: main.font; pixelSize: 11; weight: 600 } }
                                        Text { visible: rr.modelData.desc !== ""; width: parent.width; elide: Text.ElideRight; text: rr.modelData.desc; color: main.muted; font { family: main.font; pixelSize: 11 } }
                                    }
                                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.goTo(rr.modelData) }
                                }
                            }
                        }
                    }
                }

                // soft edges where scrolled content meets the header and the bottom of the panel
                Rectangle {
                    z: 8; x: 0; y: 50; width: parent.width; height: 16
                    gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(main.panelBase.r, main.panelBase.g, main.panelBase.b, main.panelAlpha) } GradientStop { position: 1; color: Qt.rgba(main.panelBase.r, main.panelBase.g, main.panelBase.b, 0) } }
                }
                Rectangle {
                    z: 8; x: 0; width: parent.width; height: 26; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                    gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(main.panelBase.r, main.panelBase.g, main.panelBase.b, 0) } GradientStop { position: 1; color: Qt.rgba(main.panelBase.r, main.panelBase.g, main.panelBase.b, main.panelAlpha) } }
                }

                component Page: Flickable {
                    id: pg
                    required property int idx
                    property string heading: ""
                    property string sub: ""
                    default property alias items: stack.data
                    readonly property bool isSettingsPage: true
                    function registerRow(r) { win.registerRow(r, idx, pg); }
                    readonly property bool current: win.page === idx
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: parent.top; topMargin: 50; bottomMargin: 14 }
                    clip: true
                    contentWidth: width; contentHeight: stack.y + stack.height + 32
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    onCurrentChanged: if (current) contentY = 0     // every page opens at its top
                    visible: opacity > 0.01
                    opacity: current && win.wanted ? 1 : 0
                    transform: Translate {
                        x: pg.current ? 0 : (win.page > pg.idx ? -28 : 28)
                        Behavior on x { NumberAnimation { duration: main.ms(420); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } }
                    }
                    Behavior on opacity { NumberAnimation { duration: main.ms(240); easing.type: Easing.OutCubic } }
                    Item {
                        x: 32; y: 4; width: pg.width - 64; height: 56
                        IconTile { x: 2; anchors.verticalCenter: parent.verticalCenter; size: 40; round: true; tint: main.tone(pg.idx); glyph: String.fromCodePoint(win.pageIcons[pg.idx]) }
                        Text { x: 56; y: 8; text: pg.heading; color: main.text; font { family: main.font; pixelSize: 17; weight: 700 } }
                        Text { x: 56; y: 32; width: parent.width - 56; elide: Text.ElideRight; text: pg.sub; color: main.muted; font { family: main.font; pixelSize: 12 } }
                    }
                    Column { id: stack; x: 32; y: 76; width: pg.width - 64; spacing: 12 }
                }

                Row {
                    z: 10; x: 32; y: 14; spacing: 8
                    Repeater {
                        model: [{ "t": "‹", "d": -1 }, { "t": "›", "d": 1 }]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool can: win.navOrder.indexOf(win.page) + modelData.d >= 0 && win.navOrder.indexOf(win.page) + modelData.d < win.navOrder.length
                            width: 26; height: 26; radius: 13
                            color: nm.containsMouse && can ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.16) : main.card
                            opacity: can ? 1 : 0.4
                            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: modelData.t; color: main.text; font { family: main.font; pixelSize: 16; weight: 600 } }
                            MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (can) win.page = win.navOrder[win.navOrder.indexOf(win.page) + modelData.d] }
                        }
                    }
                }

                // ===== Appearance =====
                Page {
                    idx: 0; heading: "Appearance"; sub: "Pick a theme. Colours, wallpaper and your apps change together."
                    HCard {
                        id: themeCard
                        active: win.page === 0 && win.wanted; order: 0; title: "Theme"
                        Grid {
                            columns: 4; spacing: 10
                            width: parent.width
                            Repeater {
                                model: win.shell.themeList.order
                                ThemeTile {
                                    required property string modelData
                                    themeId: modelData
                                    info: win.shell.themeList.data[modelData]
                                    selected: win.cfg.theme === modelData
                                    width: (themeCard.width - themeCard.padding * 2 - 30) / 4
                                    onPicked: win.shell.setTheme(modelData)
                                }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 0 && win.wanted; order: 1; title: "Quick looks"; collapsible: true
                        Column {
                            width: parent.width; spacing: 10
                            Flow {
                                width: parent.width; spacing: 10
                                Repeater {
                                    model: win.shell.looks
                                    LookCard {
                                        required property var modelData
                                        name: modelData.name; desc: modelData.desc
                                        width: (parent.width - 30) / 4
                                        onPicked: win.shell.applyLook(modelData.id)
                                    }
                                }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap; color: main.muted
                                text: "A look sets the bar, spacing, corners and effects in one go. You can still change anything afterwards."
                                font { family: main.font; pixelSize: 12 }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 0 && win.wanted; order: 2; title: "My presets"; collapsible: true
                        Column {
                            width: parent.width; spacing: 12
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap; color: main.muted
                                text: "Save everything you have set up (theme, bar, modules, windows, glass, fonts) under a name and switch back to it any time."
                                font { family: main.font; pixelSize: 12 }
                            }
                            Row {
                                spacing: 10; width: parent.width
                                HInput {
                                    id: presetInput; width: parent.width - 10 - 130; placeholder: "Preset name"
                                    text: win.presetName
                                    onEdited: v => win.presetName = v
                                    onSubmitted: v => { if (win.shell.savePreset(v)) win.presetName = ""; }
                                    onTypingChanged: win.typing = typing
                                }
                                HButton { label: "Save current"; primary: true; onClicked: { if (win.shell.savePreset(win.presetName)) win.presetName = ""; } }
                            }
                            Text {
                                visible: win.shell.presetList.length === 0; color: main.muted
                                text: "No presets yet."; font { family: main.font; pixelSize: 13 }
                            }
                            Repeater {
                                model: win.shell.presetList
                                HRow {
                                    id: prow
                                    required property var modelData
                                    readonly property var tinfo: win.shell.themeList.data[modelData.data.theme]
                                    label: modelData.name
                                    desc: (tinfo ? tinfo.name : "Theme") + "  ·  " + (modelData.data.barStyle || "classic") + " bar"
                                    Row {
                                        spacing: 8
                                        HButton { label: "Apply"; primary: true; onClicked: win.shell.applyPreset(prow.modelData.name) }
                                        HButton { label: "Update"; onClicked: win.shell.savePreset(prow.modelData.name) }
                                        HButton {
                                            label: win.confirmDelete === prow.modelData.name ? "Sure?" : "Delete"
                                            onClicked: {
                                                if (win.confirmDelete === prow.modelData.name) { win.confirmDelete = ""; win.shell.deletePreset(prow.modelData.name); }
                                                else { win.confirmDelete = prow.modelData.name; confirmTimer.restart(); }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 0 && win.wanted; order: 3; title: "Accent and text"
                        Column {
                            width: parent.width; spacing: 14
                            Text { text: "Accent colour"; color: main.text; font { family: main.font; pixelSize: 14; weight: 600 } }
                            AccentChips {
                                width: parent.width; value: win.cfg.accent
                                onPicked: c => { win.accentPicker = false; win.put("accent", c); }
                                onCustomRequested: win.accentPicker = !win.accentPicker
                            }
                            Item {
                                width: parent.width; height: win.accentPicker ? 80 : 0; clip: true
                                opacity: win.accentPicker ? 1 : 0
                                Behavior on height { NumberAnimation { duration: main.ms(280); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } }
                                Behavior on opacity { NumberAnimation { duration: main.ms(220) } }
                                HColorPicker {
                                    y: 6; width: 300
                                    value: win.cfg.accent !== "" ? win.cfg.accent : main.accent
                                    onPicked: c => win.put("accent", String(c))
                                }
                            }
                            HRow { label: "Color burst"; desc: "A different palette colour for each surface instead of one accent"
                                HToggle { checked: win.cfg.colorBurst; onToggled: v => win.put("colorBurst", v) } }
                            Text { text: "Font"; color: main.text; font { family: main.font; pixelSize: 14; weight: 600 } }
                            FontChips { width: parent.width; value: win.cfg.font; onPicked: f => win.put("font", f) }
                            HRow {
                                label: "Animations"; desc: "Speed of every animation. Off also switches off window animations."
                                HSegment {
                                    readonly property var keys: ["off", "relaxed", "normal", "snappy"]
                                    options: ["Off", "Relaxed", "Normal", "Snappy"]; segWidth: 68
                                    current: Math.max(0, keys.indexOf(win.cfg.motion))
                                    onPicked: i => win.put("motion", keys[i])
                                }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 0 && win.wanted; order: 3; title: "Colours of the shell"
                        Column {
                            width: parent.width; spacing: 0
                            ColorOverride { label: "Bar and island"; value: win.cfg.barColor; themeColor: main.bg; onPicked: c => win.put("barColor", c) }
                            ColorOverride { label: "Settings and menus"; value: win.cfg.panelColor; themeColor: main.page; onPicked: c => win.put("panelColor", c) }
                        }
                    }
                    HCard {
                        active: win.page === 0 && win.wanted; order: 4; title: "Wallpaper"
                        Column {
                            width: parent.width; spacing: 12
                            Flow {
                                width: parent.width; spacing: 10
                                Repeater {
                                    model: win.shell.wallCount(win.cfg.theme)
                                    Item {
                                        id: wp
                                        required property int index
                                        readonly property bool sel: win.shell.wallIndex === index + 1
                                        width: 128; height: 72
                                        scale: wm.pressed ? 0.96 : 1
                                        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
                                        Image {
                                            id: wimg; anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop
                                            sourceSize: Qt.size(320, 180); visible: false; layer.enabled: true
                                            source: Qt.resolvedUrl("wallpapers/" + win.cfg.theme + "/" + (index + 1) + ".jpg")
                                        }
                                        Item { id: wmask; anchors.fill: parent; visible: false; layer.enabled: true
                                            Rectangle { anchors.fill: parent; radius: 12 } }
                                        MultiEffect {
                                            anchors.fill: parent; source: wimg; maskEnabled: true; maskSource: wmask
                                            opacity: wimg.status === Image.Ready ? (wp.sel || wm.containsMouse ? 1 : 0.8) : 0
                                            Behavior on opacity { NumberAnimation { duration: main.ms(200) } }
                                        }
                                        Rectangle {
                                            anchors.fill: parent; radius: 12; color: "transparent"
                                            border.width: wp.sel ? 2 : 1; border.color: wp.sel ? main.accent : main.line
                                            Behavior on border.color { ColorAnimation { duration: main.ms(180) } }
                                        }
                                        MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: win.shell.setWallpaper(index + 1) }
                                    }
                                }
                            }
                            Row {
                                spacing: 10
                                HButton { label: "Shuffle"; onClicked: win.shell.shuffleWallpaper() }
                                HButton { label: "Add your own…"; primary: true; onClicked: win.shell.pickWallpaper(themedSeg.current === 1) }
                                HSegment { id: themedSeg; options: ["Original", "Themed"]; segWidth: 76; current: 0; onPicked: i => current = i }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap; color: main.muted
                                text: "“Themed” recolours your image into the theme's palette. “Original” keeps it as it is."
                                font { family: main.font; pixelSize: 12 }
                            }
                            HSliderRow {
                                label: "Dim wallpaper"; desc: "Darken the background for better contrast"
                                from: 0; to: 0.7; step: 0.05; value: win.cfg.wallDim; onMoved: v => win.put("wallDim", v)
                            }
                            HSliderRow {
                                label: "Blur wallpaper"; desc: "Soften the background"
                                from: 0; to: 1; step: 0.05; value: win.cfg.wallBlur; onMoved: v => win.put("wallBlur", v)
                            }
                            HAdvanced {
                                title: "More wallpaper options"
                                HRow {
                                    label: "Fit"; desc: "Fill the screen (crops) or fit it whole (letterbox)"
                                    HSegment { options: ["Fill", "Fit"]; segWidth: 70
                                        current: win.cfg.wallFit === "fit" ? 1 : 0
                                        onPicked: i => win.put("wallFit", i === 1 ? "fit" : "fill") }
                                }
                                HRow {
                                    label: "Auto-change"; desc: "Pick a new wallpaper from this theme on a timer"
                                    HSegment {
                                        readonly property var mins: [0, 5, 15, 30, 60]
                                        options: ["Off", "5 min", "15 min", "30 min", "1 h"]; segWidth: 60
                                        current: Math.max(0, mins.indexOf(win.cfg.wallCycle))
                                        onPicked: i => win.put("wallCycle", mins[i])
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== Creator =====
                Page {
                    idx: 1; heading: "Creator"; sub: "Make a theme of your own. It appears next to the built-in ones."
                    HCard {
                        active: win.page === 1 && win.wanted; order: 0; title: "New theme"
                        Column {
                            width: parent.width; spacing: 14
                            Row {
                                spacing: 12; width: parent.width
                                HInput {
                                    id: nameInput; width: parent.width - 12 - 150; placeholder: "Theme name"
                                    text: win.draftName
                                    onEdited: v => win.draftName = v
                                    onTypingChanged: win.typing = typing
                                }
                                HButton { label: "Copy current"; onClicked: win.copyCurrent() }
                            }
                            Row {
                                spacing: 18
                                Column {
                                    spacing: 12
                                    Repeater {
                                        model: win.colorKeys
                                        Item {
                                            id: chip
                                            required property int index
                                            required property var modelData
                                            readonly property bool sel: win.editIdx === index
                                            width: 150; height: 34
                                            Rectangle {
                                                anchors.fill: parent; radius: 12
                                                color: chip.sel ? main.page : "transparent"
                                                border.width: 1; border.color: chip.sel ? main.accent : (cm.containsMouse ? main.line : "transparent")
                                                Behavior on color { ColorAnimation { duration: main.ms(160) } }
                                                Behavior on border.color { ColorAnimation { duration: main.ms(160) } }
                                            }
                                            Rectangle {
                                                x: 8; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; radius: 10
                                                color: win.draft[chip.modelData[0]]; border.width: 1; border.color: main.line
                                            }
                                            Text {
                                                x: 38; anchors.verticalCenter: parent.verticalCenter; text: chip.modelData[1]
                                                color: chip.sel ? main.text : main.muted
                                                font { family: main.font; pixelSize: 13; weight: 600 }
                                            }
                                            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: win.editIdx = chip.index }
                                        }
                                    }
                                }
                                Column {
                                    spacing: 12
                                    HColorPicker {
                                        width: 280
                                        value: win.draft[win.colorKeys[win.editIdx][0]]
                                        onPicked: c => win.setDraft(win.colorKeys[win.editIdx][0], c)
                                    }
                                    HInput {
                                        id: hexInput; width: 280; placeholder: "#rrggbb"
                                        text: win.draft[win.colorKeys[win.editIdx][0]]
                                        onTypingChanged: win.typing = typing
                                        onEdited: v => { if (/^#[0-9a-fA-F]{6}$/.test(v)) win.setDraft(win.colorKeys[win.editIdx][0], v.toLowerCase()); }
                                        font.family: "JetBrainsMono Nerd Font Propo"
                                    }
                                }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 1 && win.wanted; order: 1; title: "Preview"
                        Row {
                            spacing: 18
                            ThemePreview {
                                bg: win.draft.bg; text: win.draft.text; accent: win.draft.accent
                                accent2: win.draft.accent2; muted: win.draft.muted
                            }
                            Column {
                                spacing: 10
                                Text {
                                    width: 300; wrapMode: Text.WordWrap; color: main.muted
                                    text: "Saving also makes a first wallpaper by recolouring the one you have now into your palette. You can add more on the Appearance page."
                                    font { family: main.font; pixelSize: 12 }
                                }
                                HButton { label: "Extract from wallpaper"
                                    onClicked: win.shell.extractPalette(p => win.draft = p) }
                                HButton { label: "Save and apply"; primary: true
                                    onClicked: win.shell.saveCustomTheme({ "name": win.draftName || "My theme",
                                        "bg": win.draft.bg, "text": win.draft.text, "accent": win.draft.accent,
                                        "accent2": win.draft.accent2, "muted": win.draft.muted }) }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 1 && win.wanted; order: 2; title: "Your themes"
                        Column {
                            width: parent.width; spacing: 2
                            Text {
                                visible: win.customIds.length === 0; text: "Nothing here yet. Save a theme above and it shows up in this list."
                                color: main.muted; font { family: main.font; pixelSize: 13 }
                            }
                            Repeater {
                                model: win.customIds
                                HRow {
                                    required property string modelData
                                    label: win.shell.themeList.data[modelData].name
                                    desc: win.cfg.theme === modelData ? "In use" : "Custom theme"
                                    Row {
                                        spacing: 8
                                        HButton { label: "Use"; onClicked: win.shell.setTheme(modelData) }
                                        HButton { label: "Delete"; onClicked: win.shell.deleteCustomTheme(modelData) }
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== Bar =====
                Page {
                    idx: 2; heading: "Bar & Island"; sub: "Pick a layout, then fine-tune it."
                    HCard {
                        active: win.page === 2 && win.wanted; order: 0; title: "Layout"
                        Column {
                            width: parent.width; spacing: 14
                            Flow {
                                width: parent.width; spacing: 8
                                Repeater {
                                    model: [["classic", "Classic"], ["pill", "Pill"], ["islands", "Islands"], ["flat", "Flat"],
                                            ["minimal", "Minimal"], ["island", "Dynamic island"]]
                                    StyleCard {
                                        required property var modelData
                                        styleId: modelData[0]; label: modelData[1]
                                        selected: win.cfg.barStyle === modelData[0]
                                        width: (parent.width - 24) / 4
                                        onPicked: win.put("barStyle", modelData[0])
                                    }
                                }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap; color: main.muted
                                text: ({ "classic": "One wide floating pill across the top.",
                                         "pill": "Everything in a single compact pill, centred.",
                                         "islands": "Workspaces, clock and status each in their own pill.",
                                         "flat": "Edge to edge, rounded only on the free side.",
                                         "minimal": "No surface at all, just the content.",
                                         "island": "One pill that morphs into the bar, menus and pop-ups." })[win.cfg.barStyle]
                                font { family: main.font; pixelSize: 12 }
                            }
                            HRow {
                                label: "Position"; desc: "Where the bar sits on screen"
                                HSegment { options: ["Top", "Bottom"]; segWidth: 78
                                    current: win.cfg.barPos === "bottom" ? 1 : 0
                                    onPicked: i => win.put("barPos", i === 1 ? "bottom" : "top") }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 1; title: "Look"; available: true
                        Column {
                            width: parent.width; spacing: 0
                            HSliderRow { label: "Bar opacity"; desc: "How see-through the bar background is"
                                from: 0.35; to: 1; step: 0.01; value: win.cfg.barOpacity; onMoved: v => win.put("barOpacity", v) }
                            HSliderRow { label: "Bar roundness"; desc: "Corner radius of the bar"
                                from: 0; to: 15; step: 1; decimals: 0; unit: " px"; value: win.cfg.barRadius; onMoved: v => win.put("barRadius", v) }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 2; title: "Dynamic island"; available: win.isIsland
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Open the island"; desc: "Open the dashboard when you hover over the island, or only when you click it"
                                HSegment { readonly property var keys: ["hover", "click"]; options: ["On hover", "On click"]; segWidth: 84
                                    current: Math.max(0, keys.indexOf(win.cfg.islandOpenOn)); onPicked: i => win.put("islandOpenOn", keys[i]) } }
                            HSliderRow { label: "Hover delay"; available: win.cfg.islandOpenOn === "hover"; desc: "How long to rest on the island before it opens"
                                from: 0; to: 800; step: 20; decimals: 0; unit: " ms"; value: win.cfg.islandHoverDelay; onMoved: v => win.put("islandHoverDelay", v) }
                            HRow { label: "Dashboard"; desc: "Opening the island shows the workspaces, calendar, music and status. Off: it grows into the bar"
                                HToggle { checked: win.cfg.islandPanel; onToggled: v => win.put("islandPanel", v) } }
                            HRow { label: "Three pieces"; desc: "A round button for music, the clock, and a round button for the Control Center"
                                HToggle { checked: win.cfg.islandSplit; onToggled: v => win.put("islandSplit", v) } }
                            HRow { label: "Volume and brightness pop-up"; desc: "The island shows a bar when you change volume or brightness"
                                HToggle { checked: win.cfg.islandPeekLevels; onToggled: v => win.put("islandPeekLevels", v) } }
                            HRow { label: "Music pop-up"; desc: "The island shows the song when the track changes"
                                HToggle { checked: win.cfg.islandPeekMedia; onToggled: v => win.put("islandPeekMedia", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 3; title: "Resting island"; available: win.isIsland; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Workspaces on the island"; desc: "The workspace indicator on the left of the clock"
                                HToggle { checked: win.cfg.islandShowWs; onToggled: v => win.put("islandShowWs", v) } }
                            HRow { label: "Status on the island"; desc: "Wi-Fi and battery on the right of the clock"
                                HToggle { checked: win.cfg.islandShowStatus; onToggled: v => win.put("islandShowStatus", v) } }
                            HRow { label: "Music bars"; desc: "Moving bars next to the clock while music plays"
                                HToggle { checked: win.cfg.islandShowEq; onToggled: v => win.put("islandShowEq", v) } }
                            HSliderRow { label: "Minimum width"; desc: "Smallest width of the resting island. It always stays wide enough for its content (0 = automatic)"
                                from: 0; to: 320; step: 2; decimals: 0; unit: " px"; value: win.cfg.islandCollapsedW; onMoved: v => win.put("islandCollapsedW", v) }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 4; title: "Hover dashboard"; available: win.isIsland && win.dash; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Workspaces column"; desc: "The active window and your workspaces, on the left"
                                HToggle { checked: win.cfg.islandPanelLeft; onToggled: v => win.put("islandPanelLeft", v) } }
                            HRow { label: "Status column"; desc: "Battery, Wi-Fi, Bluetooth and quick switches, on the right"
                                HToggle { checked: win.cfg.islandPanelRight; onToggled: v => win.put("islandPanelRight", v) } }
                            HSliderRow { label: "Height"; desc: "How tall the dashboard is"
                                from: 150; to: 260; step: 2; decimals: 0; unit: " px"; value: win.cfg.islandPanelH; onMoved: v => win.put("islandPanelH", v) }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 5; title: "Island appearance"; available: win.isIsland; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Border"; desc: "A thin line around the island"
                                HToggle { checked: win.cfg.islandBorder; onToggled: v => win.put("islandBorder", v) } }
                            HRow { label: "Shadow"; available: !win.cfg.glassBar; desc: "A soft shadow under the island"
                                HToggle { checked: win.cfg.islandShadow; onToggled: v => win.put("islandShadow", v) } }
                            HSliderRow { label: "Distance from the top"; desc: "Space between the island and the screen edge (0 = follow the outer window gaps)"
                                from: 0; to: 40; step: 1; decimals: 0; unit: " px"; value: win.cfg.islandGap; onMoved: v => win.put("islandGap", v) }
                            HSliderRow { label: "Bounce"; desc: "How springy the island is when it changes shape"
                                from: 0; to: 1; step: 0.05; value: win.cfg.motionBounce; onMoved: v => win.put("motionBounce", v) }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 6; title: "Bar details"; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                                HSliderRow { label: "Bar height"; desc: "Thickness of the bar"
                                    from: 22; to: 44; step: 1; decimals: 0; unit: " px"; value: win.cfg.barHeight; onMoved: v => win.put("barHeight", v) }
                                HSliderRow { label: "Top gap"; available: !win.isIsland; desc: "Space between the bar and the screen edge"
                                    from: 0; to: 16; step: 1; decimals: 0; unit: " px"; value: win.cfg.barGap; onMoved: v => win.put("barGap", v) }
                                HSliderRow { label: "Side gap"; available: !win.isPill; desc: "Space at the left and right"
                                    from: 0; to: 40; step: 1; decimals: 0; unit: " px"; value: win.cfg.barSide; onMoved: v => win.put("barSide", v) }
                                HSliderRow { label: "Text size"; available: !win.dash; desc: "Size of bar text and icons"
                                    from: 11; to: 17; step: 1; decimals: 0; unit: " px"; value: win.cfg.barFont; onMoved: v => win.put("barFont", v) }
                                HSliderRow { label: "Module spacing"; available: !win.dash; desc: "Extra room between modules"
                                    from: 0; to: 16; step: 1; decimals: 0; unit: " px"; value: win.cfg.modSpacing; onMoved: v => win.put("modSpacing", v) }
                                HRow { label: "Icon colours"; available: !win.dash; desc: "Accent, plain text, or one colour per module"
                                    HSegment { readonly property var keys: ["accent", "text", "colour"]
                                        options: ["Accent", "Text", "Colourful"]; segWidth: 76
                                        current: Math.max(0, keys.indexOf(win.cfg.iconMode)); onPicked: i => win.put("iconMode", keys[i]) } }
                            HRow { label: "Drawn icons"; available: true; desc: "Wi-Fi as signal bars and a drawn battery instead of font icons"
                                    HToggle { checked: win.cfg.drawnIcons; onToggled: v => win.put("drawnIcons", v) } }
                                HRow { label: "Workspace style"; available: win.hasMod("workspaces") || win.isIsland; desc: "How the workspace indicators look"
                                    HSegment { readonly property var keys: ["pills", "dots", "numbers", "bars", "scroll", "stretch"]
                                        options: ["Pills", "Dots", "Numbers", "Bars", "Scroll", "Stretch"]; segWidth: 62
                                        current: Math.max(0, keys.indexOf(win.cfg.wsStyle)); onPicked: i => win.put("wsStyle", keys[i]) } }
                                HSliderRow { label: "Workspaces shown"; available: win.hasMod("workspaces") || win.isIsland; desc: "How many workspaces appear"
                                    from: 3; to: 10; step: 1; decimals: 0; value: win.cfg.wsCount; onMoved: v => win.put("wsCount", v) }
                                HRow { label: "Hide empty workspaces"; available: (win.hasMod("workspaces") || win.isIsland) && ["pills", "dots", "numbers"].indexOf(win.cfg.wsStyle) >= 0; desc: "Only show workspaces that are in use"
                                    HToggle { checked: win.cfg.wsOccupiedOnly; onToggled: v => win.put("wsOccupiedOnly", v) } }
                                HRow { label: "Date in the clock"; available: win.hasMod("clock") && !win.dash; desc: "Show the weekday and date next to the time"
                                    HToggle { checked: win.cfg.clockDate; onToggled: v => win.put("clockDate", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 7; title: "Clock and calendar"; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "24-hour clock"; desc: "Use 14:30 instead of 2:30 PM"
                                HToggle { checked: win.cfg.clock24; onToggled: v => win.put("clock24", v) } }
                            HRow { label: "Show seconds"; desc: "Tick every second in the bar"
                                HToggle { checked: win.cfg.clockSeconds; onToggled: v => win.put("clockSeconds", v) } }
                            HRow { label: "Week starts on Monday"; desc: "In the calendar that opens when you click the clock"
                                HToggle { checked: win.cfg.weekMonday; onToggled: v => win.put("weekMonday", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 8; title: "Session"; collapsible: true
                        HRow {
                            label: "Lock screen"; desc: "Morphing clock lock, same as Super + N"
                            HButton { label: "Lock now"; primary: true; onClicked: { win.shell.closeSettings(); lockDelay.restart(); } }
                        }
                    }
                }

                // ===== Modules =====
                Page {
                    idx: 3; heading: "Modules"; sub: "Choose what the bar shows and where it goes."
                    HCard {
                        active: win.page === 3 && win.wanted; order: 0; title: "Bar modules"
                        Column {
                            width: parent.width; spacing: 2
                            Repeater {
                                model: win.shell.moduleOrder
                                Item {
                                    id: mrow
                                    required property string modelData
                                    readonly property string zone: win.shell.zoneOf(modelData)
                                    readonly property var info: win.shell.moduleInfo[modelData]
                                    width: parent.width; height: 48
                                    IconTile { x: 2; anchors.verticalCenter: parent.verticalCenter; glyph: main.iconFor(mrow.info.label); tint: mrow.zone === "" ? main.muted : main.accent }
                                    Text {
                                        x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 330 - 46; elide: Text.ElideRight
                                        text: mrow.info.label; color: mrow.zone === "" ? main.muted : main.text
                                        font { family: main.font; pixelSize: 14; weight: 600 }
                                    }
                                    Row {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                        HSegment {
                                            readonly property var zones: ["", "left", "center", "right"]
                                            options: ["Off", "Left", "Middle", "Right"]; segWidth: 56
                                            current: Math.max(0, zones.indexOf(mrow.zone))
                                            onPicked: i => win.shell.setModuleZone(mrow.modelData, zones[i])
                                        }
                                        HButton { label: "↑"; padX: 11; enabled: mrow.zone !== ""; opacity: enabled ? 1 : 0.35
                                            onClicked: win.shell.moveModule(mrow.modelData, -1) }
                                        HButton { label: "↓"; padX: 11; enabled: mrow.zone !== ""; opacity: enabled ? 1 : 0.35
                                            onClicked: win.shell.moveModule(mrow.modelData, 1) }
                                    }
                                }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 3 && win.wanted; order: 1; title: "Text next to icons"; collapsible: true
                        Column {
                            width: parent.width; spacing: 2
                            HRow { label: "Show text"; available: win.hasMod("volume") || win.hasMod("network") || win.hasMod("bluetooth") || win.hasMod("battery") || win.hasMod("brightness"); desc: "Always, or only while the pointer is over a module"
                                HSegment { options: ["Always", "On hover"]; segWidth: 76
                                    current: win.cfg.labelsOnHover ? 1 : 0
                                    onPicked: i => win.put("labelsOnHover", i === 1) } }
                            HRow { label: "Volume"; available: win.hasMod("volume"); desc: "Show the percentage"
                                HToggle { checked: win.cfg.labelVolume; onToggled: v => win.put("labelVolume", v) } }
                            HRow { label: "Brightness"; available: win.hasMod("brightness") && win.shell.caps.backlight; desc: "Show the percentage"
                                HToggle { checked: win.cfg.labelBrightness; onToggled: v => win.put("labelBrightness", v) } }
                            HRow { label: "Network"; available: win.hasMod("network"); desc: "Show the Wi-Fi name"
                                HToggle { checked: win.cfg.labelNetwork; onToggled: v => win.put("labelNetwork", v) } }
                            HRow { label: "Bluetooth"; available: win.hasMod("bluetooth") && win.shell.caps.bluetooth; desc: "Show the connected device"
                                HToggle { checked: win.cfg.labelBluetooth; onToggled: v => win.put("labelBluetooth", v) } }
                            HRow { label: "Battery"; available: win.hasMod("battery") && win.shell.caps.battery; desc: "Show the percentage"
                                HToggle { checked: win.cfg.labelBattery; onToggled: v => win.put("labelBattery", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 3 && win.wanted; order: 2; title: "Good to know"; collapsible: true
                        Column {
                            width: parent.width; spacing: 10
                            Text { width: parent.width; wrapMode: Text.WordWrap; color: main.muted
                                text: "Network and Bluetooth open a menu that grows out of their button. Volume and Brightness change when you scroll over them. The Battery module hides itself on a desktop, Brightness without a backlight, and Bluetooth without an adapter."
                                font { family: main.font; pixelSize: 12 } }
                            HRow {
                                label: "Reset modules"; desc: "Workspaces, clock, volume, network and battery"
                                HButton { label: "Reset"; onClicked: win.shell.set("modules", win.shell.defaults.modules) }
                            }
                        }
                    }
                }

                // ===== Windows =====
                Page {
                    idx: 4; heading: "Windows"; sub: "Spacing, borders and effects for Hyprland windows."
                    HCard {
                        active: win.page === 4 && win.wanted; order: 0; title: "Layout"
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Inner gaps"; desc: "Space between windows"
                                from: 0; to: 20; step: 1; decimals: 0; unit: " px"; value: win.cfg.gapsIn; onMoved: v => win.put("gapsIn", v) }
                            HSliderRow { label: "Outer gaps"; desc: "Space around the screen edge"
                                from: 0; to: 40; step: 1; decimals: 0; unit: " px"; value: win.cfg.gapsOut; onMoved: v => win.put("gapsOut", v) }
                            HSliderRow { label: "Border width"; desc: "Accent gradient around the focused window"
                                from: 0; to: 6; step: 1; decimals: 0; unit: " px"; value: win.cfg.borderSize; onMoved: v => win.put("borderSize", v) }
                            HSliderRow { label: "Corner radius"; desc: "Roundness of window corners"
                                from: 0; to: 24; step: 1; decimals: 0; unit: " px"; value: win.cfg.rounding; onMoved: v => win.put("rounding", v) }
                        }
                    }
                    HCard {
                        active: win.page === 4 && win.wanted; order: 1; title: "Focus"
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Inactive window opacity"; desc: "Dim windows that are not focused"
                                from: 0.6; to: 1; step: 0.02; value: win.cfg.inactiveOpacity; onMoved: v => win.put("inactiveOpacity", v) }
                            HAdvanced {
                                title: "Shadows and borders"
                                HRow { label: "Window shadows"; desc: "A soft shadow under every window"
                                    HToggle { checked: win.cfg.shadow; onToggled: v => win.put("shadow", v) } }
                                HSliderRow { label: "Shadow size"; available: win.cfg.shadow; desc: "How far the shadow reaches"
                                    from: 2; to: 30; step: 1; decimals: 0; unit: " px"; value: win.cfg.shadowSize; onMoved: v => win.put("shadowSize", v) }
                                HRow { label: "Gradient border"; desc: "Blend the accent colours, or use a single colour"
                                    HToggle { checked: win.cfg.gradientBorder; onToggled: v => win.put("gradientBorder", v) } }
                            }
                        }
                    }
                }

                // ===== Input =====
                Page {
                    idx: 5; heading: "Input"; sub: "Mouse, touchpad and keyboard behaviour."
                    HCard {
                        active: win.page === 5 && win.wanted; order: 0; title: "Mouse and touchpad"
                        Column {
                            width: parent.width; spacing: 4
                            HRow { label: "Focus follows mouse"; desc: "Windows take focus when you point at them"
                                HToggle { checked: win.cfg.followMouse; onToggled: v => win.put("followMouse", v) } }
                            HRow { label: "Natural scrolling"; available: win.shell.caps.touchpad; desc: "Content moves with your fingers on the touchpad"
                                HToggle { checked: win.cfg.naturalScroll; onToggled: v => win.put("naturalScroll", v) } }
                            HRow { label: "Tap to click"; available: win.shell.caps.touchpad; desc: "Tap the touchpad instead of pressing it"
                                HToggle { checked: win.cfg.tapToClick; onToggled: v => win.put("tapToClick", v) } }
                            HSliderRow { label: "Pointer speed"; desc: "Slower on the left, faster on the right"
                                from: -1; to: 1; step: 0.1; decimals: 1; value: win.cfg.pointerSpeed; onMoved: v => win.put("pointerSpeed", v) }
                        }
                    }
                    HCard {
                        active: win.page === 5 && win.wanted; order: 1; title: "Keyboard"
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Key repeat speed"; desc: "How fast a held key repeats"
                                from: 10; to: 60; step: 1; decimals: 0; unit: "/s"; value: win.cfg.repeatRate; onMoved: v => win.put("repeatRate", v) }
                            HSliderRow { label: "Repeat delay"; desc: "How long to hold before a key starts repeating"
                                from: 150; to: 900; step: 10; decimals: 0; unit: " ms"; value: win.cfg.repeatDelay; onMoved: v => win.put("repeatDelay", v) }
                        }
                    }
                }

                // ===== Glass =====
                Page {
                    idx: 6; heading: "Glass"; sub: "Frosted, see-through surfaces with a blurred backdrop."
                    HCard {
                        active: win.page === 6 && win.wanted; order: 0; title: "Frosted glass on"
                        Column {
                            width: parent.width; spacing: 2
                            HRow { label: "Status bar"; desc: "The bar and its menus (Wi-Fi, Bluetooth, quick settings) turn see-through and blur what is behind them"
                                HToggle { checked: win.cfg.glassBar; onToggled: v => win.put("glassBar", v) } }
                            HRow { label: "Settings panel"; desc: "This window"
                                HToggle { checked: win.cfg.glassPanel; onToggled: v => win.put("glassPanel", v) } }
                            HRow { label: "App launcher"; available: win.shell.caps.rofi; desc: "Rofi, applied on next open"
                                HToggle { checked: win.cfg.glassLauncher; onToggled: v => win.put("glassLauncher", v) } }
                            HRow { label: "Terminal"; available: win.shell.caps.kitty; desc: "Kitty windows, reloaded live"
                                HToggle { checked: win.cfg.glassTerminal; onToggled: v => win.put("glassTerminal", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 6 && win.wanted; order: 1; title: "Frosted app windows"; collapsible: true
                        Column {
                            width: parent.width; spacing: 2
                            HRow { label: "Frost other apps"; desc: "Makes the windows of the groups below see-through with the blurred backdrop"
                                HToggle { checked: win.cfg.glassWindows; onToggled: v => win.put("glassWindows", v) } }
                            HRow { label: "Browsers"; available: win.cfg.glassWindows; desc: "Firefox, Lodica, Chromium, Brave, Zen"
                                HToggle { checked: win.cfg.glassBrowsers; onToggled: v => win.put("glassBrowsers", v) } }
                            HRow { label: "File managers"; available: win.cfg.glassWindows; desc: "Dolphin, Nautilus, Thunar"
                                HToggle { checked: win.cfg.glassFiles; onToggled: v => win.put("glassFiles", v) } }
                            HRow { label: "Editors"; available: win.cfg.glassWindows; desc: "VS Code, Kate, Gedit, Text Editor"
                                HToggle { checked: win.cfg.glassEditors; onToggled: v => win.put("glassEditors", v) } }
                            HRow { label: "Chat and media"; available: win.cfg.glassWindows; desc: "Discord, Spotify, Telegram, Signal, Hearth"
                                HToggle { checked: win.cfg.glassChat; onToggled: v => win.put("glassChat", v) } }
                            HRow { label: "Other KDE and GNOME apps"; available: win.cfg.glassWindows; desc: "Okular, Gwenview, System Settings, Calculator and the like"
                                HToggle { checked: win.cfg.glassOther; onToggled: v => win.put("glassOther", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 6 && win.wanted; order: 2; title: "Tuning"; available: win.cfg.glassBar || win.cfg.glassPanel || win.cfg.glassLauncher || win.cfg.glassTerminal || win.cfg.glassWindows; collapsible: true
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Glass amount"; desc: "How see-through glass surfaces are"
                                from: 0.1; to: 0.65; step: 0.01; value: win.cfg.glassAmount; onMoved: v => win.put("glassAmount", v) }
                            HSliderRow { label: "Blur strength"; desc: "How soft the backdrop gets"
                                from: 1; to: 14; step: 1; decimals: 0; value: win.cfg.blurSize; onMoved: v => win.put("blurSize", v) }
                            HRow { label: "Background blur"; desc: "Master switch for all blur in Hyprland"
                                HToggle { checked: win.cfg.blur; onToggled: v => win.put("blur", v) } }
                        }
                    }
                }

                // ===== System =====
                Page {
                    idx: 7; heading: "System"; sub: "Choose which apps follow the theme."
                    HCard {
                        active: win.page === 7 && win.wanted; order: 0; title: "Follow the theme"
                        Column {
                            width: parent.width; spacing: 2
                            HRow { label: "Kitty"; available: win.shell.caps.kitty; desc: "Terminal colours, reloaded live"
                                HToggle { checked: win.cfg.syncKitty; onToggled: v => win.put("syncKitty", v) } }
                            HRow { label: "Fish"; available: win.shell.caps.fish; desc: "Prompt and syntax colours in every open shell"
                                HToggle { checked: win.cfg.syncFish; onToggled: v => win.put("syncFish", v) } }
                            HRow { label: "Rofi"; available: win.shell.caps.rofi; desc: "App launcher, applied on next open"
                                HToggle { checked: win.cfg.syncRofi; onToggled: v => win.put("syncRofi", v) } }
                            HRow { label: "GTK apps"; desc: "Accent and surfaces, applied when an app starts"
                                HToggle { checked: win.cfg.syncGtk; onToggled: v => win.put("syncGtk", v) } }
                            HRow { label: "Other apps"; desc: "Firefox, Yazi, Lodica, Dolphin and other KDE apps, micro, cava. Restart the app to see it"
                                HToggle { checked: win.cfg.syncApps; onToggled: v => win.put("syncApps", v) } }
                            HRow { label: "Hyprlock"; available: win.shell.caps.hyprlock; desc: "The Super + Shift + X lock screen"
                                HToggle { checked: win.cfg.syncLock; onToggled: v => win.put("syncLock", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 7 && win.wanted; order: 1; title: "Terminal"; available: win.shell.caps.kitty && win.cfg.syncKitty; collapsible: true
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Kitty opacity"; desc: "Transparency of terminal windows"
                                from: 0.5; to: 1; step: 0.01; value: win.cfg.termOpacity; onMoved: v => win.put("termOpacity", v) }
                            HAdvanced {
                                title: "More terminal options"
                                HSliderRow { label: "Font size"; desc: "Text size in kitty"
                                    from: 8; to: 20; step: 1; decimals: 0; unit: " pt"; value: win.cfg.kittyFont; onMoved: v => win.put("kittyFont", v) }
                                HSliderRow { label: "Padding"; desc: "Space around the text"
                                    from: 0; to: 40; step: 2; decimals: 0; unit: " px"; value: win.cfg.kittyPad; onMoved: v => win.put("kittyPad", v) }
                                HRow { label: "Cursor"; desc: "Shape of the text cursor"
                                    HSegment { readonly property var keys: ["beam", "block", "underline"]
                                        options: ["Beam", "Block", "Line"]; segWidth: 66
                                        current: Math.max(0, keys.indexOf(win.cfg.kittyCursor)); onPicked: i => win.put("kittyCursor", keys[i]) } }
                            }
                            HRow { label: "Apply now"; available: win.cfg.syncKitty || win.cfg.syncFish || win.cfg.syncRofi || win.cfg.syncGtk || win.cfg.syncApps || win.cfg.syncLock; desc: "Re-write every themed config file"
                                HButton { label: "Re-apply"; onClicked: win.shell.reapply() } }
                        }
                    }
                    HCard {
                        active: win.page === 7 && win.wanted; order: 2; title: "App launcher"; available: win.shell.caps.rofi && win.cfg.syncRofi; collapsible: true
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Width"; desc: "Width of the launcher window"
                                from: 300; to: 700; step: 20; decimals: 0; unit: " px"; value: win.cfg.rofiWidth; onMoved: v => win.put("rofiWidth", v) }
                            HAdvanced {
                                title: "More launcher options"
                                HSliderRow { label: "Rows"; desc: "How many apps are listed"
                                    from: 4; to: 12; step: 1; decimals: 0; value: win.cfg.rofiLines; onMoved: v => win.put("rofiLines", v) }
                                HRow { label: "App icons"; desc: "Show an icon next to each app"
                                    HToggle { checked: win.cfg.rofiIcons; onToggled: v => win.put("rofiIcons", v) } }
                            }
                        }
                    }
                }

                // ===== Control Center =====
                Page {
                    idx: 8; heading: "Control Center"; sub: "Arrange it exactly as it will look: drag, resize, add and remove."
                    Item {
                        id: ccEditor
                        width: parent.width
                        readonly property bool below: width - frame.width - 20 < 200
                        readonly property var flick: { let p = parent; while (p && p.contentY === undefined) p = p.parent; return p; }
                        property var activeDrag: null
                        property real pointerY: 0
                        height: below ? frame.height + 16 + side.height : Math.max(frame.height, side.height)

                        // while a tile is held near the top or bottom edge, the page scrolls on its own
                        Timer {
                            interval: 16; repeat: true; running: ccEditor.activeDrag !== null
                            onTriggered: {
                                const f = ccEditor.flick;
                                if (!f) return;
                                const edge = 70, top = ccEditor.pointerY, bottom = f.height - ccEditor.pointerY;
                                const d = top < edge ? -16 * (edge - top) / edge : (bottom < edge ? 16 * (edge - bottom) / edge : 0);
                                if (d === 0) return;
                                const y = Math.max(0, Math.min(f.contentHeight - f.height, f.contentY + d));
                                if (y === f.contentY) return;
                                f.contentY = y;
                                ccEditor.activeDrag.update();
                            }
                        }

                        Rectangle {
                            id: frame
                            width: popup.wantedWidth; height: popup.wantedHeight
                            radius: 28; color: main.bg; border.width: 1; border.color: main.border
                            opacity: win.page === 8 && win.wanted ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: main.ms(300) } }
                            QuickPopup {
                                id: popup
                                anchors.fill: parent
                                editing: true
                                active: win.page === 8 && win.wanted
                                shell: win.shell
                            }
                            Text {
                                x: 18; y: 14; text: String.fromCodePoint(0xF0570); color: main.accent
                                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 }
                            }
                            Item {
                                id: overlay
                                x: popup.gridOrigin.x; y: popup.gridOrigin.y
                                width: popup.gridItem.width; height: popup.gridItem.implicitHeight
                                readonly property real cw: popup.gridItem.cellW
                                readonly property real rh: popup.rowH
                                readonly property real gap: popup.cellGap
                                readonly property int cols: popup.layout.cols
                                function cellX(g) { return g * (cw + gap); }
                                function cellY(g) { return g * (rh + gap); }
                                function shapeRadius(h) { return h <= 70 ? h / 2 : 30; }

                                Rectangle {
                                    id: ghost
                                    visible: false; z: 1; radius: overlay.shapeRadius(height)
                                    color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.14)
                                    border.width: 2; border.color: main.accent
                                    Behavior on x { NumberAnimation { duration: main.ms(90); easing.type: Easing.OutCubic } }
                                    Behavior on y { NumberAnimation { duration: main.ms(90); easing.type: Easing.OutCubic } }
                                }
                                Repeater {
                                    model: popup.sections
                                    delegate: Item {
                                        id: mod
                                        required property string modelData
                                        readonly property var it: popup.layout.items[modelData]
                                        readonly property var mn: win.shell.ccMinSize[modelData] || [1, 1]
                                        property int pw: it ? it.w : 1
                                        property int ph: it ? it.h : 1
                                        property bool moving: false
                                        property real px: 0
                                        property real py: 0
                                        readonly property bool hot: hh.hovered || moving || rz.pressed
                                        function bindPos() {
                                            x = Qt.binding(() => mod.it ? overlay.cellX(mod.it.x) : 0);
                                            y = Qt.binding(() => mod.it ? overlay.cellY(mod.it.y) : 0);
                                        }
                                        Component.onCompleted: bindPos()
                                        width: pw * overlay.cw + (pw - 1) * overlay.gap
                                        height: ph * overlay.rh + (ph - 1) * overlay.gap
                                        z: moving || rz.pressed ? 5 : 2
                                        Behavior on width { enabled: !rz.pressed; NumberAnimation { duration: main.ms(160); easing.type: Easing.OutCubic } }
                                        Behavior on height { enabled: !rz.pressed; NumberAnimation { duration: main.ms(160); easing.type: Easing.OutCubic } }
                                        HoverHandler { id: hh }

                                        Rectangle {
                                            anchors.fill: parent; radius: overlay.shapeRadius(height)
                                            color: mod.moving ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.30) : "transparent"
                                            border.width: mod.hot ? 2 : 0; border.color: main.accent
                                            Behavior on color { ColorAnimation { duration: main.ms(120) } }
                                        }
                                        MouseArea {
                                            id: mv
                                            anchors.fill: parent; preventStealing: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            property point off
                                            property int gx: 0
                                            property int gy: 0
                                            function update() {
                                                const p = overlay.mapFromItem(ccEditor.flick, mod.px, mod.py);
                                                mod.moving = true;
                                                mod.x = Math.max(0, Math.min(overlay.width - mod.width, p.x - off.x));
                                                mod.y = Math.max(0, Math.min(overlay.height - mod.height, p.y - off.y));
                                                gx = Math.max(0, Math.min(overlay.cols - mod.pw, Math.round(mod.x / (overlay.cw + overlay.gap))));
                                                gy = Math.max(0, Math.round(mod.y / (overlay.rh + overlay.gap)));
                                                ghost.x = overlay.cellX(gx); ghost.y = overlay.cellY(gy);
                                                ghost.width = mod.width; ghost.height = mod.height;
                                                ghost.visible = true;
                                            }
                                            function finish() {
                                                ccEditor.activeDrag = null;
                                                ghost.visible = false;
                                                if (!mod.moving) return;
                                                mod.moving = false;
                                                const moved = gx !== mod.it.x || gy !== mod.it.y;
                                                mod.bindPos();
                                                if (moved) win.shell.ccPlace(mod.modelData, gx, gy, mod.pw, mod.ph);
                                            }
                                            onPressed: m => {
                                                const p = mapToItem(overlay, m.x, m.y);
                                                off = Qt.point(p.x - mod.x, p.y - mod.y);
                                                gx = mod.it.x; gy = mod.it.y;
                                            }
                                            onPositionChanged: m => {
                                                if (!pressed) return;
                                                const f = mapToItem(ccEditor.flick, m.x, m.y);
                                                mod.px = f.x; mod.py = f.y;
                                                ccEditor.pointerY = f.y;
                                                ccEditor.activeDrag = mv;
                                                update();
                                            }
                                            onReleased: finish()
                                            onCanceled: finish()
                                        }
                                        Rectangle {
                                            visible: mod.hot && !mod.moving
                                            width: 20; height: 20; radius: 10; x: parent.width - width - 2; y: 2; z: 3
                                            color: xm.containsMouse ? main.red : Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.88)
                                            border.width: 1; border.color: main.border
                                            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "×"; color: main.text; font { pixelSize: 14; weight: 700 } }
                                            MouseArea { id: xm; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.shell.ccToggle(mod.modelData) }
                                        }
                                        Rectangle {
                                            visible: mod.hot
                                            width: 20; height: 20; radius: 10; x: parent.width - width - 2; y: parent.height - height - 2; z: 3
                                            color: main.accent
                                            Text { anchors.centerIn: parent; text: "↘"; color: main.onAccent; font { pixelSize: 12; weight: 700 } }
                                            MouseArea {
                                                id: rz
                                                anchors.fill: parent; anchors.margins: -5; preventStealing: true; cursorShape: Qt.SizeFDiagCursor
                                                property point start
                                                property int sw: 1
                                                property int sh: 1
                                                function update() {
                                                    const p = overlay.mapFromItem(ccEditor.flick, mod.px, mod.py);
                                                    mod.pw = Math.max(mod.mn[0], Math.min(overlay.cols - mod.it.x, sw + Math.round((p.x - start.x) / (overlay.cw + overlay.gap))));
                                                    mod.ph = Math.max(mod.mn[1], Math.min(6, sh + Math.round((p.y - start.y) / (overlay.rh + overlay.gap))));
                                                    ghost.x = mod.x; ghost.y = mod.y; ghost.width = mod.width; ghost.height = mod.height; ghost.visible = true;
                                                }
                                                function finish() {
                                                    ccEditor.activeDrag = null;
                                                    ghost.visible = false;
                                                    if (mod.pw !== mod.it.w || mod.ph !== mod.it.h) win.shell.ccPlace(mod.modelData, mod.it.x, mod.it.y, mod.pw, mod.ph);
                                                }
                                                onPressed: m => { start = mapToItem(overlay, m.x, m.y); sw = mod.pw; sh = mod.ph; }
                                                onPositionChanged: m => {
                                                    if (!pressed) return;
                                                    const f = mapToItem(ccEditor.flick, m.x, m.y);
                                                    mod.px = f.x; mod.py = f.y;
                                                    ccEditor.pointerY = f.y;
                                                    ccEditor.activeDrag = rz;
                                                    update();
                                                }
                                                onReleased: finish()
                                                onCanceled: finish()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            id: side
                            x: ccEditor.below ? 0 : frame.width + 20; y: ccEditor.below ? frame.height + 16 : 0
                            width: ccEditor.below ? ccEditor.width : ccEditor.width - frame.width - 20; spacing: 14
                            HCard {
                                active: win.page === 8 && win.wanted; order: 0; title: "Grid"
                                Column {
                                    width: parent.width; spacing: 10
                                    Text { text: "Columns"; color: main.text; font { family: main.font; pixelSize: 13; weight: 500 } }
                                    HSegment {
                                        options: ["5", "6", "7", "8", "9"]; segWidth: (parent.width - 6) / 5
                                        current: win.shell.ccGrid.cols - 5
                                        onPicked: i => win.shell.ccSetCols(i + 5)
                                    }
                                    Row { spacing: 6
                                        HButton { label: "Tidy"; padX: 10; onClicked: win.shell.ccCompact() }
                                        HButton { label: "Undo"; padX: 10; onClicked: win.shell.ccUndo() }
                                        HButton { label: "Reset"; padX: 10; onClicked: win.shell.ccReset() } }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; color: main.muted; font { family: main.font; pixelSize: 11 }
                                        text: "Drag a module to move it. Pull its corner to resize it. Click × to take it off." }
                                }
                            }
                            HCard {
                                id: addCard
                                readonly property var offIds: win.shell.ccFull.filter(i => (win.cfg.ccHidden || []).indexOf(i) >= 0)
                                active: win.page === 8 && win.wanted; order: 1; title: "Add to the Control Center"
                                Column {
                                    width: parent.width; spacing: 0
                                    Text { visible: addCard.offIds.length === 0; width: parent.width; height: 30; wrapMode: Text.WordWrap
                                        text: "Everything is on the grid."; color: main.muted; font { family: main.font; pixelSize: 12 } }
                                    Repeater {
                                        model: addCard.offIds
                                        delegate: Item {
                                            id: addRow
                                            required property string modelData
                                            readonly property var info: win.shell.ccLabels[modelData] || [modelData, ""]
                                            width: parent.width; height: 44
                                            Rectangle { anchors.fill: parent; radius: 12; color: Qt.rgba(main.text.r, main.text.g, main.text.b, am.containsMouse ? 0.08 : 0)
                                                Behavior on color { ColorAnimation { duration: main.ms(120) } } }
                                            IconTile { x: 4; anchors.verticalCenter: parent.verticalCenter; size: 28; round: true; glyph: String.fromCodePoint(win.shell.ccGlyphs[addRow.modelData]) }
                                            Column {
                                                x: 42; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 42 - 30; spacing: 1
                                                Text { width: parent.width; elide: Text.ElideRight; text: addRow.info[0]; color: main.text; font { family: main.font; pixelSize: 12; weight: 600 } }
                                                Text { width: parent.width; elide: Text.ElideRight; text: addRow.info[1]; color: main.muted; font { family: main.font; pixelSize: 10 } }
                                            }
                                            Text { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: "+"; color: am.containsMouse ? main.accent : main.muted; font { pixelSize: 20; weight: 600 } }
                                            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.shell.ccToggle(addRow.modelData) }
                                        }
                                    }
                                }
                            }
                            HCard {
                                active: win.page === 8 && win.wanted; order: 2; title: "Night Light"; collapsible: true
                                Column {
                                    width: parent.width; spacing: 10
                                    Text { text: "Warmth"; color: main.text; font { family: main.font; pixelSize: 13; weight: 500 } }
                                    HSegment {
                                        options: ["Soft", "Warm", "Deep"]; segWidth: (parent.width - 6) / 3
                                        current: Math.max(0, Math.min(2, win.cfg.nightLevel - 1))
                                        onPicked: i => win.put("nightLevel", i + 1)
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== Notifications =====
                Page {
                    idx: 9; heading: "Notifications"; sub: "Pop-ups, the notification centre and quiet mode."
                    HCard {
                        active: win.page === 9 && win.wanted; order: 0; title: "Pop-ups"
                        Column {
                            width: parent.width; spacing: 4
                            HRow { label: "Show notifications"; desc: "Pop-ups and a notification centre. Turn off if mako, dunst or another daemon should handle them (takes effect after a restart)"
                                HToggle { checked: win.cfg.notifications; onToggled: v => win.put("notifications", v) } }
                            HSliderRow { label: "Time on screen"; available: win.cfg.notifications; desc: "How long a pop-up stays when the app does not say"
                                from: 3; to: 15; step: 1; decimals: 0; unit: " s"; value: win.cfg.notifTimeout; onMoved: v => win.put("notifTimeout", v) }
                            HRow { label: "Quiet mode"; desc: "Hide pop-ups (critical ones still show). Also on the bell: right click"
                                HToggle { checked: win.shell.notifier.dnd; onToggled: v => { win.shell.notifier.dnd = v; } } }
                        }
                    }
                }

                // ===== Shortcuts =====
                Page {
                    id: scPage
                    idx: 10; heading: "Shortcuts"; sub: "Open any part of the island with a key combination."
                    property string recording: ""
                    property string notice: ""
                    readonly property var mgr: win.shell.shortcuts
                    readonly property var groups: ["Island menus", "Shell", "Quick actions"]
                    readonly property var shifted: ({ "33": "1", "64": "2", "35": "3", "36": "4", "37": "5", "94": "6", "38": "7", "42": "8", "40": "9", "41": "0" })

                    function pretty(c) {
                        return c.split("+").map(p => p.trim()).map(p => ({ "SUPER": "Super", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift",
                            "comma": ",", "period": ".", "slash": "/", "minus": "-", "equal": "=", "semicolon": ";", "apostrophe": "'" })[p] || p).join(" + ");
                    }
                    function keyName(ev) {
                        const k = ev.key;
                        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1);
                        if ((k >= Qt.Key_A && k <= Qt.Key_Z) || (k >= Qt.Key_0 && k <= Qt.Key_9)) return String.fromCharCode(k);
                        if (shifted[String(k)]) return shifted[String(k)];
                        const t = {};
                        t[Qt.Key_Space] = "Space"; t[Qt.Key_Return] = "Return"; t[Qt.Key_Enter] = "Return"; t[Qt.Key_Tab] = "Tab";
                        t[Qt.Key_Comma] = "comma"; t[Qt.Key_Period] = "period"; t[Qt.Key_Slash] = "slash"; t[Qt.Key_Backslash] = "backslash";
                        t[Qt.Key_Minus] = "minus"; t[Qt.Key_Equal] = "equal"; t[Qt.Key_Semicolon] = "semicolon"; t[Qt.Key_Apostrophe] = "apostrophe";
                        t[Qt.Key_BracketLeft] = "bracketleft"; t[Qt.Key_BracketRight] = "bracketright"; t[Qt.Key_QuoteLeft] = "grave";
                        t[Qt.Key_Left] = "Left"; t[Qt.Key_Right] = "Right"; t[Qt.Key_Up] = "Up"; t[Qt.Key_Down] = "Down";
                        t[Qt.Key_Home] = "Home"; t[Qt.Key_End] = "End"; t[Qt.Key_PageUp] = "Prior"; t[Qt.Key_PageDown] = "Next";
                        t[Qt.Key_Print] = "Print"; t[Qt.Key_Insert] = "Insert";
                        return t[k] || "";
                    }
                    function start(id) {
                        notice = "";
                        recording = id;
                        win.typing = true;
                        mgr.beginCapture();
                        capture.forceActiveFocus();
                    }
                    function stop() {
                        if (recording === "") return;
                        recording = "";
                        win.typing = false;
                        mgr.endCapture();
                        keyScope.forceActiveFocus();
                    }
                    function clear(id) {
                        const m = Object.assign({}, win.cfg.shortcuts || {});
                        delete m[id];
                        win.put("shortcuts", m);
                    }
                    onCurrentChanged: if (!current) stop()
                    Connections { target: win; function onWantedChanged() { if (!win.wanted) scPage.stop(); } }
                    Connections {
                        target: scPage.mgr
                        function onConflict(id, why) { scPage.notice = why + ". Try another combination."; scPage.stop(); }
                        function onAssigned(id) { scPage.notice = ""; scPage.stop(); }
                    }
                    Item {
                        id: capture
                        width: 1; height: 1
                        Keys.onPressed: ev => {
                            if (scPage.recording === "") return;
                            ev.accepted = true;
                            const k = ev.key;
                            if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_CapsLock].indexOf(k) >= 0) return;
                            const m = ev.modifiers;
                            if (k === Qt.Key_Escape && !m) { scPage.stop(); return; }
                            if ((k === Qt.Key_Backspace || k === Qt.Key_Delete) && !m) { const id = scPage.recording; scPage.stop(); scPage.clear(id); return; }
                            const name = scPage.keyName(ev);
                            if (name === "") { scPage.notice = "That key cannot be used."; return; }
                            const parts = [];
                            if (m & Qt.MetaModifier) parts.push("SUPER");
                            if (m & Qt.ControlModifier) parts.push("CTRL");
                            if (m & Qt.AltModifier) parts.push("ALT");
                            if (m & Qt.ShiftModifier) parts.push("SHIFT");
                            if (parts.length === 0 && !/^F\d+$/.test(name) && name !== "Print") { scPage.notice = "Hold Super, Ctrl or Alt as well, so normal typing keeps working."; return; }
                            scPage.notice = "";
                            scPage.mgr.tryAssign(scPage.recording, parts.concat([name]).join(" + "));
                        }
                    }
                    Rectangle {
                        visible: scPage.notice !== ""
                        width: parent.width; height: visible ? noteText.implicitHeight + 20 : 0; radius: 14
                        color: Qt.rgba(main.red.r, main.red.g, main.red.b, 0.14); border.width: 1; border.color: Qt.rgba(main.red.r, main.red.g, main.red.b, 0.5)
                        Text { id: noteText; x: 14; y: 10; width: parent.width - 28; wrapMode: Text.WordWrap; text: scPage.notice; color: main.text; font { family: main.font; pixelSize: 12 } }
                    }
                    Repeater {
                        model: scPage.groups
                        delegate: HCard {
                            id: grp
                            required property string modelData
                            required property int index
                            active: win.page === 10 && win.wanted; order: index; title: modelData
                            Column {
                                width: parent.width; spacing: 0
                                Repeater {
                                    model: win.shell.shortcutActions.filter(a => a.group === grp.modelData)
                                    delegate: HRow {
                                        id: srow
                                        required property var modelData
                                        readonly property string combo: (win.cfg.shortcuts || {})[modelData.id] || ""
                                        readonly property bool rec: scPage.recording === modelData.id
                                        label: modelData.label; desc: modelData.desc
                                        Row {
                                            spacing: 8
                                            Rectangle {
                                                visible: srow.combo !== "" && !srow.rec
                                                width: 24; height: 24; radius: 12; anchors.verticalCenter: parent.verticalCenter
                                                color: xm.containsMouse ? Qt.rgba(main.red.r, main.red.g, main.red.b, 0.3) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
                                                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "×"; color: main.text; font { pixelSize: 15; weight: 600 } }
                                                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: scPage.clear(srow.modelData.id) }
                                            }
                                            Rectangle {
                                                width: Math.max(104, chipText.implicitWidth + 28); height: 30; radius: 15; anchors.verticalCenter: parent.verticalCenter
                                                color: srow.rec ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.2) : (cm.containsMouse ? main.line : "transparent")
                                                border.width: 1; border.color: srow.rec ? main.accent : main.line
                                                Behavior on color { ColorAnimation { duration: main.ms(140) } }
                                                Text {
                                                    id: chipText; anchors.centerIn: parent
                                                    text: srow.rec ? "Press keys…" : (srow.combo !== "" ? scPage.pretty(srow.combo) : "Not set")
                                                    color: srow.rec ? main.accent : (srow.combo !== "" ? main.text : main.muted)
                                                    font { family: main.font; pixelSize: 12; weight: 600 }
                                                }
                                                MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: srow.rec ? scPage.stop() : scPage.start(srow.modelData.id) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== Desktop =====
                Page {
                    id: dtPage
                    idx: 11; heading: "Desktop"; sub: "Put widgets on your desktop and your lock screen."
                    readonly property int homeCount: (win.cfg.homeWidgets || []).length
                    readonly property int lockCount: (win.cfg.lockWidgets || []).length
                    function edit(tab) { win.shell.closeSettings(); win.shell.editor.show(tab); }
                    HCard {
                        active: win.page === 11 && win.wanted; order: 0; title: "Customize"
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Desktop"; desc: "Full-screen view of your desktop: drag widgets around, resize them, add or remove them"
                                Row { spacing: 10
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: dtPage.homeCount + (dtPage.homeCount === 1 ? " widget" : " widgets"); color: main.muted; font { family: main.font; pixelSize: 12 } }
                                    HButton { label: "Edit desktop"; primary: true; onClicked: dtPage.edit("home") } } }
                            HRow { label: "Lock screen"; desc: "The same for the lock screen. The clock and the password field keep their place"
                                Row { spacing: 10
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: dtPage.lockCount + (dtPage.lockCount === 1 ? " widget" : " widgets"); color: main.muted; font { family: main.font; pixelSize: 12 } }
                                    HButton { label: "Edit lock screen"; primary: true; onClicked: dtPage.edit("lock") } } }
                        }
                    }
                    HCard {
                        active: win.page === 11 && win.wanted; order: 1; title: "Show"
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Widgets on the desktop"; desc: "Hide them all without losing your arrangement"
                                HToggle { checked: win.cfg.homeEnabled; onToggled: v => win.put("homeEnabled", v) } }
                            HRow { label: "Widgets on the lock screen"; desc: "Hide them all without losing your arrangement"
                                HToggle { checked: win.cfg.lockWidgetsEnabled; onToggled: v => win.put("lockWidgetsEnabled", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 11 && win.wanted; order: 2; title: "New widgets"; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Style"; desc: "How a widget looks when you add it. You can change each one afterwards"
                                HSegment {
                                    readonly property var keys: ["auto", "plain", "card", "glass", "solid", "outline"]
                                    options: ["Auto", "Plain", "Card", "Glass", "Solid", "Outline"]; segWidth: 54
                                    current: Math.max(0, keys.indexOf(win.cfg.widgetStyle)); onPicked: i => win.put("widgetStyle", keys[i]) } }
                            HSliderRow { label: "Roundness"; desc: "Corner radius of new widgets"
                                from: 0; to: 48; step: 1; decimals: 0; unit: " px"; value: win.cfg.widgetRadius; onMoved: v => win.put("widgetRadius", v) }
                        }
                    }
                    HCard {
                        active: win.page === 11 && win.wanted; order: 3; title: "Lock screen"; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Date above the clock"; desc: "The day and date above the lock screen clock"
                                HToggle { checked: win.cfg.lockDate; onToggled: v => win.put("lockDate", v) } }
                            HSliderRow { label: "Clock size"; desc: "Size of the big clock"
                                from: 60; to: 160; step: 2; decimals: 0; unit: " px"; value: win.cfg.lockClockSize; onMoved: v => win.put("lockClockSize", v) }
                            HSliderRow { label: "Clock height"; desc: "How high the clock and the password field sit on the screen"
                                from: 0.25; to: 0.55; step: 0.01; decimals: 2; value: win.cfg.lockClockY; onMoved: v => win.put("lockClockY", v) }
                            HSliderRow { label: "Blur"; desc: "How much your desktop is blurred behind the lock screen"
                                from: 0; to: 1.5; step: 0.05; decimals: 2; value: win.cfg.lockBlur; onMoved: v => win.put("lockBlur", v) }
                            HSliderRow { label: "Dim"; desc: "Darken the lock screen"
                                from: 0; to: 0.6; step: 0.02; decimals: 2; value: win.cfg.lockDim; onMoved: v => win.put("lockDim", v) }
                        }
                    }
                    HCard {
                        active: win.page === 11 && win.wanted; order: 4; title: "Start over"; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Remove desktop widgets"; desc: "Take every widget off the desktop"
                                HButton { label: "Remove all"; onClicked: win.put("homeWidgets", []) } }
                            HRow { label: "Remove lock screen widgets"; desc: "Take every widget off the lock screen"
                                HButton { label: "Remove all"; onClicked: win.put("lockWidgets", []) } }
                        }
                    }
                }

                // ===== Updates =====
                Page {
                    id: updPage
                    idx: 12; heading: "Updates"; sub: "Check GitHub for a newer version and install it from here."
                    readonly property var up: win.shell.updater
                    readonly property bool wide: up.phase === "available" || up.phase === "current"
                    onCurrentChanged: if (current && win.wanted) up.checkIfStale()
                    HCard {
                        active: win.page === 12 && win.wanted; order: 0; title: "Version"
                        Column {
                            width: parent.width; spacing: 0
                            HRow { label: "Installed"
                                Text { text: updPage.up.installed !== "" ? updPage.up.short(updPage.up.installed) : "unknown"; color: main.muted; font { family: "monospace"; pixelSize: 13 } } }
                            HRow { label: "Latest on GitHub"
                                Text { text: updPage.up.latest !== "" ? updPage.up.short(updPage.up.latest) : "-"; color: main.muted; font { family: "monospace"; pixelSize: 13 } } }
                            HRow { label: "Status"
                                Text {
                                    readonly property string p: updPage.up.phase
                                    text: p === "checking" ? "Checking…" : p === "updating" ? "Working…" : p === "current" ? "You are up to date"
                                        : p === "available" ? (updPage.up.behind < 0 ? "A version is available" : updPage.up.behind + (updPage.up.behind === 1 ? " update available" : " updates available"))
                                        : p === "updated" ? "Updated. The shell reloads by itself." : p === "restored" ? "Backup restored."
                                        : p === "error" ? "Something went wrong" : "Not checked yet"
                                    color: p === "available" ? main.accent : (p === "error" ? main.red : main.muted)
                                    font { family: main.font; pixelSize: 13; weight: 600 }
                                } }
                            HRow { label: "Check or install"
                                Row { spacing: 8
                                    HButton { label: updPage.up.phase === "checking" ? "Checking…" : "Check for updates"; opacity: updPage.up.busy ? 0.5 : 1; onClicked: updPage.up.check() }
                                    HButton { label: updPage.up.phase === "updating" ? "Updating…" : "Update now"; primary: true
                                        visible: updPage.up.phase === "available"; opacity: updPage.up.busy ? 0.5 : 1; onClicked: updPage.up.update() } } }
                            Text { visible: updPage.up.phase === "error" || updPage.up.phase === "updated"; width: parent.width; wrapMode: Text.WordWrap; topPadding: 6; bottomPadding: 4
                                text: updPage.up.message; color: updPage.up.phase === "error" ? main.red : main.muted; font { family: main.font; pixelSize: 12 } }
                        }
                    }
                    HCard {
                        active: win.page === 12 && win.wanted; order: 1
                        title: updPage.up.phase === "available" && updPage.up.behind !== 0 ? "What is new" : "Latest changes"
                        visible: updPage.up.commits.length > 0
                        Column {
                            width: parent.width; spacing: 0
                            Repeater {
                                model: updPage.up.phase === "available" && updPage.up.behind > 0 ? updPage.up.commits.slice(0, Math.min(updPage.up.behind, 8)) : updPage.up.commits.slice(0, 6)
                                delegate: Item {
                                    required property var modelData
                                    width: parent.width; height: 40
                                    Text { x: 2; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                                        text: modelData.msg; color: main.text; font { family: main.font; pixelSize: 13; weight: 500 } }
                                    Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                        text: updPage.up.ago(modelData.date); color: main.muted; font { family: main.font; pixelSize: 12 } }
                                }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 12 && win.wanted; order: 2; title: "Safety"; collapsible: true
                        Column {
                            width: parent.width; spacing: 0
                            Text { width: parent.width; wrapMode: Text.WordWrap; bottomPadding: 8; color: main.muted; font { family: main.font; pixelSize: 12 }
                                text: "Your settings, presets, custom themes and wallpapers are never touched. A backup of the current shell is saved before every update." }
                            HRow { label: "Undo the last update"; desc: "Put the backup made before the last update back"
                                HButton { label: "Restore backup"; opacity: updPage.up.busy ? 0.5 : 1; onClicked: updPage.up.restore() } }
                        }
                    }
                }

                // ===== About =====
                Page {
                    idx: 13; heading: "About"; sub: "Shortcuts and housekeeping."
                    HCard {
                        active: win.page === 13 && win.wanted; order: 0; title: "Built-in shortcuts"
                        Column {
                            width: parent.width; spacing: 2
                            Repeater {
                                model: [["Super + ,", "Open / close settings"], ["Super + N", "Lock screen"],
                                        ["Alt + Space", "App launcher"], ["Super + Q", "Terminal"], ["Esc", "Close settings"],
                                        ["Up / Down", "Switch settings page"]]
                                Item {
                                    required property var modelData
                                    width: parent.width; height: 34
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: main.text; font { family: main.font; pixelSize: 14 } }
                                    Rectangle {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: keyTxt.implicitWidth + 20; height: 24; radius: 8; color: main.page; border.width: 1; border.color: main.line
                                        Text { id: keyTxt; anchors.centerIn: parent; text: modelData[0]; color: main.accent; font { family: main.font; pixelSize: 12; weight: 600 } }
                                    }
                                }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 13 && win.wanted; order: 1; title: "Housekeeping"; collapsible: true
                        HRow {
                            label: "Reset to defaults"; desc: "Restore Everforest and the original layout"
                            HButton { label: "Reset"; onClicked: win.shell.resetSettings() }
                        }
                    }
                }
            }

            // transient confirmation
            Rectangle {
                id: toastChip
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                height: 34; width: toastText.implicitWidth + 32; radius: 17
                color: main.accent
                opacity: win.shell.toast !== "" ? 1 : 0
                visible: opacity > 0.01
                transform: Translate { y: win.shell.toast !== "" ? 0 : 10
                    Behavior on y { NumberAnimation { duration: main.ms(300); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } } }
                Behavior on opacity { NumberAnimation { duration: main.ms(220) } }
                Text { id: toastText; anchors.centerIn: parent; text: win.shell.toast; color: main.onAccent
                    font { family: main.font; pixelSize: 13; weight: 600 } }
            }
        }
    }

    Timer { id: confirmTimer; interval: 3000; onTriggered: win.confirmDelete = "" }
    Timer { id: lockDelay; interval: 380; onTriggered: win.shell.lockNow() }
}
