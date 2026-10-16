// qmllint disable
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    readonly property string quickGlyph: String.fromCodePoint(0xF0570)
    property string activity: ""                   // volume | brightness | workspace | battery | media | ""
    property bool hoverHold: false
    property bool armed: false
    property bool menuSettled: false
    readonly property string mode: menu !== "" ? "menu"
        : (hoverHold || shell.settingsOpen) ? "bar"
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
    readonly property real collapsedW: Math.max(centerW + 28, 64)

    function openMenu(kind, glyph, from) {
        if (menu === kind) { closeMenu(); return; }
        menuFrom = from || "";
        menuGlyph = glyph;
        menu = kind;
        menuSettled = false;
        settleTimer.restart();
        activity = "";
    }
    function closeMenu() {  menu = ""; menuFrom = ""; menuSettled = false; }
    // from Wi-Fi / Bluetooth back to the quick settings menu it was opened from
    function goBack() { if (menuFrom === "quick") openMenu("quick", quickGlyph, ""); else closeMenu(); }
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

    property int bright: -1
    Process {
        id: brightReader
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                if (f.length < 5 || f[1] !== "backlight") return;
                const v = parseInt(f[3]);
                if (isl.bright >= 0 && v !== isl.bright) isl.peek("brightness");
                isl.bright = v;
            }
        }
    }
    Timer { interval: 1000; running: isl.bar.island; repeat: true; triggeredOnStart: true; onTriggered: brightReader.running = true }

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }
    Connections { target: isl.player; ignoreUnknownSignals: true
        function onTrackTitleChanged() { if (isl.player && isl.player.isPlaying) isl.peek("media"); }
        function onIsPlayingChanged() { if (isl.player) isl.peek("media"); } }

    // ---------------------------------------------------------------- the shape
    property var lastH: ({ "network": 380, "bluetooth": 300, "quick": 430 })
    readonly property var menuItem: menu === "network" ? netLoader.item : menu === "bluetooth" ? btLoader.item : menu === "quick" ? quickLoader.item : null
    readonly property real menuH: menu === "" ? 0 : Math.min(bar.maxMenuH, menuItem ? menuItem.wantedHeight : lastH[menu])
    onMenuHChanged: if (menu !== "" && menuItem) lastH[menu] = menuH
    readonly property real transientW: activity === "volume" || activity === "brightness" ? 250
        : activity === "workspace" ? wsPane.implicitWidth + 40
        : activity === "battery" ? 200 : activity === "media" ? 330 : 0
    readonly property real targetW: mode === "menu" ? 360 : mode === "bar" ? pillW : mode === "activity" ? transientW : collapsedW
    readonly property real targetH: mode === "menu" ? menuH : mode === "bar" ? base : mode === "activity" ? base + 14 : base - 6

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
            NumberAnimation {
                duration: main.ms(isl.reshaping ? 560 : 280)
                easing.type: isl.reshaping ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: isl.spring
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: main.ms(isl.reshaping ? 560 : 280)
                easing.type: isl.reshaping ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: isl.spring
            }
        }
        x: (parent.width - width) / 2
        y: isl.atBottom ? parent.height - height - bar.islandGap : bar.islandGap
        radius: Math.min(height / 2, bar.radius + (isl.mode === "menu" || isl.mode === "activity" ? 7 : 0))
        color: main.bg
        border.color: main.border
        border.width: 1
        // menus are nearly opaque so text behind them never makes them hard to read
        opacity: Math.max(bar.bgAlpha, isl.mode === "menu" ? 0.97 : 0) * bar.intro
        Behavior on opacity { NumberAnimation { duration: main.ms(260) } }
        transform: Translate { y: (1 - bar.intro) * (isl.atBottom ? 14 : -14) }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.38
            shadowBlur: 0.7; shadowVerticalOffset: 3; shadowHorizontalOffset: 0
        }
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
                    const it = isl.menu === "network" ? netLoader.item : isl.menu === "bluetooth" ? btLoader.item : quickLoader.item;
                    if (it && it.typing) keys.forceActiveFocus(); else isl.goBack();
                }
            }
            Text {
                x: 18; y: 14; text: isl.menuGlyph; color: main.accent
                visible: isl.menuFrom === ""
                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 }
            }
            BackButton { x: 10; y: 9; visible: isl.menuFrom !== ""; onClicked: isl.goBack() }
            Loader {
                id: netLoader; width: 360; height: parent.height; asynchronous: true
                visible: isl.menu === "network"
                sourceComponent: NetworkPopup { active: isl.menu === "network"; settled: active && isl.menuSettled }
            }
            Loader {
                id: btLoader; width: 360; height: parent.height; asynchronous: true
                visible: isl.menu === "bluetooth"
                sourceComponent: BluetoothPopup { active: isl.menu === "bluetooth"; settled: active && isl.menuSettled }
            }
            Loader {
                id: quickLoader; width: 360; height: parent.height; asynchronous: true
                visible: isl.menu === "quick"
                sourceComponent: QuickPopup {
                    active: isl.menu === "quick"; settled: active && isl.menuSettled; shell: isl.shell
                    onRequestMenu: kind => isl.openMenu(kind, kind === "network" ? String.fromCodePoint(0xF05A9) : String.fromCodePoint(0xF00AF), "quick")
                    onRequestClose: isl.closeMenu()
                }
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
