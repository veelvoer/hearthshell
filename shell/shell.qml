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
        speed: ({ "off": 40, "relaxed": 0.65, "normal": 1, "snappy": 1.6 })[shellRoot.cfg.motion] * Math.max(0.1, shellRoot.cfg.animSpeed)
        barPx: shellRoot.cfg.barFont
        iconMode: shellRoot.cfg.iconMode
        burst: shellRoot.cfg.colorBurst
        barOverride: shellRoot.cfg.barColor !== "" ? shellRoot.cfg.barColor : "transparent"
        panelOverride: shellRoot.cfg.panelColor !== "" ? shellRoot.cfg.panelColor : "transparent"
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
        "drawnIcons": false, "islandSplit": false, "islandPanel": true, "colorBurst": false, "islandOpenOn": "hover", "islandHoverDelay": 0, "islandGap": 0, "islandBorder": true, "islandShadow": true, "islandShowWs": true, "islandShowStatus": true, "islandShowEq": true, "islandPanelLeft": true, "islandPanelRight": true, "islandPeekLevels": true, "islandPeekMedia": true, "barColor": "", "panelColor": "", "islandCollapsedW": 0, "islandPanelH": 172, "ccLayout": { "cols": 6, "items": {} }, "nightLevel": 2, "shortcuts": {}, "shortcutsApplied": [], "homeEnabled": true, "homeWidgets": [], "lockWidgetsEnabled": true, "lockWidgets": [], "widgetNotes": {}, "widgetStyle": "auto", "widgetRadius": 26, "lockClockY": 0.4, "lockDim": 0, "notifTimeout": 6, "weekMonday": true, "ccOrder": ["wifi", "bluetooth", "audio", "quiet", "night", "volume", "brightness", "media", "notifications"], "ccHidden": ["airplane", "caffeine", "game", "mic", "micvol", "screenshot", "wallpaper", "theme", "battery", "system"], "motionBounce": 0.5, "notifications": true, "glassWindows": false, "glassBrowsers": true, "glassFiles": true, "glassEditors": true, "glassChat": true, "glassOther": true,
        "userWalls": {},
        "font": "Inter", "motion": "normal", "accent": "", "wallFit": "fill",
        "barHeight": 30, "barGap": 4, "barSide": 10, "barFont": 13, "modSpacing": 0, "iconMode": "accent",
        "wsStyle": "pills", "wsCount": 9, "wsSlots": 5, "animSpeed": 1, "animPreset": "apple", "animAdvanced": false, "animAdv": {}, "wsOccupiedOnly": false, "clockDate": false,
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
        "motion", "animSpeed", "animPreset", "animAdvanced", "animAdv", "accent", "shadow", "shadowSize", "gradientBorder", "followMouse", "naturalScroll", "tapToClick",
        "pointerSpeed", "repeatRate", "repeatDelay", "kittyFont", "kittyPad", "kittyCursor", "rofiWidth", "rofiLines", "rofiIcons"]
    property var cfg: defaults
    property bool settingsOpen: false
    property bool launcherOpen: false
    property bool powerOpen: false
    property string overlayScreen: ""         // the screen the launcher / power menu opened on (the focused one at that moment)
    function toggleLauncher() {
        powerOpen = false;
        if (!launcherOpen) overlayScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (screens.length > 0 ? screens[0].name : "");
        launcherOpen = !launcherOpen;
    }
    function togglePower() {
        launcherOpen = false;
        if (!powerOpen) overlayScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (screens.length > 0 ? screens[0].name : "");
        powerOpen = !powerOpen;
    }
    Notifier { id: notifierObj }
    readonly property var notifier: notifierObj
    readonly property var shortcutActions: [
        { "id": "quick", "group": "Island menus", "label": "Control Center", "desc": "Open or close the Control Center", "fn": "openMenu", "arg": "quick" },
        { "id": "theme", "group": "Island menus", "label": "Theme menu", "desc": "Pick a theme", "fn": "openMenu", "arg": "theme" },
        { "id": "wallpaper", "group": "Island menus", "label": "Wallpaper menu", "desc": "Pick a wallpaper", "fn": "openMenu", "arg": "wallpaper" },
        { "id": "calendar", "group": "Island menus", "label": "Calendar", "desc": "Open the calendar", "fn": "openMenu", "arg": "calendar" },
        { "id": "notifications", "group": "Island menus", "label": "Notifications", "desc": "Open the notification centre", "fn": "openMenu", "arg": "notifications" },
        { "id": "sound", "group": "Island menus", "label": "Sound menu", "desc": "Volume, outputs and microphones", "fn": "openMenu", "arg": "sound" },
        { "id": "display", "group": "Island menus", "label": "Display menu", "desc": "Brightness and screen options", "fn": "openMenu", "arg": "display" },
        { "id": "network", "group": "Island menus", "label": "Wi-Fi menu", "desc": "Networks", "fn": "openMenu", "arg": "network" },
        { "id": "bluetooth", "group": "Island menus", "label": "Bluetooth menu", "desc": "Devices", "fn": "openMenu", "arg": "bluetooth" },
        { "id": "media", "group": "Island menus", "label": "Now playing", "desc": "Open the media player", "fn": "openMenu", "arg": "media" },
        { "id": "launcher", "group": "Shell", "label": "App launcher", "desc": "Open the launcher", "fn": "toggleLauncher", "arg": "" },
        { "id": "power", "group": "Shell", "label": "Power menu", "desc": "Lock, sleep, restart, shut down", "fn": "togglePower", "arg": "" },
        { "id": "settings", "group": "Shell", "label": "Settings", "desc": "Open or close settings", "fn": "toggleSettings", "arg": "" },
        { "id": "lock", "group": "Shell", "label": "Lock screen", "desc": "Lock the computer", "fn": "lock", "arg": "" },
        { "id": "dnd", "group": "Quick actions", "label": "Quiet mode", "desc": "Toggle do not disturb", "fn": "toggleDnd", "arg": "" },
        { "id": "night", "group": "Quick actions", "label": "Night Light", "desc": "Toggle the warm screen colour", "fn": "toggle", "arg": "night" },
        { "id": "game", "group": "Quick actions", "label": "Game Mode", "desc": "Toggle Game Mode", "fn": "toggle", "arg": "game" },
        { "id": "caffeine", "group": "Quick actions", "label": "Keep Awake", "desc": "Toggle Keep Awake", "fn": "toggle", "arg": "caffeine" },
        { "id": "nextWall", "group": "Quick actions", "label": "Next wallpaper", "desc": "Shuffle to another wallpaper", "fn": "shuffleWallpaper", "arg": "" },
        { "id": "editDesktop", "group": "Shell", "label": "Edit desktop", "desc": "Customize the desktop widgets", "fn": "editDesktop", "arg": "home" },
        { "id": "nextTheme", "group": "Quick actions", "label": "Next theme", "desc": "Switch to the next theme", "fn": "nextTheme", "arg": "" } ]
    ShortcutManager { id: shortcutsObj; shell: shellRoot }
    readonly property var shortcuts: shortcutsObj
    WidgetDefs { id: widgetDefsObj }
    readonly property var widgetDefs: widgetDefsObj
    readonly property var widgetTypes: widgetDefsObj.types
    readonly property var widgetOrder: widgetDefsObj.order
    function setNote(id, text) {
        const n = Object.assign({}, cfg.widgetNotes || {});
        n[id] = text;
        set("widgetNotes", n);
    }
    // what this computer has, so Settings only offers what can work here
    // ---- Hyprland animations: presets, plus an advanced mode that overrides single values. The result is computed here once.
    readonly property var animGroups: [
        { "id": "windows", "label": "Windows", "styles": [["popin 90%", "Pop in"], ["popin 70%", "Deep pop"], ["slide", "Slide"], ["gnomed", "Fold"]] },
        { "id": "workspaces", "label": "Workspaces", "styles": [["slide", "Slide"], ["slidevert", "Vertical"], ["fade", "Fade"], ["slidefade 20%", "Slide + fade"]] },
        { "id": "layers", "label": "Menus and panels", "styles": [["popin 93%", "Pop in"], ["slide", "Slide"], ["fade", "Fade"]] },
        { "id": "fade", "label": "Fading", "styles": [] },
        { "id": "border", "label": "Borders", "styles": [] } ]
    readonly property var animCurves: [["spring", "Soft spring"], ["bounce", "Bouncy"], ["ease", "Smooth"], ["snap", "Snappy"], ["soft", "Gentle"], ["linear", "Linear"]]
    readonly property var animPresets: ({
        "apple": { "label": "Apple", "desc": "Soft springs, like macOS",
            "windows": { "speed": 4.5, "style": "popin 90%", "curve": "spring" }, "workspaces": { "speed": 4.8, "style": "slide", "curve": "ease" },
            "layers": { "speed": 3.8, "style": "popin 93%", "curve": "spring" }, "fade": { "speed": 3, "curve": "ease" }, "border": { "speed": 4.5, "curve": "ease" } },
        "smooth": { "label": "Smooth", "desc": "Calm and even, nothing bounces",
            "windows": { "speed": 5.5, "style": "popin 85%", "curve": "ease" }, "workspaces": { "speed": 5.5, "style": "slide", "curve": "ease" },
            "layers": { "speed": 4.5, "style": "popin 95%", "curve": "ease" }, "fade": { "speed": 4, "curve": "ease" }, "border": { "speed": 5, "curve": "ease" } },
        "snappy": { "label": "Snappy", "desc": "Short and sharp, for speed",
            "windows": { "speed": 2.4, "style": "popin 92%", "curve": "snap" }, "workspaces": { "speed": 2.6, "style": "slide", "curve": "snap" },
            "layers": { "speed": 2.2, "style": "popin 96%", "curve": "snap" }, "fade": { "speed": 2, "curve": "snap" }, "border": { "speed": 2.5, "curve": "snap" } },
        "bouncy": { "label": "Bouncy", "desc": "Playful, with a little overshoot",
            "windows": { "speed": 5, "style": "popin 80%", "curve": "bounce" }, "workspaces": { "speed": 5.2, "style": "slidefade 20%", "curve": "bounce" },
            "layers": { "speed": 4.5, "style": "popin 88%", "curve": "bounce" }, "fade": { "speed": 3.5, "curve": "ease" }, "border": { "speed": 4.5, "curve": "ease" } },
        "slide": { "label": "Slide", "desc": "Everything glides in from the side",
            "windows": { "speed": 4, "style": "slide", "curve": "ease" }, "workspaces": { "speed": 4.5, "style": "slide", "curve": "ease" },
            "layers": { "speed": 3.5, "style": "slide", "curve": "ease" }, "fade": { "speed": 3, "curve": "ease" }, "border": { "speed": 4, "curve": "ease" } },
        "minimal": { "label": "Minimal", "desc": "Quiet fades, almost no movement",
            "windows": { "speed": 2.5, "style": "popin 97%", "curve": "soft" }, "workspaces": { "speed": 3, "style": "fade", "curve": "soft" },
            "layers": { "speed": 2.5, "style": "fade", "curve": "soft" }, "fade": { "speed": 2.5, "curve": "soft" }, "border": { "speed": 3, "curve": "soft" } },
        "off": { "label": "Off", "desc": "No animations in Hyprland",
            "windows": { "speed": 1, "style": "popin 100%", "curve": "linear" }, "workspaces": { "speed": 1, "style": "fade", "curve": "linear" },
            "layers": { "speed": 1, "style": "fade", "curve": "linear" }, "fade": { "speed": 1, "curve": "linear" }, "border": { "speed": 1, "curve": "linear" } } })
    readonly property var animOrder: ["apple", "smooth", "snappy", "bouncy", "slide", "minimal", "off"]
    function animValue(group, key) {
        const adv = cfg.animAdvanced && cfg.animAdv && cfg.animAdv[group] && cfg.animAdv[group][key] !== undefined ? cfg.animAdv[group][key] : undefined;
        if (adv !== undefined) return adv;
        const p = animPresets[cfg.animPreset] || animPresets.apple;
        return p[group][key];
    }
    function setAnimAdv(group, key, value) {
        const a = JSON.parse(JSON.stringify(cfg.animAdv || {}));
        if (!a[group]) a[group] = {};
        a[group][key] = value;
        set("animAdv", a);
    }
    readonly property var animSet: {
        const out = { "enabled": cfg.animPreset !== "off" && cfg.motion !== "off", "speed": Math.max(0.1, cfg.animSpeed) };
        for (const g of animGroups) { out[g.id] = { "speed": animValue(g.id, "speed"), "curve": animValue(g.id, "curve") }; if (g.styles.length > 0) out[g.id].style = animValue(g.id, "style"); }
        return out;
    }
    property bool islandMenuOpen: false           // a menu is open on the island: pop-ups wait so they do not cover it
    property var caps: ({ "kitty": true, "rofi": true, "fish": true, "hyprlock": true, "battery": true, "backlight": true, "touchpad": true, "bluetooth": true, "wifi": true })
    Process {
        id: capsProbe
        running: true
        command: ["sh", "-c", "for t in kitty rofi fish hyprlock; do command -v $t >/dev/null 2>&1 && echo $t=1 || echo $t=0; done; " +
            "ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && echo battery=1 || echo battery=0; " +
            "[ -n \"$(ls /sys/class/backlight 2>/dev/null)\" ] && echo backlight=1 || echo backlight=0; " +
            "grep -qi touchpad /proc/bus/input/devices 2>/dev/null && echo touchpad=1 || echo touchpad=0; " +
            "[ -n \"$(ls /sys/class/bluetooth 2>/dev/null)\" ] && echo bluetooth=1 || echo bluetooth=0; " +
            "ls /sys/class/net/*/wireless >/dev/null 2>&1 && echo wifi=1 || echo wifi=0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = {};
                for (const l of text.trim().split("\n")) { const p = l.split("="); if (p.length === 2) c[p[0]] = p[1] === "1"; }
                shellRoot.caps = Object.assign({}, shellRoot.caps, c);
            }
        }
    }
    SystemStats { id: statsObj }
    readonly property var stats: statsObj
    DesktopEditor { id: editorObj; shell: shellRoot }
    readonly property var editor: editorObj
    HomeWidgets { shell: shellRoot }
    UpdateChecker { id: updaterObj }
    readonly property var updater: updaterObj
    SystemToggles { id: togglesObj; nightLevel: shellRoot.cfg.nightLevel }
    readonly property var toggles: togglesObj
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
        "launcher": { "label": "App launcher", "desc": "A button that opens the built-in launcher", "file": "LauncherButton.qml" },
        "media": { "label": "Now playing", "desc": "Title and artist of the song or video playing; click to pause, scroll to skip", "file": "MediaModule.qml" },
        "notifications": { "label": "Notifications", "desc": "Bell with the notification list; right click for Do not disturb", "file": "NotifButton.qml" },
        "power": { "label": "Power menu", "desc": "Lock, log out, sleep, restart, shut down", "file": "PowerButton.qml" },
        "battery": { "label": "Battery", "desc": "Hidden when there is no battery", "file": "Battery.qml" }
    })
    readonly property var moduleOrder: ["workspaces", "clock", "volume", "brightness", "network", "bluetooth", "quick", "battery", "launcher", "media", "notifications", "power"]
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

    // ---- Control Center layout ---------------------------------------------
    readonly property var ccAll: ["wifi", "bluetooth", "audio", "quiet", "night", "airplane", "caffeine", "game", "mic", "screenshot", "wallpaper", "theme", "battery", "volume", "micvol", "brightness", "performance", "system", "media", "notifications"]
    readonly property var ccLabels: ({
        "wifi": ["Wi-Fi", "Network tile with the name of the network"], "bluetooth": ["Bluetooth", "Tile with the connected device"],
        "audio": ["Audio", "Output device tile; the arrow switches output"], "quiet": ["Quiet", "Do not disturb for notification pop-ups"],
        "night": ["Night Light", "Warm screen colour for the evening"], "airplane": ["Airplane", "Switch every radio off at once"],
        "caffeine": ["Keep Awake", "Stop the screen and the computer from going to sleep"], "game": ["Game Mode", "Turn off animations, blur and gaps for speed"],
        "mic": ["Microphone", "Mute or unmute the microphone"], "screenshot": ["Screenshot", "Pick a region and copy it to the clipboard"],
        "wallpaper": ["Wallpaper", "Shuffle to another wallpaper of this theme"], "theme": ["Theme", "Switch to the next theme"],
        "battery": ["Battery", "Charge level and time left"], "volume": ["Volume", "Slider"], "micvol": ["Mic volume", "Microphone input level slider"],
        "brightness": ["Brightness", "Slider (laptop screens)"], "performance": ["Performance", "Eco, Normal or Performance power mode"],
        "system": ["System", "Processor, memory and temperature"], "media": ["Now playing", "Card with the cover, buttons and progress"],
        "notifications": ["Notifications", "The latest ones, with Clear all"] })
    readonly property var ccFull: {
        const out = (cfg.ccOrder && cfg.ccOrder.length > 0 ? cfg.ccOrder : ccAll).slice();
        for (let i = 0; i < ccAll.length; i++) {
            if (out.indexOf(ccAll[i]) >= 0) continue;
            let at = out.length;
            for (let j = i + 1; j < ccAll.length; j++) { const k = out.indexOf(ccAll[j]); if (k >= 0) { at = k; break; } }
            out.splice(at, 0, ccAll[i]);
        }
        return out;
    }
    readonly property var ccDefaultHidden: ["airplane", "caffeine", "game", "mic", "micvol", "screenshot", "wallpaper", "theme", "battery", "system"]
    readonly property var ccGlyphs: ({ "wifi": 0xF05A9, "bluetooth": 0xF00AF, "audio": 0xF057E, "quiet": 0xF009B, "night": 0xF0594, "airplane": 0xF001D,
        "caffeine": 0xF0176, "game": 0xF0297, "mic": 0xF036C, "screenshot": 0xF0E51, "wallpaper": 0xF0E09, "theme": 0xF03D8, "battery": 0xF0079,
        "volume": 0xF057E, "micvol": 0xF036C, "brightness": 0xF00E0, "performance": 0xF04C5, "system": 0xF061A, "media": 0xF075A, "notifications": 0xF009A })
    readonly property var ccMinSize: ({ "volume": [2, 1], "micvol": [2, 1], "brightness": [2, 1], "performance": [2, 1], "system": [3, 2], "media": [3, 2], "notifications": [3, 2] })
    readonly property var ccWide: ["volume", "micvol", "brightness", "performance"]
    function ccDefSize(id, cols) {
        if (id === "media") return [cols, 3];
        if (id === "notifications" || id === "system") return [cols, 2];
        if (ccWide.indexOf(id) >= 0) return [cols, 1];
        return [Math.max(1, Math.floor(cols / 2)), 1];
    }
    function ccCompute() {
        const L = cfg.ccLayout || {};
        const cols = Math.max(5, Math.min(9, L.cols || 6));
        const saved = L.items || {};
        const hidden = cfg.ccHidden || [];
        const occ = {};
        const out = {};
        const mark = it => { for (let j = 0; j < it.h; j++) for (let i = 0; i < it.w; i++) occ[(it.y + j) * 20 + it.x + i] = true; };
        const free = (x, y, w, h) => {
            if (x < 0 || x + w > cols) return false;
            for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (occ[(y + j) * 20 + x + i]) return false;
            return true;
        };
        const sized = id => {
            const d = ccDefSize(id, cols), mn = ccMinSize[id] || [1, 1], sv = saved[id];
            const w = sv ? sv.w : d[0], h = sv ? sv.h : d[1];
            return [Math.max(mn[0], Math.min(cols, w)), Math.max(mn[1], Math.min(6, h))];
        };
        const ids = ccFull.filter(id => hidden.indexOf(id) < 0);
        for (const id of ids) {
            const sv = saved[id];
            if (!sv) continue;
            const sz = sized(id), it = { "x": Math.max(0, Math.min(cols - sz[0], sv.x)), "y": Math.max(0, sv.y), "w": sz[0], "h": sz[1] };
            if (free(it.x, it.y, it.w, it.h)) { out[id] = it; mark(it); }
        }
        for (const id of ids) {
            if (out[id]) continue;
            const sz = sized(id);
            let placed = false;
            for (let y = 0; !placed && y < 60; y++) for (let x = 0; !placed && x + sz[0] <= cols; x++) {
                if (free(x, y, sz[0], sz[1])) { const it = { "x": x, "y": y, "w": sz[0], "h": sz[1] }; out[id] = it; mark(it); placed = true; }
            }
        }
        return { "cols": cols, "items": out };
    }
    readonly property var ccGrid: ccCompute()
    property var ccHistory: []
    function ccSnapshot() {
        const h = ccHistory.slice(-19);
        h.push({ "layout": JSON.parse(JSON.stringify(cfg.ccLayout || { "cols": 6, "items": {} })), "hidden": (cfg.ccHidden || []).slice() });
        ccHistory = h;
    }
    function ccUndo() {
        if (ccHistory.length === 0) return;
        const h = ccHistory.slice(), s = h.pop();
        ccHistory = h;
        set("ccLayout", s.layout); set("ccHidden", s.hidden);
    }
    function ccCollides(a, b) { return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h; }
    function ccPlace(id, x, y, w, h) {
        ccSnapshot();
        const g = ccGrid, cols = g.cols, mn = ccMinSize[id] || [1, 1];
        w = Math.max(mn[0], Math.min(cols, w)); h = Math.max(mn[1], Math.min(6, h));
        x = Math.max(0, Math.min(cols - w, x)); y = Math.max(0, y);
        const items = {};
        for (const k in g.items) items[k] = Object.assign({}, g.items[k]);
        items[id] = { "x": x, "y": y, "w": w, "h": h };
        const queue = [id];
        let guard = 0;
        while (queue.length > 0 && guard++ < 400) {
            const cid = queue.shift(), cur = items[cid];
            for (const k in items) {
                if (k === cid || k === id) continue;
                if (ccCollides(cur, items[k])) { items[k].y = cur.y + cur.h; queue.push(k); }
            }
        }
        set("ccLayout", { "cols": cols, "items": items });
    }
    function ccCompact() {
        ccSnapshot();
        const g = ccGrid;
        const ids = Object.keys(g.items).sort((a, b) => g.items[a].y - g.items[b].y || g.items[a].x - g.items[b].x);
        const placed = {};
        for (const id of ids) {
            const it = Object.assign({}, g.items[id]);
            while (it.y > 0) {
                const up = { "x": it.x, "y": it.y - 1, "w": it.w, "h": it.h };
                if (Object.keys(placed).some(k => ccCollides(up, placed[k]))) break;
                it.y--;
            }
            placed[id] = it;
        }
        set("ccLayout", { "cols": g.cols, "items": placed });
    }
    function ccSetCols(n) {
        ccSnapshot();
        set("ccLayout", { "cols": n, "items": (cfg.ccLayout && cfg.ccLayout.items) || {} });
    }
    function ccToggle(id) {
        ccSnapshot();
        const h = (cfg.ccHidden || []).slice();
        const i = h.indexOf(id);
        if (i >= 0) {
            h.splice(i, 1);
            const g = ccGrid, d = ccDefSize(id, g.cols), mn = ccMinSize[id] || [1, 1];
            let bottom = 0;
            for (const k in g.items) bottom = Math.max(bottom, g.items[k].y + g.items[k].h);
            const items = JSON.parse(JSON.stringify(g.items));
            items[id] = { "x": 0, "y": bottom, "w": Math.max(mn[0], d[0]), "h": Math.max(mn[1], d[1]) };
            set("ccLayout", { "cols": g.cols, "items": items });
        } else h.push(id);
        set("ccHidden", h);
    }
    function ccReset() { ccSnapshot(); set("ccOrder", ccAll.slice()); set("ccHidden", ccDefaultHidden.slice()); set("ccLayout", { "cols": 6, "items": {} }); }

    // ---- popup menus (Wi-Fi, Bluetooth) ---------------------------------
    property var popup: ({ "kind": "", "screen": "", "rect": {}, "glyph": "", "label": "" })
    property string popupHost: ""           // "<kind>@<screen>" while a menu card is on screen
    function togglePopup(kind, screenName, rect, glyph, label) {
        if (popup.kind === kind && popup.screen === screenName) { closePopup(); return; }
        popup = { "kind": kind, "screen": screenName, "rect": rect, "glyph": glyph, "label": label };
    }
    property var bars: ({})                  // the bar window of each screen, by name
    function menuGlyph(k) { return menuGlyphs.glyphFor(k); }
    MenuStack { id: menuGlyphs; visible: false; width: 0; height: 0; menu: "" }
    function openMenu(kind) {
        const b = bars[focusedMonitorName()];
        if (b) b.openMenuAt(kind);
    }
    function focusedMonitorName() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (screens.length > 0 ? screens[0].name : ""); }
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
        "glassBar", "glassPanel", "glassLauncher", "glassTerminal", "glassAmount", "glassWindows", "glassBrowsers", "glassFiles", "glassEditors", "glassChat", "glassOther", "blur", "blurSize", "wsStyle", "iconMode", "drawnIcons"]
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
            applier.command = ["python3", Quickshell.shellPath("scripts/apply-theme.py"), shellRoot.cfg.theme, JSON.stringify(Object.assign({}, shellRoot.cfg, { "animSet": shellRoot.animSet }))];
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
        function toggleLauncher() { shellRoot.toggleLauncher(); }
        function togglePower() { shellRoot.togglePower(); }
        function openMenu(kind: string) { shellRoot.openMenu(kind); }
        function closeMenus() { const b = bars[focusedMonitorName()]; if (b && b.islandRef) b.islandRef.goBack(); }
        function toggleDnd() { notifier.dnd = !notifier.dnd; }
        function shuffleWallpaper() { shellRoot.shuffleWallpaper(); }
        function editDesktop(tab: string) { shellRoot.closeSettings(); editorObj.show(tab); }
        function nextTheme() {
            const o = themesData.order, i = o.indexOf(cfg.theme);
            shellRoot.setTheme(o[(i + 1) % o.length]);
        }
        function toggle(name: string) {
            if (name === "night") togglesObj.toggleNight();
            else if (name === "game") togglesObj.toggleGame();
            else if (name === "airplane") togglesObj.toggleAirplane();
            else if (name === "caffeine") togglesObj.toggleCaffeine();
        }
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
        model: shellRoot.cfg.barStyle === "island" ? [] : shellRoot.screens      // the island hosts its own menus
        Popups {
            required property var modelData
            screen: modelData
            shell: shellRoot
        }
    }

    // app launcher, power menu and notification pop-ups
    Variants { model: shellRoot.screens; Launcher { required property var modelData; screen: modelData; shell: shellRoot } }
    Variants { model: shellRoot.screens; PowerMenu { required property var modelData; screen: modelData; shell: shellRoot } }
    Variants {
        model: shellRoot.screens.length > 0 ? [shellRoot.screens[0]] : []
        NotificationToasts { required property var modelData; screen: modelData; shell: shellRoot; notifier: shellRoot.notifier }
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
                shotPath: "file://" + shellRoot.shotDir + "/" + (lockSurface.screen ? lockSurface.screen.name : "") + ".png"
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
