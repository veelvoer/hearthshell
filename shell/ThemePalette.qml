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

    // The icon for a settings row, picked from its name.
    function iconFor(label) {
        const t = (label || "").toLowerCase();
        const has = (...w) => w.some(x => t.indexOf(x) >= 0);
        const cp = n => String.fromCodePoint(n);
        if (has("theme", "colour", "color", "accent", "palette")) return cp(0xF03D8);
        if (has("wallpaper", "image", "picture")) return cp(0xF02E9);
        if (has("clock", "24-hour", "seconds", "time")) return cp(0xF0150);
        if (has("monday", "calendar", "week")) return cp(0xF00ED);
        if (has("round", "radius", "corner")) return cp(0xF0831);
        if (has("opacity", "glass", "frost", "blur", "transparen", "see-through")) return cp(0xF05CC);
        if (has("gap", "spacing", "inner", "outer", "border", "width", "height", "size", "padding")) return cp(0xF046C);
        if (has("font", "text")) return cp(0xF027D);
        if (has("icon")) return cp(0xF003B);
        if (has("workspace")) return cp(0xF0572);
        if (has("bounce", "spring", "motion", "animation", "speed")) return cp(0xF04C5);
        if (has("island", "pieces")) return cp(0xF0570);
        if (has("position")) return cp(0xF0572);
        if (has("focus", "inactive")) return cp(0xF01BE);
        if (has("mouse", "pointer", "touchpad", "scroll", "tap")) return cp(0xF037D);
        if (has("keyboard", "key", "repeat")) return cp(0xF030C);
        if (has("kitty", "terminal", "fish", "shell")) return cp(0xF018D);
        if (has("rofi", "launcher")) return cp(0xF003B);
        if (has("hyprlock", "lock")) return cp(0xF033E);
        if (has("firefox", "browser")) return cp(0xF059F);
        if (has("file")) return cp(0xF024B);
        if (has("editor")) return cp(0xF0174);
        if (has("chat")) return cp(0xF0361);
        if (has("gtk", "apps", "other", "window")) return cp(0xF05B1);
        if (has("notification", "pop", "bell", "daemon")) return cp(0xF009A);
        if (has("quiet", "night", "do not disturb")) return cp(0xF0594);
        if (has("volume", "sound", "audio")) return cp(0xF057E);
        if (has("bright")) return cp(0xF00E0);
        if (has("battery")) return cp(0xF0079);
        if (has("wi-fi", "network")) return cp(0xF05A9);
        if (has("bluetooth")) return cp(0xF00AF);
        if (has("music", "playing", "media")) return cp(0xF075A);
        if (has("power")) return cp(0xF0425);
        if (has("bar", "status")) return cp(0xF0572);
        if (has("reset", "restart", "start over", "defaults")) return cp(0xF0709);
        if (has("apply", "re-apply", "update")) return cp(0xF06B0);
        if (has("show", "hide", "label")) return cp(0xF0208);
        return cp(0xF0570);
    }
}
