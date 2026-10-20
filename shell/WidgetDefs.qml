import QtQuick

// What every widget is, and every option it has. The widgets and the Customize panel are both drawn from this one list,
// so adding an option here is all it takes for it to appear and work.
QtObject {
    id: root

    readonly property var order: ["clock", "analog", "date", "greeting", "text", "countdown", "calendar", "media", "system", "battery", "note", "image"]

    readonly property var styles: [["plain", "Plain"], ["card", "Card"], ["glass", "Frosted"], ["solid", "Solid"], ["outline", "Outline"]]
    readonly property var aligns: [["left", "Left"], ["center", "Centre"], ["right", "Right"]]
    readonly property var fonts: [["theme", "Theme"], ["serif", "Serif"], ["mono", "Mono"]]
    readonly property var weights: [["300", "Light"], ["600", "Medium"], ["800", "Bold"]]
    readonly property var dateFormats: [["long", "Long"], ["short", "Short"], ["numeric", "Numeric"]]

    // the look every widget shares
    readonly property var look: [
        { "key": "style", "label": "Style", "kind": "choice", "choices": styles },
        { "key": "radius", "label": "Roundness", "kind": "slider", "min": 0, "max": 48, "step": 1, "unit": " px", "def": 26 },
        { "key": "frost", "label": "Frost", "kind": "slider", "min": 0.1, "max": 1, "step": 0.05, "decimals": 2, "def": 0.7 },
        { "key": "bgAlpha", "label": "Background strength", "kind": "slider", "min": 0.1, "max": 1, "step": 0.05, "decimals": 2 },
        { "key": "tint", "label": "Text colour", "kind": "choice", "choices": [["auto", "Auto"], ["accent", "Accent"], ["soft", "Soft"]], "def": "auto" },
        { "key": "shadow", "label": "Shadow", "kind": "toggle", "def": false },
        { "key": "opacity", "label": "Opacity", "kind": "slider", "min": 0.3, "max": 1, "step": 0.05, "decimals": 2, "def": 1 }
    ]

    readonly property var types: ({
        "clock": { "label": "Clock", "glyph": 0xF0954, "w": 380, "h": 170, "style": "plain", "desc": "Big digital time",
            "options": [
                { "key": "hour", "label": "Hours", "kind": "choice", "choices": [["theme", "Theme"], ["24", "24 h"], ["12", "12 h"]], "def": "theme" },
                { "key": "seconds", "label": "Seconds", "kind": "toggle", "def": false },
                { "key": "showDate", "label": "Date below", "kind": "toggle", "def": true },
                { "key": "dateFmt", "label": "Date style", "kind": "choice", "choices": dateFormats, "def": "long" },
                { "key": "align", "label": "Alignment", "kind": "choice", "choices": aligns, "def": "center" },
                { "key": "font", "label": "Font", "kind": "choice", "choices": fonts, "def": "theme" },
                { "key": "weight", "label": "Weight", "kind": "choice", "choices": weights, "def": "600" } ] },
        "analog": { "label": "Analog", "glyph": 0xF0150, "w": 260, "h": 260, "style": "plain", "desc": "Round clock with hands",
            "options": [
                { "key": "face", "label": "Face", "kind": "toggle", "def": true },
                { "key": "ticks", "label": "Hour marks", "kind": "toggle", "def": true },
                { "key": "numbers", "label": "Numbers", "kind": "toggle", "def": false },
                { "key": "secondHand", "label": "Second hand", "kind": "toggle", "def": true } ] },
        "date": { "label": "Date", "glyph": 0xF00F6, "w": 380, "h": 100, "style": "plain", "desc": "Day and date",
            "options": [
                { "key": "fmt", "label": "Format", "kind": "choice", "choices": dateFormats, "def": "long" },
                { "key": "layout", "label": "Layout", "kind": "choice", "choices": [["stacked", "Stacked"], ["inline", "One line"]], "def": "stacked" },
                { "key": "align", "label": "Alignment", "kind": "choice", "choices": aligns, "def": "center" },
                { "key": "font", "label": "Font", "kind": "choice", "choices": fonts, "def": "theme" } ] },
        "greeting": { "label": "Greeting", "glyph": 0xF1821, "w": 520, "h": 90, "style": "plain", "desc": "Good morning, you",
            "options": [
                { "key": "name", "label": "Name", "kind": "text", "def": "", "hint": "Your user name" },
                { "key": "showDate", "label": "Date below", "kind": "toggle", "def": false },
                { "key": "align", "label": "Alignment", "kind": "choice", "choices": aligns, "def": "center" },
                { "key": "weight", "label": "Weight", "kind": "choice", "choices": weights, "def": "600" } ] },
        "text": { "label": "Text", "glyph": 0xF09A8, "w": 360, "h": 120, "style": "plain", "desc": "Any words you like",
            "options": [
                { "key": "text", "label": "Words", "kind": "text", "def": "Hello", "hint": "Write something" },
                { "key": "size", "label": "Size", "kind": "slider", "min": 16, "max": 120, "step": 1, "unit": " px", "def": 48 },
                { "key": "align", "label": "Alignment", "kind": "choice", "choices": aligns, "def": "center" },
                { "key": "font", "label": "Font", "kind": "choice", "choices": fonts, "def": "theme" },
                { "key": "weight", "label": "Weight", "kind": "choice", "choices": weights, "def": "600" } ] },
        "countdown": { "label": "Countdown", "glyph": 0xF051B, "w": 320, "h": 150, "style": "card", "desc": "Days until a date",
            "options": [
                { "key": "label", "label": "What for", "kind": "text", "def": "the big day", "hint": "A name for it" },
                { "key": "date", "label": "Date", "kind": "text", "def": "", "hint": "YYYY-MM-DD" },
                { "key": "align", "label": "Alignment", "kind": "choice", "choices": aligns, "def": "center" } ] },
        "calendar": { "label": "Calendar", "glyph": 0xF0E17, "w": 290, "h": 300, "style": "card", "desc": "This month",
            "options": [
                { "key": "header", "label": "Month title", "kind": "toggle", "def": true },
                { "key": "weekNumbers", "label": "Week numbers", "kind": "toggle", "def": false },
                { "key": "neighbors", "label": "Days of other months", "kind": "toggle", "def": false },
                { "key": "highlight", "label": "Today", "kind": "choice", "choices": [["circle", "Circle"], ["square", "Square"], ["dot", "Dot"]], "def": "circle" } ] },
        "media": { "label": "Music", "glyph": 0xF075A, "w": 360, "h": 116, "style": "card", "desc": "What is playing",
            "options": [
                { "key": "art", "label": "Cover", "kind": "toggle", "def": true },
                { "key": "progress", "label": "Progress bar", "kind": "toggle", "def": true },
                { "key": "controls", "label": "Buttons", "kind": "toggle", "def": true },
                { "key": "autoHide", "label": "Hide when nothing plays", "kind": "toggle", "def": false } ] },
        "system": { "label": "System", "glyph": 0xF061A, "w": 290, "h": 140, "style": "card", "desc": "Processor, memory, heat",
            "options": [
                { "key": "cpu", "label": "Processor", "kind": "toggle", "def": true },
                { "key": "memory", "label": "Memory", "kind": "toggle", "def": true },
                { "key": "temp", "label": "Temperature", "kind": "toggle", "def": true },
                { "key": "disk", "label": "Disk", "kind": "toggle", "def": false },
                { "key": "view", "label": "Show as", "kind": "choice", "choices": [["bars", "Bars"], ["numbers", "Numbers"]], "def": "bars" } ] },
        "battery": { "label": "Battery", "glyph": 0xF0079, "w": 150, "h": 150, "style": "card", "desc": "Charge level",
            "options": [
                { "key": "view", "label": "Show as", "kind": "choice", "choices": [["ring", "Ring"], ["bar", "Bar"]], "def": "ring" },
                { "key": "showState", "label": "Charging text", "kind": "toggle", "def": true } ] },
        "note": { "label": "Note", "glyph": 0xF039E, "w": 270, "h": 180, "style": "card", "desc": "Type anything",
            "options": [
                { "key": "paper", "label": "Paper", "kind": "choice", "choices": [["theme", "Theme"], ["yellow", "Yellow"], ["mint", "Mint"], ["sky", "Sky"], ["rose", "Rose"]], "def": "theme" },
                { "key": "textSize", "label": "Text size", "kind": "slider", "min": 12, "max": 30, "step": 1, "unit": " px", "def": 16 },
                { "key": "mono", "label": "Typewriter font", "kind": "toggle", "def": false } ] },
        "image": { "label": "Picture", "glyph": 0xF02E9, "w": 300, "h": 200, "style": "plain", "desc": "A photo or logo",
            "options": [
                { "key": "path", "label": "Image", "kind": "file", "def": "" },
                { "key": "fit", "label": "Fit", "kind": "choice", "choices": [["fill", "Fill"], ["fit", "Whole"]], "def": "fill" } ] }
    })

    function styleAlpha(style) { return style === "solid" ? 1 : style === "glass" ? 0.3 : style === "card" ? 0.66 : 0; }
    function defaultOf(type, key) {
        const t = types[type];
        if (!t) return undefined;
        if (key === "style") return t.style;
        for (const o of look) if (o.key === key && o.def !== undefined) return o.def;
        if (t.options) for (const o of t.options) if (o.key === key) return o.def;
        return undefined;
    }
    function val(spec, key) {
        if (key === "style" && spec.style === "liquid") return "glass";
        if (spec[key] !== undefined) return spec[key];
        if (key === "bgAlpha") return styleAlpha(val(spec, "style"));
        // widgets saved before styles existed only knew "card"
        if (key === "style" && spec.card !== undefined) return spec.card ? "card" : "plain";
        return defaultOf(spec.type, key);
    }
    function optionsOf(type) { return types[type] && types[type].options ? types[type].options : []; }
}
