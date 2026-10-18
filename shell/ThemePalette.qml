// qmllint disable
import QtQuick

// Animated colour set for the active theme. Bar widgets read these as `main.*`.
QtObject {
    id: root
    property var src: ({})
    property real menuAlpha: 1      // < 1 = frosted bar menus
    property real panelAlpha: 1     // < 1 = frosted settings panel
    property string font: "Inter"   // UI font, chosen in Appearance
    property string serif: "Noto Serif"
    property real speed: 1          // animation speed multiplier, big = effectively instant
    property int barPx: 13          // text size of bar modules
    property string iconMode: "accent"   // accent | text | colour
    function ms(d) { return Math.max(1, Math.round(d / speed)); }

    property color bg: src.bg
    property color text: src.text
    property color wsa: src.wsa
    property color wso: src.wso
    property color wsi: src.wsi
    property color wst: src.wst
    property color wsti: src.wsti
    property color icon: src.icon

    property color red: src.term.red
    property color green: src.term.green
    property color yellow: src.term.yellow
    property color blue: src.term.blue
    property color magenta: src.term.magenta
    property color cyan: src.term.cyan

    // Derived surfaces for the settings panel (follow the animated base colours).
    readonly property color dim: Qt.darker(bg, 1.54)                       // deepest background (bar, terminal)
    readonly property color surface: Qt.tint(dim, Qt.rgba(bg.r, bg.g, bg.b, 0.55)) // active workspace, raised bits
    readonly property color page: Qt.darker(bg, 1.35)
    readonly property color card: Qt.lighter(bg, 1.28)
    // neutral hairline for the bar and lock input: never clashes with a theme's accent
    readonly property color border: Qt.rgba(text.r, text.g, text.b, 0.16)
    readonly property color line: Qt.rgba(text.r, text.g, text.b, 0.13)
    readonly property color muted: Qt.rgba(text.r, text.g, text.b, 0.58)
    readonly property color accent: wsa
    readonly property color onAccent: Qt.darker(bg, 1.6)

    readonly property int dur: ms(380)
    Behavior on bg { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on text { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on wsa { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on wso { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on wsi { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on wst { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on wsti { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on icon { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on red { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on green { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on yellow { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on blue { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on magenta { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on cyan { ColorAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
}
