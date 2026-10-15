// qmllint disable
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Status bar with switchable presets (classic, pill, islands, flat, minimal, notch, dynamic island) and
// user-chosen modules in three zones (left, centre, right).
PanelWindow {
    id: win
    required property var shell

    readonly property string style: shell.cfg.barStyle
    readonly property bool atBottom: shell.cfg.barPos === "bottom"
    // pill, notch and island share one compact, centred layout
    readonly property bool pill: style === "pill" || style === "notch" || style === "island"
    readonly property bool island: style === "island"
    readonly property bool notch: style === "notch"
    readonly property bool edgeFlush: style === "flat" || style === "notch"
    readonly property real bgAlpha: shell.cfg.glassBar ? Math.max(0.35, 1 - shell.cfg.glassAmount) : shell.cfg.barOpacity
    readonly property real radius: shell.cfg.barRadius
    readonly property real pad: 14
    readonly property real gap: 12
    readonly property var mods: shell.cfg.modules
    property real intro: 0

    // zone geometry
    readonly property real leftW: zl.implicitWidth
    readonly property real centerW: zc.implicitWidth
    readonly property real rightW: zr.implicitWidth
    readonly property bool hasC: centerW > 0
    readonly property real side: hasC ? Math.max(leftW, rightW) : 0
    readonly property real pillW: hasC ? side * 2 + centerW + gap * 2 + pad * 2
                                       : leftW + rightW + ((leftW > 0 && rightW > 0) ? gap * 2 : 0) + pad * 2

    color: "transparent"
    implicitHeight: shell.cfg.barHeight
    implicitWidth: pill ? pillW : 0
    WlrLayershell.namespace: "quickshell-bar"
    mask: Region { item: win.island ? islandSurface : fullRect }
    Item { id: fullRect; anchors.fill: parent; visible: false }

    anchors {
        top: !win.atBottom
        bottom: win.atBottom
        left: !win.pill
        right: !win.pill
    }
    margins {
        top: win.atBottom ? -2 : (win.edgeFlush ? 0 : shell.cfg.barGap)
        bottom: win.atBottom ? (win.edgeFlush ? 0 : shell.cfg.barGap) : -2
        left: win.style === "flat" ? 0 : shell.cfg.barSide
        right: win.style === "flat" ? 0 : shell.cfg.barSide
    }

    // ---- popups -----------------------------------------------------------
    function hostIs(kind) { return shell.popupHost === kind + "@" + (screen ? screen.name : ""); }

    // Opens a menu that grows out of `item` (a module button).
    function openPopup(kind, item, glyph, label) {
        const p = item.mapToItem(win.contentItem, 0, 0);
        const wx = pill ? (screen.width - width) / 2 : margins.left;
        const wy = atBottom ? screen.height - height - margins.bottom : margins.top;
        shell.togglePopup(kind, screen.name, { "x": wx + p.x, "y": wy + p.y, "w": item.width, "h": item.height }, glyph, label);
    }

    // ---- lock-screen morph target ------------------------------------------
    property Item clockItem: null
    function updateClock() {
        if (!clockItem || !clockItem.visible) { shell.barClockX = -1; return; }
        const p = clockItem.mapToItem(win.contentItem, clockItem.width / 2, 0);
        const wx = pill ? (screen.width - width) / 2 : margins.left;
        shell.barClockX = wx + p.x;
    }
    Timer { id: clockTimer; interval: 60; onTriggered: win.updateClock() }
    onPillWChanged: clockTimer.restart()
    onStyleChanged: clockTimer.restart()
    onWidthChanged: clockTimer.restart()
    onModsChanged: clockTimer.restart()
    onLeftWChanged: clockTimer.restart()
    onCenterWChanged: clockTimer.restart()
    onRightWChanged: clockTimer.restart()

    // ---- dynamic island: a small clock pill that opens up on hover and when something happens ----------
    property bool peek: false
    property bool armed: false
    property bool hoverHold: false     // stays true a moment after the pointer leaves, so the island does not flicker
    readonly property bool expanded: !island || hoverHold || peek || shell.settingsOpen || shell.popupHost !== ""
    Timer { id: holdTimer; interval: 420; onTriggered: win.hoverHold = false }
    Timer { id: armTimer; interval: 3500; running: true; onTriggered: win.armed = true }
    Timer { id: peekTimer; interval: 2600; onTriggered: win.peek = false }
    function peekNow() { if (!island || !armed) return; peek = true; peekTimer.restart(); }
    Connections { target: Hyprland; function onFocusedWorkspaceChanged() { win.peekNow(); } }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Connections {
        target: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() { win.peekNow(); }
        function onMutedChanged() { win.peekNow(); }
    }
    Connections { target: UPower.displayDevice; function onStateChanged() { win.peekNow(); } }
    // side zones fade with the pill's width; the width itself follows one expo-out curve
    property real openness: expanded ? 1 : 0
    Behavior on openness { NumberAnimation { duration: main.ms(520); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
    readonly property real collapsedW: Math.max(centerW + 28, 56)

    // the bar glides in on start and on reload
    Component.onCompleted: { introAnim.start(); clockTimer.restart(); }
    NumberAnimation { id: introAnim; target: win; property: "intro"; from: 0; to: 1; duration: main.ms(650)
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }

    // Surfaces fade between presets while the layout re-settles.
    component Surface: Rectangle {
        property bool shown: true
        visible: opacity > 0.01
        opacity: shown ? win.bgAlpha * win.intro : 0
        color: main.bg
        radius: win.radius
        border.color: main.border
        border.width: 1
        Behavior on opacity { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
        transform: Translate { y: (1 - win.intro) * (win.atBottom ? 14 : -14) }
    }

    // ---- backgrounds ------------------------------------------------------
    Surface {   // classic, pill
        shown: win.style === "classic" || win.style === "pill"
        anchors.fill: parent
    }
    Surface {   // notch: attached to the screen edge, only the free side is rounded
        readonly property real nr: Math.max(win.radius, 12)
        shown: win.notch
        anchors.fill: parent
        topLeftRadius: win.atBottom ? nr : 0
        topRightRadius: win.atBottom ? nr : 0
        bottomLeftRadius: win.atBottom ? 0 : nr
        bottomRightRadius: win.atBottom ? 0 : nr
    }
    Rectangle {   // dynamic island: one pill that grows and shrinks around its content
        id: islandSurface
        readonly property real fullH: win.height
        visible: opacity > 0.01
        opacity: win.island ? win.bgAlpha * win.intro : 0
        Behavior on opacity { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
        width: win.collapsedW + (win.pillW - win.collapsedW) * win.openness
        height: fullH - 6 + 6 * win.openness
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        radius: height / 2
        color: main.bg
        border.color: main.border
        border.width: 1
        transform: Translate { y: (1 - win.intro) * (win.atBottom ? 14 : -14) }
        layer.enabled: win.island
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35
            shadowBlur: 0.6; shadowVerticalOffset: 2; shadowHorizontalOffset: 0
        }
        HoverHandler {
            id: islandHover
            onHoveredChanged: { if (hovered) { win.hoverHold = true; holdTimer.stop(); } else holdTimer.restart(); }
        }
    }
    Surface {   // flat: edge to edge, only the free edge is rounded
        shown: win.style === "flat"
        anchors.fill: parent
        topLeftRadius: win.atBottom ? win.radius : 0
        topRightRadius: win.atBottom ? win.radius : 0
        bottomLeftRadius: win.atBottom ? 0 : win.radius
        bottomRightRadius: win.atBottom ? 0 : win.radius
    }
    Surface {   // islands: one pill per zone
        shown: win.style === "islands" && win.leftW > 0
        x: 0; width: win.leftW + win.pad * 2 - 10; height: parent.height
    }
    Surface {
        shown: win.style === "islands" && win.centerW > 0
        width: win.centerW + 18; height: parent.height; anchors.horizontalCenter: parent.horizontalCenter
    }
    Surface {
        shown: win.style === "islands" && win.rightW > 0
        width: win.rightW + win.pad * 2 - 10; height: parent.height; anchors.right: parent.right
    }
    // minimal: no surface, just a soft scrim so text stays readable on any wallpaper
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: win.atBottom ? undefined : parent.top
        anchors.bottom: win.atBottom ? parent.bottom : undefined
        height: parent.height + 10
        opacity: win.style === "minimal" ? win.intro : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: main.ms(260); easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: win.atBottom ? 1 : 0; color: Qt.rgba(0, 0, 0, 0.55) }
            GradientStop { position: win.atBottom ? 0 : 1; color: Qt.rgba(0, 0, 0, 0) }
        }
    }
    // pill dividers
    Rectangle {
        visible: win.pill && win.leftW > 0 && (win.hasC || win.rightW > 0)
        opacity: win.intro * 0.9 * (win.island ? win.openness : 1)
        width: 1; height: 14; y: (parent.height - height) / 2
        x: win.hasC ? win.pad + win.side + win.gap / 2 : win.pad + win.leftW + win.gap
        color: main.border
    }
    Rectangle {
        visible: win.pill && win.hasC && win.rightW > 0
        opacity: win.intro * 0.9 * (win.island ? win.openness : 1)
        width: 1; height: 14; y: (parent.height - height) / 2
        x: win.pad + win.side + win.gap * 1.5 + win.centerW
        color: main.border
    }

    // ---- module zones -----------------------------------------------------
    component Zone: RowLayout {
        id: zone
        property string name: ""
        property var ids: []
        spacing: shell.cfg.modSpacing
        Repeater {
            model: zone.ids
            Loader {
                id: ld
                required property string modelData
                source: win.shell.moduleFile(modelData)
                visible: status === Loader.Ready && !!item && item.available !== false
                Layout.alignment: Qt.AlignVCenter
                readonly property bool bare: modelData === "workspaces" || modelData === "clock"
                Layout.leftMargin: bare ? 5 : 0
                Layout.rightMargin: bare ? 5 : 0
                onLoaded: {
                    item.bar = win;
                    item.zone = zone.name;
                    if (modelData === "clock") win.clockItem = item;
                }
                Component.onDestruction: if (modelData === "clock" && win.clockItem === item) win.clockItem = null
            }
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: win.intro
        transform: Translate { y: (1 - win.intro) * (win.atBottom ? 10 : -10) }
        layer.enabled: win.style === "minimal"
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.9
            shadowBlur: 0.7; shadowVerticalOffset: 1; shadowHorizontalOffset: 0
        }

        Zone {
            id: zl; name: "left"; ids: win.mods.left
            opacity: win.island ? Math.max(0, (win.openness - 0.35) / 0.65) : 1
            enabled: !win.island || win.openness > 0.6
            anchors.verticalCenter: parent.verticalCenter
            x: win.pad - 5
            Behavior on x { NumberAnimation { duration: main.ms(320); easing.type: Easing.OutCubic } }
        }
        Zone {
            id: zc; name: "center"; ids: win.mods.center
            anchors.verticalCenter: parent.verticalCenter
            x: win.pill ? win.pad + win.side + win.gap : (parent.width - implicitWidth) / 2
            Behavior on x { NumberAnimation { duration: main.ms(320); easing.type: Easing.OutCubic } }
        }
        Zone {
            id: zr; name: "right"; ids: win.mods.right
            opacity: win.island ? Math.max(0, (win.openness - 0.35) / 0.65) : 1
            enabled: !win.island || win.openness > 0.6
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width - implicitWidth - win.pad + 5
            Behavior on x { NumberAnimation { duration: main.ms(320); easing.type: Easing.OutCubic } }
        }
    }
}
