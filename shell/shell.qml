// qmllint disable
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: shellRoot
    readonly property string activeTheme: cfg.theme
    
    // ---- Lock + clock morph ------------------------------------
    readonly property real barTopMargin: cfg.barStyle === "flat" ? 0 : (cfg.barStyle === "island" ? Math.max(4, cfg.gapsOut) : cfg.barGap)
    readonly property real barHeight: cfg.barHeight
    readonly property real barCenterY: barTopMargin + barHeight / 2

    readonly property string clockFont: cfg.font
    readonly property real lockFontPx: cfg.lockClockSize   // lockscreen clock size
    readonly property real barFontPx: 14    // bar clock size (Clock.qml)
    readonly property real stackGap: 52     // HH / mm centre offset from stack centre

    property string phase: "idle"           // idle | capturing | locked | unlocking
    property bool preview: false            // true = fullscreen overlay instead of a real session lock
    property bool holdBar: false            // hide the bar clock (the lock clock stands in for it)
    property real morph: 1                  // 0 = lockscreen, 1 = on the bar clock
    property real blurAmt: 0
    property real uiOpacity: 0
    property bool authBusy: false
    property string authStatus: ""
    property string shotDir: "/tmp/qs-lock"
    readonly property bool wantLocked: phase === "locked" || phase === "unlocking"
    property alias clock: sysClock

    SystemClock { id: sysClock; precision: SystemClock.Minutes }

    function lockNow() {
        if (phase !== "idle") return;
        authStatus = ""; authBusy = false;
        morph = 1; blurAmt = 0; uiOpacity = 0;
        holdBar = true;                 // bar clock out of the screenshot
        phase = "capturing";
        captureDelay.restart();
    }

    function beginUnlock() {
        if (phase !== "locked") return;
        phase = "unlocking";
        lockInAnim.stop();
        unlockAnim.restart();
    }

    Timer { id: captureDelay; interval: 80; onTriggered: {
        let names = [];
        for (let i = 0; i < shellRoot.screens.length; i++) names.push(shellRoot.screens[i].name);
        grim.command = ["sh", "-c", "mkdir -p " + shellRoot.shotDir + "; for n in " + names.join(" ") + "; do grim -o \"$n\" " + shellRoot.shotDir + "/$n.png || exit 1; done"];
        grim.running = true;
    } }

    Process {
        id: grim
        onExited: code => {
            if (code !== 0) { shellRoot.holdBar = false; shellRoot.phase = "idle"; return; }
            shellRoot.phase = "locked";      // lock surfaces appear (clock sits on the bar clock)
            lockInAnim.restart();
        }
    }

    ParallelAnimation {
        id: lockInAnim
        NumberAnimation { target: shellRoot; property: "morph"; from: 1; to: 0; duration: 700
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] }
        NumberAnimation { target: shellRoot; property: "blurAmt"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: shellRoot; property: "uiOpacity"; from: 0; to: 1; duration: 300 }
        }
    }

    SequentialAnimation {
        id: unlockAnim
        ParallelAnimation {
            NumberAnimation { target: shellRoot; property: "uiOpacity"; to: 0; duration: 160 }
            NumberAnimation { target: shellRoot; property: "morph"; to: 1; duration: 750
                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] }
            NumberAnimation { target: shellRoot; property: "blurAmt"; to: 0; duration: 650; easing.type: Easing.InOutCubic }
        }
        // bar clock appears underneath the identical lock clock, then the lock goes away
        ScriptAction { script: shellRoot.holdBar = false }
        PauseAnimation { duration: 90 }
        ScriptAction { script: { shellRoot.phase = "idle"; shellRoot.authBusy = false; } }
    }

    // ---- authentication -------------------------------------------
    property string pendingPassword: ""
    // PAM service used to check the lock-screen password; install.sh writes the right one to pam-service
    FileView { id: pamFile; path: Quickshell.shellPath("pam-service"); blockLoading: true }
    readonly property string pamService: {
        try { const t = pamFile.text().trim(); return t !== "" ? t : "hyprlock"; } catch (e) { return "hyprlock"; }
    }
    PamContext {
        id: pam
        config: shellRoot.pamService
        onPamMessage: {
            if (responseRequired) respond(shellRoot.pendingPassword);
        }
        onCompleted: result => {
            shellRoot.pendingPassword = "";
            if (result === PamResult.Success) {
                shellRoot.authStatus = "";
                shellRoot.beginUnlock();
            } else {
                shellRoot.authBusy = false;
                shellRoot.authStatus = "Wrong password";
                shellRoot.authFailed();
            }
        }
    }
    signal authFailed()

    function submitPassword(pw) {
        if (authBusy || phase !== "locked") return;
        authBusy = true;
        authStatus = "";
        pendingPassword = pw;
        pam.start();
    }

    Themes { id: themesData }
    readonly property var themeList: themesData

    ThemePalette {
        id: palette
        src: shellRoot.cfg.accent === "" ? themesData.data[shellRoot.cfg.theme]
             : Object.assign({}, themesData.data[shellRoot.cfg.theme], { "wsa": shellRoot.cfg.accent, "icon": shellRoot.cfg.accent })
        font: shellRoot.cfg.font
        speed: ({ "off": 40, "relaxed": 0.65, "normal": 1, "snappy": 1.6 })[shellRoot.cfg.motion]
        barPx: shellRoot.cfg.barFont
        iconMode: shellRoot.cfg.iconMode
        panelAlpha: shellRoot.cfg.glassPanel ? Math.max(0.35, 1 - shellRoot.cfg.glassAmount) : 1
        menuAlpha: (shellRoot.cfg.glassPanel || shellRoot.cfg.glassBar) ? Math.max(0.35, 1 - shellRoot.cfg.glassAmount) : 1
    }
    readonly property var main: palette

    // ---- persisted settings ----------------------------------------
    readonly property var defaults: ({
        "theme": "everforest", "wallIdx": {}, "wallDim": 0, "wallBlur": 0, "wallCycle": 0,
        "barOpacity": 0.88, "barRadius": 15, "clock24": true, "clockSeconds": false,
        "gapsIn": 7, "gapsOut": 10, "rounding": 12, "borderSize": 2, "inactiveOpacity": 0.94, "blur": true,
        "termOpacity": 0.92, "blurSize": 6,
        "barStyle": "classic", "barPos": "top",
        "glassBar": false, "glassPanel": false, "glassLauncher": false, "glassTerminal": false, "glassAmount": 0.4,
        "glassWindows": false, "glassBrowsers": true, "glassFiles": true, "glassEditors": true, "glassChat": true, "glassOther": true,
        "userWalls": {},
        "font": "Inter", "motion": "normal", "accent": "", "wallFit": "fill",
        "barHeight": 30, "barGap": 4, "barSide": 10, "barFont": 13, "modSpacing": 0, "iconMode": "accent",
        "wsStyle": "pills", "wsCount": 9, "wsOccupiedOnly": false, "clockDate": false,
        "labelVolume": true, "labelNetwork": true, "labelBluetooth": true, "labelBrightness": true, "labelBattery": true, "labelsOnHover": false,
        "shadow": true, "shadowSize": 12, "gradientBorder": true,
        "followMouse": true, "naturalScroll": true, "tapToClick": true, "pointerSpeed": 0, "repeatRate": 25, "repeatDelay": 600,
        "lockClockSize": 96, "lockBlur": 1, "lockDate": true,
        "kittyFont": 11, "kittyPad": 12, "kittyCursor": "beam",
        "rofiWidth": 400, "rofiLines": 7, "rofiIcons": true,
        "modules": { "left": ["workspaces"], "center": ["clock"], "right": ["volume", "network", "battery"] },
        "syncKitty": true, "syncRofi": true, "syncFish": true, "syncGtk": true, "syncLock": true, "syncApps": true
    })
    // keys that need scripts/apply-theme.py to run when they change
    readonly property var systemKeys: ["theme", "gapsIn", "gapsOut", "rounding", "borderSize", "inactiveOpacity",
        "blur", "blurSize", "termOpacity", "glassBar", "glassPanel", "glassLauncher", "glassTerminal", "glassAmount", "glassWindows", "glassBrowsers", "glassFiles", "glassEditors", "glassChat", "glassOther", "syncKitty", "syncRofi", "syncFish", "syncGtk", "syncLock", "syncApps",
        "motion", "accent", "shadow", "shadowSize", "gradientBorder", "followMouse", "naturalScroll", "tapToClick",
        "pointerSpeed", "repeatRate", "repeatDelay", "kittyFont", "kittyPad", "kittyCursor", "rofiWidth", "rofiLines", "rofiIcons"]
    property var cfg: defaults
    property bool settingsOpen: false
    property bool settingsLoaded: false
    readonly property int wallIndex: cfg.wallIdx[cfg.theme] || 1
    readonly property string wallpaperSource: Quickshell.shellPath("wallpapers/" + cfg.theme + "/" + wallIndex + ".jpg")

    // ---- bar modules --------------------------------------------------
    readonly property var moduleInfo: ({
        "workspaces": { "label": "Workspaces", "desc": "Numbered workspace pills", "file": "Workspaces.qml" },
        "clock": { "label": "Clock", "desc": "Time, with optional seconds", "file": "ClockModule.qml" },
        "volume": { "label": "Volume", "desc": "Click to mute, scroll to change", "file": "Volume.qml" },
        "brightness": { "label": "Brightness", "desc": "Scroll to change, hidden without a backlight", "file": "Brightness.qml" },
        "network": { "label": "Network", "desc": "Wi-Fi or ethernet, click for the network menu", "file": "Network.qml" },
        "bluetooth": { "label": "Bluetooth", "desc": "Click for the device menu, hidden without an adapter", "file": "Bluetooth.qml" },
        "quick": { "label": "Quick settings", "desc": "Wi-Fi, Bluetooth, sound, brightness and power in one menu", "file": "QuickSettings.qml" },
        "battery": { "label": "Battery", "desc": "Hidden when there is no battery", "file": "Battery.qml" }
    })
    readonly property var moduleOrder: ["workspaces", "clock", "volume", "brightness", "network", "bluetooth", "quick", "battery"]
    function moduleFile(id) { return moduleInfo[id] ? moduleInfo[id].file : "Workspaces.qml"; }
    property real barClockX: -1             // centre of the bar clock on screen, -1 = none

    // keep only known modules, each at most once
    function sanitizeModules(m) {
        const seen = {};
        const out = { "left": [], "center": [], "right": [] };
        for (const zone of ["left", "center", "right"]) {
            const list = m && Array.isArray(m[zone]) ? m[zone] : [];
            for (const id of list) {
                if (moduleInfo[id] && !seen[id]) { seen[id] = true; out[zone].push(id); }
            }
        }
        return out;
    }
    function zoneOf(id) {
        for (const zone of ["left", "center", "right"]) if (cfg.modules[zone].indexOf(id) >= 0) return zone;
        return "";
    }
    // place a module in a zone (or "" to hide it)
    function setModuleZone(id, zone) {
        const m = { "left": cfg.modules.left.slice(), "center": cfg.modules.center.slice(), "right": cfg.modules.right.slice() };
        for (const z of ["left", "center", "right"]) m[z] = m[z].filter(x => x !== id);
        if (zone !== "") m[zone].push(id);
        set("modules", m);
    }
    function moveModule(id, delta) {
        const zone = zoneOf(id);
        if (zone === "") return;
        const m = { "left": cfg.modules.left.slice(), "center": cfg.modules.center.slice(), "right": cfg.modules.right.slice() };
        const i = m[zone].indexOf(id), j = i + delta;
        if (j < 0 || j >= m[zone].length) return;
        m[zone][i] = m[zone][j];
        m[zone][j] = id;
        set("modules", m);
    }

    // ---- popup menus (Wi-Fi, Bluetooth) ---------------------------------
    property var popup: ({ "kind": "", "screen": "", "rect": {}, "glyph": "", "label": "" })
    property string popupHost: ""           // "<kind>@<screen>" while a menu card is on screen
    function togglePopup(kind, screenName, rect, glyph, label) {
        if (popup.kind === kind && popup.screen === screenName) { closePopup(); return; }
        popup = { "kind": kind, "screen": screenName, "rect": rect, "glyph": glyph, "label": label };
    }
    function closePopup() { popup = { "kind": "", "screen": "", "rect": {}, "glyph": "", "label": "" }; }

    function set(key, value) {
        if (cfg[key] === value) return;
        const c = Object.assign({}, cfg);
        c[key] = value;
        cfg = c;
        saveTimer.restart();
        if (systemKeys.indexOf(key) >= 0) applyTimer.restart();
    }
    // styles that were removed map to the closest remaining one
    function normalizeStyle(s) {
        if (s === "notch") return "pill";
        return ["classic", "pill", "islands", "flat", "minimal", "island"].indexOf(s) >= 0 ? s : "classic";
    }
    function setTheme(t) { if (themesData.data[t]) set("theme", t); }
    function setWallpaper(i) {
        const m = Object.assign({}, cfg.wallIdx);
        m[cfg.theme] = i;
        set("wallIdx", m);
    }
    function wallCount(theme) {
        const t = themesData.data[theme];
        return (t ? t.walls : 0) + (cfg.userWalls[theme] || 0);
    }
    function shuffleWallpaper() {
        const n = wallCount(cfg.theme);
        if (n < 2) return;
        let i = wallIndex;
        while (i === wallIndex) i = 1 + Math.floor(Math.random() * n);
        setWallpaper(i);
    }
    function resetSettings() {
        cfg = defaults;
        saveTimer.restart();
        applyTimer.restart();
    }
    // ---- user themes and wallpapers (scripts/*.py do the heavy lifting) ----
    signal themeSaved(string id)
    signal wallpaperAdded()
    property string toast: ""
    function notify(msg) { toast = msg; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 3200; onTriggered: shellRoot.toast = "" }

    function pickWallpaper(themed) {
        pickProc.themed = themed;
        pickProc.running = true;
    }
    Process {
        id: pickProc
        property bool themed: false
        command: ["sh", Quickshell.shellPath("scripts/pick-file.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "") shellRoot.addWallpaper(path, pickProc.themed);
            }
        }
        onExited: code => { if (code === 2) shellRoot.notify("Install kdialog or zenity to pick a file"); }
    }
    function addWallpaper(path, themed) {
        addProc.theme = cfg.theme;
        addProc.command = ["python3", Quickshell.shellPath("scripts/add-wallpaper.py"), cfg.theme, path, themed ? "themed" : "original"];
        addProc.running = true;
    }
    Process {
        id: addProc
        property string theme: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                if (isNaN(n)) { shellRoot.notify("Could not add that image"); return; }
                const base = themesData.data[addProc.theme] ? themesData.data[addProc.theme].walls : 0;
                const u = Object.assign({}, shellRoot.cfg.userWalls);
                u[addProc.theme] = n - base;
                shellRoot.set("userWalls", u);
                shellRoot.setWallpaper(n);
                shellRoot.notify("Wallpaper added");
                shellRoot.wallpaperAdded();
            }
        }
    }

    function saveCustomTheme(spec) {
        spec.wallpaper = wallpaperSource;
        saveProc.command = ["python3", Quickshell.shellPath("scripts/custom-theme.py"), "save", JSON.stringify(spec)];
        saveProc.running = true;
    }
    Process {
        id: saveProc
        stdout: StdioCollector {
            onStreamFinished: {
                const id = text.trim();
                if (id === "") { shellRoot.notify("Could not save the theme"); return; }
                themesData.reloadCustom();
                shellRoot.setTheme(id);
                shellRoot.notify("Theme saved");
                shellRoot.themeSaved(id);
            }
        }
    }
    function deleteCustomTheme(id) {
        if (cfg.theme === id) setTheme("everforest");
        delProc.command = ["python3", Quickshell.shellPath("scripts/custom-theme.py"), "delete", id];
        delProc.running = true;
    }
    Process { id: delProc; onExited: { themesData.reloadCustom(); shellRoot.notify("Theme deleted"); } }

    function extractPalette(callback) {
        palProc.cb = callback;
        palProc.command = ["python3", Quickshell.shellPath("scripts/palette.py"), wallpaperSource];
        palProc.running = true;
    }
    Process {
        id: palProc
        property var cb: null
        stdout: StdioCollector {
            onStreamFinished: {
                try { if (palProc.cb) palProc.cb(JSON.parse(text)); } catch (e) { shellRoot.notify("Could not read colours"); }
            }
        }
    }

    // ---- quick looks: one click sets bar, spacing, borders and effects together -------
    readonly property var lookKeys: ["barStyle", "barRadius", "barOpacity", "barHeight", "barGap", "barSide", "barFont", "modSpacing",
        "rounding", "gapsIn", "gapsOut", "borderSize", "inactiveOpacity", "shadow", "shadowSize", "gradientBorder",
        "glassBar", "glassPanel", "glassLauncher", "glassTerminal", "glassAmount", "glassWindows", "glassBrowsers", "glassFiles", "glassEditors", "glassChat", "glassOther", "blur", "blurSize", "wsStyle", "iconMode"]
    readonly property var looks: [
        { "id": "classic", "name": "Classic", "desc": "The original pill bar", "set": {} },
        { "id": "cozy", "name": "Cozy", "desc": "Soft, round, roomy",
          "set": { "barHeight": 32, "barGap": 6, "rounding": 18, "gapsIn": 8, "gapsOut": 14, "shadowSize": 20 } },
        { "id": "glass", "name": "Glass", "desc": "Frosted and blurred",
          "set": { "barStyle": "pill", "glassBar": true, "glassPanel": true, "glassLauncher": true, "glassTerminal": true, "glassWindows": true,
                   "glassAmount": 0.45, "blurSize": 9, "rounding": 16, "gapsIn": 6, "gapsOut": 12, "borderSize": 1, "wsStyle": "dots" } },
        { "id": "compact", "name": "Compact", "desc": "Slim and tight",
          "set": { "barStyle": "flat", "barHeight": 26, "barFont": 12, "barRadius": 12, "rounding": 10, "gapsIn": 3, "gapsOut": 5,
                   "borderSize": 1, "shadowSize": 6, "wsStyle": "numbers" } },
        { "id": "islands", "name": "Islands", "desc": "Floating pills",
          "set": { "barStyle": "islands", "barHeight": 32, "barGap": 8, "rounding": 16, "gapsIn": 6, "gapsOut": 14, "shadowSize": 18 } },
        { "id": "minimal", "name": "Minimal", "desc": "No bar surface",
          "set": { "barStyle": "minimal", "rounding": 12, "gapsIn": 4, "gapsOut": 8, "borderSize": 1, "shadow": false,
                   "wsStyle": "dots", "iconMode": "text" } },
        { "id": "dynamic", "name": "Dynamic", "desc": "Opens on hover",
          "set": { "barStyle": "island", "barHeight": 32, "barGap": 8, "rounding": 16, "gapsIn": 6, "gapsOut": 12, "shadowSize": 18, "wsStyle": "dots" } },
        { "id": "vivid", "name": "Vivid", "desc": "Bold and colourful",
          "set": { "iconMode": "colour", "rounding": 14, "borderSize": 3, "gapsOut": 12, "shadowSize": 16 } }
    ]
    function applyLook(id) {
        const look = looks.find(l => l.id === id);
        if (!look) return;
        const c = Object.assign({}, cfg);
        for (const k of lookKeys) c[k] = defaults[k];
        Object.assign(c, look.set);
        cfg = c;
        saveTimer.restart();
        applyTimer.restart();
        notify(look.name + " look applied");
    }

    // ---- saved presets: the whole look and layout under a name (presets.json) ----------------
    property var presetList: []
    readonly property var presetSkip: ["userWalls", "wallIdx"]    // tied to files on this machine
    FileView {
        id: presetStore
        path: Quickshell.shellPath("presets.json")
        printErrors: false
        onLoaded: { try { const l = JSON.parse(text()); if (Array.isArray(l)) shellRoot.presetList = l; } catch (e) { console.warn("presets.json unreadable:", e); } }
    }
    function writePresets(list) { presetList = list; presetStore.setText(JSON.stringify(list, null, 2)); }
    function savePreset(name) {
        name = (name || "").trim();
        if (name === "") { notify("Give the preset a name first"); return false; }
        const data = JSON.parse(JSON.stringify(cfg));
        for (const k of presetSkip) delete data[k];
        const exists = presetList.some(p => p.name === name);
        writePresets(presetList.filter(p => p.name !== name).concat([{ "name": name, "data": data }]));
        notify(exists ? "Preset updated" : "Preset saved");
        return true;
    }
    function applyPreset(name) {
        const p = presetList.find(x => x.name === name);
        if (!p) return;
        const c = Object.assign({}, cfg);
        for (const k in p.data) {
            if (k in defaults && typeof p.data[k] === typeof defaults[k] && presetSkip.indexOf(k) < 0) c[k] = p.data[k];
        }
        if (!themesData.data[c.theme]) c.theme = cfg.theme;
        c.barStyle = normalizeStyle(c.barStyle);
        c.modules = sanitizeModules(c.modules);
        cfg = c;
        saveTimer.restart();
        applyTimer.restart();
        notify("Preset \"" + name + "\" applied");
    }
    function deletePreset(name) { writePresets(presetList.filter(p => p.name !== name)); notify("Preset deleted"); }

    function reapply() { applyTimer.restart(); }
    function openSettings() { settingsOpen = true; }
    function closeSettings() { settingsOpen = false; }

    // Pushes the theme and window geometry to kitty, rofi, fish, GTK, hyprlock and Hyprland.
    Process { id: applier }
    Timer {
        id: applyTimer; interval: 250
        onTriggered: {
            if (!shellRoot.settingsLoaded) return;
            applier.command = ["python3", Quickshell.shellPath("scripts/apply-theme.py"), shellRoot.cfg.theme, JSON.stringify(shellRoot.cfg)];
            applier.running = true;
        }
    }
    Timer {
        interval: Math.max(1, shellRoot.cfg.wallCycle) * 60000
        running: shellRoot.cfg.wallCycle > 0 && !shellRoot.wantLocked
        repeat: true
        onTriggered: shellRoot.shuffleWallpaper()
    }

    FileView {
        id: store
        path: Quickshell.shellPath("settings.json")
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                const c = Object.assign({}, shellRoot.defaults);
                for (const k in c) if (d[k] !== undefined && typeof d[k] === typeof c[k]) c[k] = d[k];
                if (!themesData.data[c.theme]) c.theme = "everforest";
                c.barStyle = shellRoot.normalizeStyle(c.barStyle);
                c.modules = shellRoot.sanitizeModules(d.modules !== undefined ? d.modules : c.modules);
                shellRoot.cfg = c;
            } catch (e) { console.warn("settings.json unreadable:", e); }
            shellRoot.settingsLoaded = true;
            applyTimer.restart();
        }
        onLoadFailed: { shellRoot.settingsLoaded = true; applyTimer.restart(); }
    }
    Timer {
        id: saveTimer; interval: 400
        onTriggered: if (shellRoot.settingsLoaded) store.setText(JSON.stringify(shellRoot.cfg, null, 2))
    }

    readonly property var screens: {
        if (Quickshell.screens.length > 0) return Quickshell.screens;
        if (Quickshell.primaryScreen) return [Quickshell.primaryScreen];
        return [];
    }

    IpcHandler {
        target: "shell"
        function lock() { shellRoot.preview = false; shellRoot.lockNow(); }
        function lockPreview() { shellRoot.preview = true; shellRoot.lockNow(); }
        function unlock() { if (shellRoot.preview) shellRoot.beginUnlock(); }
        function setTheme(theme: string) { shellRoot.setTheme(theme); }
        function set(key: string, value: string) { shellRoot.set(key, JSON.parse(value)); }
        function addWallpaper(path: string, themed: bool) { shellRoot.addWallpaper(path, themed); }
        function saveTheme(spec: string) { shellRoot.saveCustomTheme(JSON.parse(spec)); }
        function applyLook(id: string) { shellRoot.applyLook(id); }
        function savePreset(name: string) { shellRoot.savePreset(name); }
        function applyPreset(name: string) { shellRoot.applyPreset(name); }
        function deletePreset(name: string) { shellRoot.deletePreset(name); }
        function toggleSettings() { shellRoot.settingsOpen = !shellRoot.settingsOpen; }
        function openSettings() { shellRoot.openSettings(); }
        function closeSettings() { shellRoot.closeSettings(); }
    }

    // Wallpaper (replaces swaybg; crossfades on theme change)
    Variants {
        model: shellRoot.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            color: "black"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-wallpaper"
            Wallpaper { anchors.fill: parent; source: shellRoot.wallpaperSource; dim: shellRoot.cfg.wallDim; blur: shellRoot.cfg.wallBlur; fit: shellRoot.cfg.wallFit === "fit" }
        }
    }

    // Settings panel (Super + ,)
    Variants {
        model: shellRoot.screens
        Settings {
            required property var modelData
            screen: modelData
            shell: shellRoot
            wanted: shellRoot.settingsOpen && (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === shellRoot.screens[0])
        }
    }

    Variants {
        model: shellRoot.screens
        Bar {
            required property var modelData
            screen: modelData
            shell: shellRoot
        }
    }

    // Wi-Fi / Bluetooth menus that grow out of the bar buttons
    Variants {
        model: shellRoot.screens
        Popups {
            required property var modelData
            screen: modelData
            shell: shellRoot
        }
    }

    // =========================================================================
    // LOCKSCREEN (real ext-session-lock; preview mode uses a fullscreen overlay)
    // =========================================================================
    WlSessionLock {
        locked: shellRoot.wantLocked && !shellRoot.preview
        WlSessionLockSurface {
            id: lockSurface
            color: "black"
            LockContent {
                anchors.fill: parent
                shell: shellRoot
                shotPath: "file://" + shellRoot.shotDir + "/" + lockSurface.screen.name + ".png"
                status: shellRoot.authStatus
                onSubmit: pw => shellRoot.submitPassword(pw)
                Connections { target: shellRoot; function onAuthFailed() { clear(); shake(); focusInput(); } }
            }
        }
    }

    Variants {
        model: shellRoot.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: shellRoot.preview && shellRoot.wantLocked
            color: "black"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-lock-preview"
            LockContent {
                anchors.fill: parent
                shell: shellRoot
                shotPath: "file://" + shellRoot.shotDir + "/" + modelData.name + ".png"
                status: shellRoot.authStatus
                onSubmit: pw => shellRoot.submitPassword(pw)
                Connections { target: shellRoot; function onAuthFailed() { clear(); shake(); focusInput(); } }
            }
        }
    }
}
