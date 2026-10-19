// qmllint disable
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Dynamic island. One pill that morphs, with a springy curve, into whatever is needed:
//   idle       a small pill with the clock
//   bar        hover (or settings open): the full bar, workspaces + clock + status modules
//   activity  a moment of volume / brightness / workspace / charging / now playing
//   menu       the Wi-Fi, Bluetooth or quick settings menu, grown out of the bar
Item {
    id: isl
    required property var bar                       // the Bar window
    readonly property var shell: bar.shell
    anchors.fill: parent

    HoverHandler {
        id: rootHover
        onHoveredChanged: { if (hovered) { isl.hoverHold = true; holdTimer.stop(); } else holdTimer.restart(); }
    }

    // ---------------------------------------------------------------- state
    property string menu: ""                        // network | bluetooth | quick | ""
    property string menuGlyph: ""
    property string menuFrom: ""                    // "quick" when Wi-Fi / Bluetooth was opened from the quick settings menu
    property string activity: ""                   // volume | brightness | workspace | battery | media | ""
    property bool hoverHold: false
    readonly property bool split: shell.cfg.islandSplit     // three separate pieces instead of one pill that grows into the bar
    property bool armed: false
    property bool menuSettled: false
    readonly property string mode: menu !== "" ? "menu"
        : (shell.settingsOpen || (!split && hoverHold)) ? "bar"
        : activity !== "" ? "activity" : "idle"
    readonly property real base: shell.cfg.barHeight
    readonly property real pad: bar.pad
    readonly property bool atBottom: bar.atBottom

    readonly property real leftW: zl.implicitWidth
    readonly property real centerW: zc.implicitWidth
    readonly property real rightW: zr.implicitWidth
    readonly property bool hasC: centerW > 0
    readonly property real side: hasC ? Math.max(leftW, rightW) : 0
    readonly property real pillW: hasC ? side * 2 + centerW + bar.gap * 2 + pad * 2
                                       : leftW + rightW + ((leftW > 0 && rightW > 0) ? bar.gap * 2 : 0) + pad * 2
    readonly property real collapsedW: Math.max(centerW + 28, 64) + (!!player && player.isPlaying ? 26 : 0)

    function openMenu(kind, glyph, from) {
        if (menu === kind) { closeMenu(); return; }
        menuFrom = from || "";
        menuGlyph = glyph;
        menu = kind;
        menuSettled = false;
        settleTimer.restart();
        activity = "";
    }
    function stackGlyph(k) { return stack.glyphFor(k); }
    function closeMenu() {  menu = ""; menuFrom = ""; menuSettled = false; }
    // from Wi-Fi / Bluetooth back to the quick settings menu it was opened from
    function goBack() { if (menuFrom !== "") { const k = menuFrom; openMenu(k, stack.glyphFor(k), ""); } else closeMenu(); }
    function peek(kind) {
        if (!armed || menu !== "") return;
        activity = kind;
        peekTimer.restart();
    }
    Timer { id: armTimer; interval: 3500; running: true; onTriggered: isl.armed = true }
    Timer { id: peekTimer; interval: 2300; onTriggered: isl.activity = "" }
    Timer { id: settleTimer; interval: 650; onTriggered: isl.menuSettled = true }
    Timer { id: holdTimer; interval: 420; onTriggered: isl.hoverHold = false }
    Timer { id: clockTimer; interval: 700; onTriggered: isl.bar.updateClock() }
    onModeChanged: { clockTimer.restart(); shapeChanged(); }
    onMenuChanged: shapeChanged()

    Component.onCompleted: { bar.islandRef = isl; bar.islandSurface = surface; }
    Component.onDestruction: { if (bar.islandRef === isl) { bar.islandRef = null; bar.islandSurface = null; bar.islandMenu = ""; } }
    Binding { target: isl.bar; property: "islandMenu"; value: isl.menu }

    // ---------------------------------------------------------------- what makes the island react
    Connections { target: Hyprland; function onFocusedWorkspaceChanged() { isl.peek("workspace"); } }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool soundReady: !!sink && sink.ready && !!sink.audio
    readonly property int volPct: soundReady ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: soundReady && sink.audio.muted
    Connections {
        target: isl.soundReady ? isl.sink.audio : null
        function onVolumeChanged() { isl.peek("volume"); }
        function onMutedChanged() { isl.peek("volume"); }
    }
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.isPresent && battery.isLaptopBattery
    readonly property int level: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: !!battery && battery.state === UPowerDeviceState.Charging
    Connections { target: isl.battery; function onStateChanged() { if (isl.hasBattery) isl.peek("battery"); } }

    BacklightReader { id: backlight; running: isl.bar.island }
    readonly property int bright: backlight.percent
    onBrightChanged: if (backlight.percent >= 0 && prevBright >= 0 && bright !== prevBright) { peek("brightness"); prevBright = bright; } else prevBright = bright
    property int prevBright: -1

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }
    Connections { target: isl.player; ignoreUnknownSignals: true
        function onTrackTitleChanged() { if (isl.player && isl.player.isPlaying) isl.peek("media"); }
        function onIsPlayingChanged() { if (isl.player) isl.peek("media"); } }

    // ---------------------------------------------------------------- the shape
    property var lastH: ({ "network": 380, "bluetooth": 300, "quick": 430, "notifications": 300, "calendar": 440, "media": 330, "sound": 360, "display": 300 })
    readonly property var menuItem: stack.item
    readonly property real menuH: menu === "" ? 0 : Math.min(bar.maxMenuH, menuItem ? menuItem.wantedHeight : lastH[menu])
    onMenuHChanged: if (menu !== "" && menuItem) lastH[menu] = menuH
    readonly property real transientW: activity === "volume" || activity === "brightness" ? 250
        : activity === "workspace" ? wsPane.implicitWidth + 40
        : activity === "battery" ? 200 : activity === "media" ? 330 : 0
    readonly property real targetW: mode === "menu" ? 360 : mode === "bar" ? pillW : mode === "activity" ? transientW : collapsedW
    readonly property real targetH: mode === "menu" ? menuH : mode === "bar" ? base : mode === "activity" ? base + 14 : base - (split ? 2 : 6)

    // a little overshoot on every size change, like a spring
    readonly property var spring: [0.34, 1.2, 0.64, 1, 1, 1]
    // The spring is for changing shape (idle <-> bar <-> menu). Smaller size changes caused by the content itself
    // (a label getting longer, a list loading, a slider row appearing) glide without bouncing, so nothing shakes.
    property bool reshaping: false
    function shapeChanged() { reshaping = true; reshapeTimer.restart(); }
    Timer { id: reshapeTimer; interval: 620; onTriggered: isl.reshaping = false }
    Rectangle {
        id: surface
        width: isl.targetW
        height: isl.targetH
        Behavior on width {
            SpringAnimation {
                spring: isl.reshaping ? 2.6 : 4.2
                damping: isl.reshaping ? 0.46 - 0.30 * Math.max(0, Math.min(1, shell.cfg.motionBounce)) : 0.62
                epsilon: 0.25
            }
        }
        Behavior on height {
            SpringAnimation {
                spring: isl.reshaping ? 2.6 : 4.2
                damping: isl.reshaping ? 0.46 - 0.30 * Math.max(0, Math.min(1, shell.cfg.motionBounce)) : 0.62
                epsilon: 0.25
            }
        }
        x: (parent.width - width) / 2
        y: isl.atBottom ? parent.height - height - bar.islandGap : bar.islandGap
        radius: Math.min(height / 2, bar.radius + (isl.mode === "menu" || isl.mode === "activity" ? 7 : 0))
        color: main.bg
        border.color: main.border
        border.width: 1
        // menus are nearly opaque so text behind them never makes them hard to read
        opacity: Math.max(bar.bgAlpha, isl.mode === "menu" && !shell.cfg.glassBar ? 0.97 : 0) * bar.intro
        Behavior on opacity { NumberAnimation { duration: main.ms(260) } }
        transform: Translate { y: (1 - bar.intro) * (isl.atBottom ? 14 : -14) }
    }
    SoftShadow {
        z: -1
        visible: !shell.cfg.glassBar                      // frosted glass has no drop shadow
        x: surface.x; y: surface.y; width: surface.width; height: surface.height
        radius: surface.radius; opacity: bar.intro
    }

    // ---------------------------------------------------------------- the side pieces of the split island
    readonly property real pieceH: base - 2
    readonly property real pieceGap: 8
    readonly property bool piecesOn: split && (mode === "idle" || mode === "activity")
    // The input region must not follow the animation (the compositor would be told a new region every frame):
    // it is the bounding box of where the island is going, kept until the motion has settled.
    property real bbW: collapsedW
    property real bbH: base
    readonly property real sideMax: split ? 2 * (pieceGap + pieceH) + 12 : 0
    readonly property real sideExtra: piecesOn ? pieceGap + pieceH + 6 + (shell.notifier.dnd ? pieceGap + pieceH : 0) : 0
    onTargetWChanged: { bbW = Math.max(bbW, targetW); bbShrink.restart(); }
    onTargetHChanged: { bbH = Math.max(bbH, targetH); bbShrink.restart(); }
    Timer { id: bbShrink; interval: 900; onTriggered: { isl.bbW = isl.targetW; isl.bbH = isl.targetH; } }
    readonly property real extL: (width - bbW) / 2 - sideExtra
    readonly property real extR: width - extL
    readonly property real pieceY: atBottom ? surface.y + surface.height - pieceH : surface.y
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    readonly property var wifiNet: wifiDev ? wifiDev.networks.values.find(n => n.connected) : null
    readonly property int wifiLevel: !Networking.wifiEnabled || !wifiNet ? 0 : (wifiNet.signalStrength >= 0.75 ? 4 : wifiNet.signalStrength >= 0.5 ? 3 : wifiNet.signalStrength >= 0.25 ? 2 : 1)

    component Piece: Item {
        id: pc
        property string glyph: ""
        property bool lit: false
        default property alias content: inner.data
        signal clicked()
        property bool shown: isl.split && (isl.mode === "idle" || isl.mode === "activity")
        visible: opacity > 0.01
        width: isl.pieceH; height: isl.pieceH
        y: isl.pieceY
        Behavior on y { SpringAnimation { spring: 3.2; damping: 0.5; epsilon: 0.25 } }
        opacity: shown ? bar.intro : 0
        Behavior on opacity { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
        scale: hov.hovered ? 1.14 : 1
        transformOrigin: Item.Center
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.002 } }
        SoftShadow { z: -1; visible: !isl.shell.cfg.glassBar; anchors.fill: parent; radius: width / 2; opacity: bar.intro }
        Rectangle {
            id: disc
            anchors.fill: parent; radius: width / 2
            color: main.bg; border.width: 1; border.color: pc.lit ? main.accent : main.border
            opacity: bar.bgAlpha
        }
        Item { id: inner; anchors.fill: parent }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pc.clicked() }
    }

    Piece {
        id: leftPiece
        x: surface.x - isl.pieceGap - width
        lit: isl.menu === "media"
        onClicked: { if (isl.player) isl.openMenu("media", stack.glyphFor("media"), ""); else isl.shell.toggleLauncher(); }
        Rectangle {
            anchors.centerIn: parent; width: parent.width - 6; height: width; radius: width / 2; clip: true; color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.2)
            Image {
                anchors.fill: parent; visible: status === Image.Ready
                source: isl.player && isl.player.trackArtUrl ? isl.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; sourceSize: Qt.size(64, 64)
            }
            CenteredGlyph {
                visible: !isl.player || !isl.player.trackArtUrl
                glyph: String.fromCodePoint(isl.player ? 0xF075A : 0xF003B); color: main.accent; size: main.barPx
            }
        }
    }
    Piece {
        id: rightPiece
        x: surface.x + surface.width + isl.pieceGap
        lit: isl.menu === "quick"
        onClicked: isl.openMenu("quick", stack.glyphFor("quick"), "")
        BatteryRing {
            anchors.fill: parent; anchors.margins: 1
            present: isl.hasBattery; level: isl.level; charging: isl.charging; tint: main.accent
            stroke: Math.max(2, parent.width * 0.1)
        }
        CenteredGlyph {
            glyph: String.fromCodePoint(!Networking.wifiEnabled ? 0xF05AA : isl.wifiNet ? 0xF091F + (Math.max(1, isl.wifiLevel) - 1) * 3 : 0xF092D)
            color: main.icon; size: parent.width * 0.5
        }
    }
    Piece {
        id: moonPiece
        shown: isl.split && (isl.mode === "idle" || isl.mode === "activity") && isl.shell.notifier.dnd
        x: rightPiece.x + rightPiece.width + isl.pieceGap
        onClicked: isl.shell.notifier.dnd = false
        Text { anchors.centerIn: parent; text: String.fromCodePoint(0xF0594); color: main.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: main.barPx } }
    }

    // ---------------------------------------------------------------- the content (separate from the shape so the shadow stays clean)
    Item {
        id: overlay
        x: surface.x; y: surface.y; width: surface.width; height: surface.height
        opacity: bar.intro
        clip: true

        // bar: workspaces + clock + modules (idle shows only the clock)
        IslandPane {
            id: barPane
            anchors.fill: parent
            on: isl.mode === "idle" || isl.mode === "bar"
            BarZone {
                id: zl; bar: isl.bar; name: "left"; ids: isl.bar.island ? isl.bar.mods.left : []
                anchors.verticalCenter: parent.verticalCenter
                x: isl.pad - 5
                opacity: Math.max(0, Math.min(1, (surface.width - isl.collapsedW) / Math.max(1, isl.pillW - isl.collapsedW) * 1.6 - 0.6))
                enabled: isl.mode === "bar"
            }
            EqBars {
                visible: isl.mode === "idle" && !!isl.player && isl.player.isPlaying
                running: visible
                size: 13
                anchors.verticalCenter: parent.verticalCenter
                x: zc.x - width - 8
            }
            BarZone {
                id: zc; bar: isl.bar; name: "center"; ids: isl.bar.island ? isl.bar.mods.center : []
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - implicitWidth) / 2
            }
            BarZone {
                id: zr; bar: isl.bar; name: "right"; ids: isl.bar.island ? isl.bar.mods.right : []
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - implicitWidth - isl.pad + 5
                opacity: zl.opacity
                enabled: isl.mode === "bar"
            }
        }

        // ---- volume
        IslandPane {
            anchors.fill: parent
            on: isl.mode === "activity" && isl.activity === "volume"
            Row {
                anchors.centerIn: parent; spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: isl.muted || isl.volPct === 0 ? "󰸈" : (isl.volPct < 34 ? String.fromCodePoint(0xF057F) : isl.volPct < 67 ? String.fromCodePoint(0xF0580) : String.fromCodePoint(0xF057E))
                    color: main.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter; width: 120; height: 6; radius: 3; color: main.line
                    Rectangle {
                        height: parent.height; radius: 3; color: isl.muted ? main.muted : main.accent
                        width: parent.width * (isl.muted ? 0 : Math.min(1, isl.volPct / 100))
                        Behavior on width { NumberAnimation { duration: main.ms(180); easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter; width: 44; horizontalAlignment: Text.AlignRight
                    text: isl.muted ? "Muted" : isl.volPct + "%"; color: main.text
                    font { family: main.font; pixelSize: 13; weight: 600 }
                }
            }
        }

        // ---- brightness
        IslandPane {
            anchors.fill: parent
            on: isl.mode === "activity" && isl.activity === "brightness"
            Row {
                anchors.centerIn: parent; spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(isl.bright < 34 ? 0xF00DE : isl.bright < 67 ? 0xF00DF : 0xF00E0)
                    color: main.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter; width: 120; height: 6; radius: 3; color: main.line
                    Rectangle {
                        height: parent.height; radius: 3; color: main.accent
                        width: parent.width * Math.max(0, Math.min(1, isl.bright / 100))
                        Behavior on width { NumberAnimation { duration: main.ms(180); easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter; width: 44; horizontalAlignment: Text.AlignRight
                    text: isl.bright + "%"; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 }
                }
            }
        }

        // ---- workspace switch
        IslandPane {
            anchors.fill: parent
            on: isl.mode === "activity" && isl.activity === "workspace"
            Workspaces { id: wsPane; bar: isl.bar; anchors.centerIn: parent }
        }

        // ---- charging
        IslandPane {
            anchors.fill: parent
            on: isl.mode === "activity" && isl.activity === "battery"
            Row {
                anchors.centerIn: parent; spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(isl.charging ? 0xF0084 : (isl.level >= 100 ? 0xF0079 : isl.level < 10 ? 0xF0083 : 0xF007A + (Math.floor(isl.level / 10) - 1)))
                    color: isl.charging ? main.accent : (isl.level <= 15 ? "#ff002f" : main.text)
                    font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: isl.level + "%  ·  " + (isl.charging ? "Charging" : "On battery"); color: main.text
                    font { family: main.font; pixelSize: 13; weight: 600 }
                }
            }
        }

        // ---- now playing
        IslandPane {
            anchors.fill: parent
            on: isl.mode === "activity" && isl.activity === "media"
            Row {
                anchors.centerIn: parent; spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: isl.player && isl.player.isPlaying ? String.fromCodePoint(0xF0386) : String.fromCodePoint(0xF03E4)
                    color: main.accent; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; width: 250
                    Text { width: parent.width; elide: Text.ElideRight; color: main.text
                        text: isl.player && isl.player.trackTitle ? isl.player.trackTitle : "Nothing playing"
                        font { family: main.font; pixelSize: 13; weight: 600 } }
                    Text { width: parent.width; elide: Text.ElideRight; color: main.muted
                        visible: !!isl.player && !!isl.player.trackArtist; text: isl.player ? isl.player.trackArtist : ""
                        font { family: main.font; pixelSize: 11 } }
                }
            }
        }

        // ---- menus, preloaded so the first open does not stutter
        IslandPane {
            id: menuHost
            anchors.fill: parent
            on: isl.mode === "menu"
            // keyboard: Escape closes the menu (or just leaves a text field)
            FocusScope {
                id: keys
                anchors.fill: parent
                focus: isl.mode === "menu"
                onVisibleChanged: if (visible && isl.mode === "menu") forceActiveFocus()
                Keys.onEscapePressed: {
                    if (stack.typing) keys.forceActiveFocus(); else isl.goBack();
                }
            }
            Text {
                x: 18; y: 14; text: isl.menuGlyph; color: main.accent
                visible: isl.menuFrom === ""
                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 }
            }
            BackButton { x: 10; y: 9; visible: isl.menuFrom !== ""; onClicked: isl.goBack() }
            MenuStack {
                id: stack
                width: 360; height: parent.height
                menu: isl.menu; settled: isl.menuSettled; shell: isl.shell; from: isl.menuFrom
                onRequestMenu: k => isl.openMenu(k, stack.glyphFor(k), isl.menu)
                onRequestClose: isl.closeMenu()
            }
        }
    }

    // a click anywhere else closes the menu: a transparent full-screen window that takes input everywhere except on the island
    PanelWindow {
        id: catcher
        screen: isl.bar.screen
        visible: isl.menu !== ""
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-island-catcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            x: 0; y: 0; width: catcher.width; height: catcher.height
            Region {
                intersection: Intersection.Subtract
                x: (isl.bar.pill ? (catcher.width - isl.bar.width) / 2 : isl.bar.margins.left) + isl.bar.maskX
                y: (isl.atBottom ? catcher.height - isl.bar.margins.bottom - isl.bar.height : isl.bar.margins.top) + isl.bar.maskY
                width: isl.bar.maskW
                height: isl.bar.maskH
            }
        }
        MouseArea { anchors.fill: parent; onClicked: isl.closeMenu() }
    }
}
