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
    readonly property var pages: ["Appearance", "Creator", "Bar", "Modules", "Windows", "Input", "Glass", "System", "About"]
    property bool typing: false
    property bool accentPicker: false
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
    Rectangle {
        id: scrim
        x: 0; width: parent.width; y: inputArea.y; height: inputArea.height
        readonly property real fadeFrac: Math.min(0.5, 26 / Math.max(1, height))
        gradient: Gradient {
            GradientStop { position: 0; color: win.barBottom ? Qt.rgba(0, 0, 0, win.scrimK) : Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: win.barBottom ? 1 - scrim.fadeFrac : scrim.fadeFrac
                color: Qt.rgba(0, 0, 0, win.scrimK) }
            GradientStop { position: 1; color: win.barBottom ? Qt.rgba(0, 0, 0, 0) : Qt.rgba(0, 0, 0, win.scrimK) }
        }
        MouseArea { anchors.fill: parent; onClicked: win.shell.closeSettings() }
    }

    FocusScope {
        anchors.fill: parent
        focus: win.wanted
        id: keyScope
        Keys.onEscapePressed: { if (win.typing) { keyScope.forceActiveFocus(); } else { win.shell.closeSettings(); } }
        Keys.onPressed: ev => {
            if (win.typing) return;
            if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab) { win.page = (win.page + 1) % win.pages.length; ev.accepted = true; }
            else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) { win.page = (win.page + win.pages.length - 1) % win.pages.length; ev.accepted = true; }
        }

        Rectangle {
            id: panel
            width: Math.min(1000, parent.width - 60)
            height: Math.min(780, parent.height - win.barZone - 40)
            x: (parent.width - width) / 2
            y: (win.barBottom ? 0 : win.barZone) + (parent.height - win.barZone - height) / 2
            radius: 24; color: Qt.rgba(main.page.r, main.page.g, main.page.b, main.panelAlpha)
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
                x: 0; y: 0; width: 220; height: parent.height
                Text {
                    x: 28; y: 30; text: "Settings"; color: main.text
                    font { family: main.serif; pixelSize: 26 }
                }
                Text {
                    x: 28; y: 70; text: "MAKE IT YOURS"; color: main.muted
                    font { family: main.font; pixelSize: 11; weight: 700; letterSpacing: 1.2 }
                }
                Rectangle {   // sliding selection pill
                    x: 14; width: nav.width - 28; height: 40; radius: 12
                    y: 104 + win.page * 46
                    color: main.card; border.width: 1; border.color: main.line
                    Behavior on y { NumberAnimation { duration: main.ms(340); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } }
                    Rectangle { x: 0; width: 3; height: 18; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: main.accent }
                }
                Repeater {
                    model: win.pages
                    Item {
                        required property int index
                        required property string modelData
                        x: 14; y: 104 + index * 46; width: nav.width - 28; height: 40
                        Text {
                            x: 18; anchors.verticalCenter: parent.verticalCenter; text: modelData
                            color: win.page === index ? main.accent : (hover.containsMouse ? main.text : main.muted)
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
            Rectangle { x: nav.width; y: 20; width: 1; height: parent.height - 40; color: main.line }

            // ---------------- pages ----------------
            Item {
                id: content
                x: nav.width + 1; width: parent.width - x; height: parent.height
                clip: true

                component Page: Flickable {
                    id: pg
                    required property int idx
                    property string heading: ""
                    property string sub: ""
                    default property alias items: stack.data
                    readonly property bool current: win.page === idx
                    anchors.fill: parent
                    contentWidth: width; contentHeight: stack.y + stack.height + 32
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    visible: opacity > 0.01
                    opacity: current && win.wanted ? 1 : 0
                    transform: Translate {
                        x: pg.current ? 0 : (win.page > pg.idx ? -28 : 28)
                        Behavior on x { NumberAnimation { duration: main.ms(420); easing.type: Easing.BezierSpline; easing.bezierCurve: win.ease } }
                    }
                    Behavior on opacity { NumberAnimation { duration: main.ms(240); easing.type: Easing.OutCubic } }
                    Text { x: 32; y: 30; text: pg.heading; color: main.text; font { family: main.serif; pixelSize: 28 } }
                    Text { x: 32; y: 70; text: pg.sub; color: main.muted; font { family: main.font; pixelSize: 13 } }
                    Column { id: stack; x: 32; y: 108; width: pg.width - 64; spacing: 14 }
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
                        active: win.page === 0 && win.wanted; order: 1; title: "Quick looks"
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
                        active: win.page === 0 && win.wanted; order: 2; title: "Accent and text"
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
                        active: win.page === 0 && win.wanted; order: 3; title: "Wallpaper"
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
                    idx: 2; heading: "Bar"; sub: "Pick a layout, then fine-tune it."
                    HCard {
                        active: win.page === 2 && win.wanted; order: 0; title: "Layout"
                        Column {
                            width: parent.width; spacing: 14
                            Row {
                                spacing: 8
                                Repeater {
                                    model: [["classic", "Classic"], ["pill", "Pill"], ["islands", "Islands"], ["flat", "Flat"], ["minimal", "Minimal"]]
                                    StyleCard {
                                        required property var modelData
                                        styleId: modelData[0]; label: modelData[1]
                                        selected: win.cfg.barStyle === modelData[0]
                                        width: (parent.parent.width - 32) / 5
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
                                         "minimal": "No surface at all, just the content." })[win.cfg.barStyle]
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
                        active: win.page === 2 && win.wanted; order: 1; title: "Look"
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Bar opacity"; desc: "How see-through the bar background is"
                                from: 0.35; to: 1; step: 0.01; value: win.cfg.barOpacity; onMoved: v => win.put("barOpacity", v) }
                            HSliderRow { label: "Bar roundness"; desc: "Corner radius of the bar"
                                from: 0; to: 15; step: 1; decimals: 0; unit: " px"; value: win.cfg.barRadius; onMoved: v => win.put("barRadius", v) }
                            HRow { label: "24-hour clock"; desc: "Use 14:30 instead of 2:30 PM"
                                HToggle { checked: win.cfg.clock24; onToggled: v => win.put("clock24", v) } }
                            HRow { label: "Show seconds"; desc: "Tick every second in the bar"
                                HToggle { checked: win.cfg.clockSeconds; onToggled: v => win.put("clockSeconds", v) } }
                            HAdvanced {
                                title: "More bar options"
                                HSliderRow { label: "Bar height"; desc: "Thickness of the bar"
                                    from: 22; to: 44; step: 1; decimals: 0; unit: " px"; value: win.cfg.barHeight; onMoved: v => win.put("barHeight", v) }
                                HSliderRow { label: "Top gap"; desc: "Space between the bar and the screen edge"
                                    from: 0; to: 16; step: 1; decimals: 0; unit: " px"; value: win.cfg.barGap; onMoved: v => win.put("barGap", v) }
                                HSliderRow { label: "Side gap"; desc: "Space at the left and right"
                                    from: 0; to: 40; step: 1; decimals: 0; unit: " px"; value: win.cfg.barSide; onMoved: v => win.put("barSide", v) }
                                HSliderRow { label: "Text size"; desc: "Size of bar text and icons"
                                    from: 11; to: 17; step: 1; decimals: 0; unit: " px"; value: win.cfg.barFont; onMoved: v => win.put("barFont", v) }
                                HSliderRow { label: "Module spacing"; desc: "Extra room between modules"
                                    from: 0; to: 16; step: 1; decimals: 0; unit: " px"; value: win.cfg.modSpacing; onMoved: v => win.put("modSpacing", v) }
                                HRow { label: "Icon colours"; desc: "Accent, plain text, or one colour per module"
                                    HSegment { readonly property var keys: ["accent", "text", "colour"]
                                        options: ["Accent", "Text", "Colourful"]; segWidth: 76
                                        current: Math.max(0, keys.indexOf(win.cfg.iconMode)); onPicked: i => win.put("iconMode", keys[i]) } }
                                HRow { label: "Workspace style"; desc: "How the workspace indicators look"
                                    HSegment { readonly property var keys: ["pills", "dots", "numbers"]
                                        options: ["Pills", "Dots", "Numbers"]; segWidth: 72
                                        current: Math.max(0, keys.indexOf(win.cfg.wsStyle)); onPicked: i => win.put("wsStyle", keys[i]) } }
                                HSliderRow { label: "Workspaces shown"; desc: "How many workspaces appear"
                                    from: 3; to: 10; step: 1; decimals: 0; value: win.cfg.wsCount; onMoved: v => win.put("wsCount", v) }
                                HRow { label: "Hide empty workspaces"; desc: "Only show workspaces that are in use"
                                    HToggle { checked: win.cfg.wsOccupiedOnly; onToggled: v => win.put("wsOccupiedOnly", v) } }
                                HRow { label: "Date in the clock"; desc: "Show the weekday and date next to the time"
                                    HToggle { checked: win.cfg.clockDate; onToggled: v => win.put("clockDate", v) } }
                            }
                        }
                    }
                    HCard {
                        active: win.page === 2 && win.wanted; order: 2; title: "Session"
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
                                    width: parent.width; height: 56
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter; width: parent.width - 330
                                        spacing: 1
                                        Text { text: mrow.info.label; color: mrow.zone === "" ? main.muted : main.text
                                            font { family: main.font; pixelSize: 14; weight: 600 } }
                                        Text { width: parent.width; elide: Text.ElideRight; text: mrow.info.desc; color: main.muted
                                            font { family: main.font; pixelSize: 12 } }
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
                        active: win.page === 3 && win.wanted; order: 1; title: "Text next to icons"
                        Column {
                            width: parent.width; spacing: 2
                            HRow { label: "Volume"; desc: "Show the percentage"
                                HToggle { checked: win.cfg.labelVolume; onToggled: v => win.put("labelVolume", v) } }
                            HRow { label: "Brightness"; desc: "Show the percentage"
                                HToggle { checked: win.cfg.labelBrightness; onToggled: v => win.put("labelBrightness", v) } }
                            HRow { label: "Network"; desc: "Show the Wi-Fi name"
                                HToggle { checked: win.cfg.labelNetwork; onToggled: v => win.put("labelNetwork", v) } }
                            HRow { label: "Bluetooth"; desc: "Show the connected device"
                                HToggle { checked: win.cfg.labelBluetooth; onToggled: v => win.put("labelBluetooth", v) } }
                            HRow { label: "Battery"; desc: "Show the percentage"
                                HToggle { checked: win.cfg.labelBattery; onToggled: v => win.put("labelBattery", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 3 && win.wanted; order: 2; title: "Good to know"
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
                                HSliderRow { label: "Shadow size"; desc: "How far the shadow reaches"
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
                            HRow { label: "Natural scrolling"; desc: "Content moves with your fingers on the touchpad"
                                HToggle { checked: win.cfg.naturalScroll; onToggled: v => win.put("naturalScroll", v) } }
                            HRow { label: "Tap to click"; desc: "Tap the touchpad instead of pressing it"
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
                            HRow { label: "Status bar"; desc: "The bar becomes see-through and blurs what is behind it"
                                HToggle { checked: win.cfg.glassBar; onToggled: v => win.put("glassBar", v) } }
                            HRow { label: "Settings panel"; desc: "This window"
                                HToggle { checked: win.cfg.glassPanel; onToggled: v => win.put("glassPanel", v) } }
                            HRow { label: "App launcher"; desc: "Rofi, applied on next open"
                                HToggle { checked: win.cfg.glassLauncher; onToggled: v => win.put("glassLauncher", v) } }
                            HRow { label: "Terminal"; desc: "Kitty windows, reloaded live"
                                HToggle { checked: win.cfg.glassTerminal; onToggled: v => win.put("glassTerminal", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 6 && win.wanted; order: 1; title: "Tuning"
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
                            HRow { label: "Kitty"; desc: "Terminal colours, reloaded live"
                                HToggle { checked: win.cfg.syncKitty; onToggled: v => win.put("syncKitty", v) } }
                            HRow { label: "Fish"; desc: "Prompt and syntax colours in every open shell"
                                HToggle { checked: win.cfg.syncFish; onToggled: v => win.put("syncFish", v) } }
                            HRow { label: "Rofi"; desc: "App launcher, applied on next open"
                                HToggle { checked: win.cfg.syncRofi; onToggled: v => win.put("syncRofi", v) } }
                            HRow { label: "GTK apps"; desc: "Accent and surfaces, applied when an app starts"
                                HToggle { checked: win.cfg.syncGtk; onToggled: v => win.put("syncGtk", v) } }
                            HRow { label: "Hyprlock"; desc: "The Super + Shift + X lock screen"
                                HToggle { checked: win.cfg.syncLock; onToggled: v => win.put("syncLock", v) } }
                        }
                    }
                    HCard {
                        active: win.page === 7 && win.wanted; order: 1; title: "Terminal"
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
                            HRow { label: "Apply now"; desc: "Re-write every themed config file"
                                HButton { label: "Re-apply"; onClicked: win.shell.reapply() } }
                        }
                    }
                    HCard {
                        active: win.page === 7 && win.wanted; order: 2; title: "App launcher"
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
                    HCard {
                        active: win.page === 7 && win.wanted; order: 3; title: "Lock screen"
                        Column {
                            width: parent.width; spacing: 4
                            HSliderRow { label: "Clock size"; desc: "Size of the big lock-screen clock"
                                from: 64; to: 140; step: 4; decimals: 0; unit: " px"; value: win.cfg.lockClockSize; onMoved: v => win.put("lockClockSize", v) }
                            HSliderRow { label: "Background blur"; desc: "How blurred the screen behind the lock is"
                                from: 0; to: 1; step: 0.05; value: win.cfg.lockBlur; onMoved: v => win.put("lockBlur", v) }
                            HRow { label: "Show the date"; desc: "A line with the day and date above the clock"
                                HToggle { checked: win.cfg.lockDate; onToggled: v => win.put("lockDate", v) } }
                        }
                    }
                }

                // ===== About =====
                Page {
                    idx: 8; heading: "About"; sub: "Shortcuts and housekeeping."
                    HCard {
                        active: win.page === 8 && win.wanted; order: 0; title: "Shortcuts"
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
                        active: win.page === 8 && win.wanted; order: 1; title: "Housekeeping"
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

    Timer { id: lockDelay; interval: 380; onTriggered: win.shell.lockNow() }
}
