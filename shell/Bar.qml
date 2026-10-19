// qmllint disable
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Status bar with switchable styles (classic, pill, islands, flat, minimal, dynamic island) and
// user-chosen modules in three zones (left, centre, right).
PanelWindow {
    id: win
    required property var shell

    readonly property string style: shell.cfg.barStyle
    readonly property bool atBottom: shell.cfg.barPos === "bottom"
    // pill and island share one compact, centred layout
    readonly property bool pill: style === "pill" || style === "island"
    readonly property bool island: style === "island"
    readonly property real bgAlpha: shell.cfg.glassBar ? Math.max(0.35, 1 - shell.cfg.glassAmount) : shell.cfg.barOpacity
    readonly property real radius: shell.cfg.barRadius
    readonly property real pad: 14
    readonly property real gap: 12
    readonly property var mods: shell.cfg.modules
    // the island floats the same distance from the screen edge as windows do from each other and from it
    readonly property real islandGap: Math.max(4, shell.cfg.gapsOut)
    readonly property real maxMenuH: Math.max(200, Math.min(560, (screen ? screen.height : 900) - 140))
    property real intro: 0

    // the dynamic island lives in its own component; these are set by it
    property var islandRef: null
    property Item islandSurface: null
    property string islandMenu: ""

    // zone geometry (from the island's zones when it is the active style)
    readonly property real leftW: island && islandRef ? islandRef.leftW : zl.implicitWidth
    readonly property real centerW: island && islandRef ? islandRef.centerW : zc.implicitWidth
    readonly property real rightW: island && islandRef ? islandRef.rightW : zr.implicitWidth
    readonly property bool hasC: centerW > 0
    readonly property real side: hasC ? Math.max(leftW, rightW) : 0
    readonly property real pillW: hasC ? side * 2 + centerW + gap * 2 + pad * 2
                                       : leftW + rightW + ((leftW > 0 && rightW > 0) ? gap * 2 : 0) + pad * 2

    color: "transparent"
    // The island's window is only as big as the island is about to be (plus a little room): a big transparent window
    // costs the compositor a blur and a redraw of every pixel of it, which held the whole desktop near 30 fps.
    implicitHeight: island ? (islandRef ? Math.ceil(islandGap + islandRef.bbH + 14) : 64) : shell.cfg.barHeight
    implicitWidth: island ? (islandRef ? Math.ceil(islandRef.bbW + 2 * islandRef.sideExtra + 60) : 400) : (pill ? pillW : 0)
    // every style reserves its own strip, so windows tile below the bar instead of sliding under it
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: island ? islandGap + shell.cfg.barHeight : shell.cfg.barHeight
    WlrLayershell.namespace: "quickshell-bar"
    // on demand (not exclusive): a click grants keyboard focus for Esc, while the click-away catcher still receives the pointer
    WlrLayershell.keyboardFocus: island && islandRef && (islandMenu !== "" || islandRef.hoverHold) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Input: the whole window, except on the dynamic island where only the pill itself takes input
    readonly property bool maskIsland: island && islandSurface !== null && islandRef !== null
    // The island's input region is its pill plus a little slack, running out to the screen edge so a flick to the edge finds it
    readonly property real maskX: maskIsland && islandRef ? Math.max(0, islandRef.extL - 12) : 0
    readonly property real maskW: maskIsland && islandRef ? Math.min(width - maskX, islandRef.extR - islandRef.extL + 24) : width
    readonly property real maskBoxH: maskIsland && islandRef ? Math.min(height, islandGap + islandRef.bbH + 10) : height
    readonly property real maskY: maskIsland && atBottom ? height - maskBoxH : 0
    readonly property real maskH: !maskIsland ? height : maskBoxH
    mask: Region { x: win.maskX; y: win.maskY; width: win.maskW; height: win.maskH }

    anchors {
        top: !win.atBottom
        bottom: win.atBottom
        left: !win.pill
        right: !win.pill
    }
    margins {
        top: win.atBottom ? -2 : (win.island ? 0 : (win.style === "flat" ? 0 : shell.cfg.barGap))
        bottom: win.atBottom ? (win.island ? 0 : (win.style === "flat" ? 0 : shell.cfg.barGap)) : -2
        left: win.style === "flat" ? 0 : shell.cfg.barSide
        right: win.style === "flat" ? 0 : shell.cfg.barSide
    }

    // ---- popups -----------------------------------------------------------
    function hostIs(kind) {
        if (island) return islandMenu === kind;
        return shell.popupHost === kind + "@" + (screen ? screen.name : "");
    }

    // Opens a menu that grows out of `item` (a module button). On the dynamic island the island itself morphs into it.
    function openPopup(kind, item, glyph, label) {
        if (island) { if (islandRef) islandRef.openMenu(kind, glyph); return; }
        const p = item.mapToItem(win.contentItem, 0, 0);
        const wx = pill ? (screen.width - width) / 2 : margins.left;
        const wy = atBottom ? screen.height - height - margins.bottom : margins.top;
        shell.togglePopup(kind, screen.name, { "x": wx + p.x, "y": wy + p.y, "w": item.width, "h": item.height }, glyph, label);
    }

    // Opens a menu without a button to click (a key bind, `hearthshell menu quick`): from the middle of the bar.
    function openMenuAt(kind) {
        if (island) { if (islandRef) islandRef.openMenu(kind, islandRef.stackGlyph(kind), ""); return; }
        const wx = pill ? (screen.width - width) / 2 : margins.left;
        const wy = atBottom ? screen.height - height - margins.bottom : margins.top;
        shell.togglePopup(kind, screen.name, { "x": wx + width / 2 - 20, "y": wy, "w": 40, "h": height }, shell.menuGlyph(kind), "");
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

    // the bar glides in on start and on reload
    Component.onCompleted: { introAnim.start(); clockTimer.restart(); shell.bars[screen.name] = win; }
    NumberAnimation { id: introAnim; target: win; property: "intro"; from: 0; to: 1; duration: main.ms(650)
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }

    // Surfaces fade between styles while the layout re-settles.
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
        visible: win.style === "pill" && win.leftW > 0 && (win.hasC || win.rightW > 0)
        opacity: win.intro * 0.9
        width: 1; height: 14; y: (parent.height - height) / 2
        x: win.hasC ? win.pad + win.side + win.gap / 2 : win.pad + win.leftW + win.gap
        color: main.border
    }
    Rectangle {
        visible: win.style === "pill" && win.hasC && win.rightW > 0
        opacity: win.intro * 0.9
        width: 1; height: 14; y: (parent.height - height) / 2
        x: win.pad + win.side + win.gap * 1.5 + win.centerW
        color: main.border
    }

    // ---- the dynamic island ----------------------------------------------------
    Loader {
        id: islandLoader
        anchors.fill: parent
        active: win.island
        sourceComponent: Component { Island { bar: win } }
    }

    // ---- module zones (every style except the island, which has its own) -----------
    Item {
        id: content
        anchors.fill: parent
        opacity: win.intro
        visible: !win.island
        transform: Translate { y: (1 - win.intro) * (win.atBottom ? 10 : -10) }
        layer.enabled: win.style === "minimal"
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.9
            shadowBlur: 0.7; shadowVerticalOffset: 1; shadowHorizontalOffset: 0
        }

        BarZone {
            id: zl; bar: win; name: "left"; ids: win.island ? [] : win.mods.left
            anchors.verticalCenter: parent.verticalCenter
            x: win.pad - 5
            Behavior on x { NumberAnimation { duration: main.ms(320); easing.type: Easing.OutCubic } }
        }
        BarZone {
            id: zc; bar: win; name: "center"; ids: win.island ? [] : win.mods.center
            anchors.verticalCenter: parent.verticalCenter
            x: win.pill ? win.pad + win.side + win.gap : (parent.width - implicitWidth) / 2
            Behavior on x { NumberAnimation { duration: main.ms(320); easing.type: Easing.OutCubic } }
        }
        BarZone {
            id: zr; bar: win; name: "right"; ids: win.island ? [] : win.mods.right
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width - implicitWidth - win.pad + 5
            Behavior on x { NumberAnimation { duration: main.ms(320); easing.type: Easing.OutCubic } }
        }
    }
}
