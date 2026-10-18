// qmllint disable
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Full-screen overlay that hosts the Wi-Fi / Bluetooth menus. The card grows out of the
// bar button that opened it (position, size, corner radius and icon all interpolate).
PanelWindow {
    id: win
    required property var shell

    readonly property string myScreen: screen ? screen.name : ""
    readonly property bool wanted: shell.popup.kind !== "" && shell.popup.screen === myScreen
    property string kind: ""
    property var rect: ({ "x": 0, "y": 0, "w": 10, "h": 10 })
    property string glyph: ""
    property string label: ""
    property real p: 0                       // 0 = the button, 1 = the open menu

    readonly property real tw: 360
    readonly property real maxH: Math.max(200, Math.min(580, height - 140))
    readonly property var openItem: kind === "network" ? netLoader.item : (kind === "bluetooth" ? btLoader.item : (kind === "quick" ? quickLoader.item : (kind === "notifications" ? notifLoader.item : (kind === "calendar" ? calLoader.item : null))))
    readonly property real wantedH: openItem ? Math.min(maxH, openItem.wantedHeight) : 120
    property real th: wantedH
    Behavior on th { NumberAnimation { duration: main.ms(280); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }

    readonly property bool below: shell.cfg.barPos !== "bottom"
    readonly property real tx: Math.max(12, Math.min(width - tw - 12, rect.x + rect.w / 2 - tw / 2))
    readonly property real ty: below ? rect.y + rect.h + 10 : rect.y - 10 - th
    readonly property real fontPx: 13

    // from the quick settings menu to the Wi-Fi or Bluetooth menu, in the same card
    property string from: ""                 // "quick" while Wi-Fi / Bluetooth is open from the quick settings menu
    property string quickGlyph: String.fromCodePoint(0xF0570)
    function goBack() {
        if (from === "quick") switchKind("quick"); else shell.closePopup();
    }
    function switchKind(k) {
        const g = k === "network" ? String.fromCodePoint(0xF05A9) : k === "bluetooth" ? String.fromCodePoint(0xF00AF) : quickGlyph;
        from = k === "quick" ? "" : "quick";
        kind = k; glyph = g; label = "";
        shell.popupHost = k + "@" + myScreen;
        shell.popup = Object.assign({}, shell.popup, { "kind": k, "glyph": g, "label": "" });
    }
    function lerp(a, b, t) { return a + (b - a) * t; }
    function clamp01(v) { return Math.max(0, Math.min(1, v)); }

    // One invisible open/close of each menu shortly after start-up, so the first real
    // open does not pay for glyph, shader and layout set-up.
    Timer { interval: 4500; running: true; onTriggered: if (!win.wanted) win.warm("network") }
    function warm(which) {
        kind = which;
        rect = { "x": width - 260, "y": 4, "w": 70, "h": 24 };
        warming = true;
        warmAnim.start();
    }
    SequentialAnimation {
        id: warmAnim
        NumberAnimation { target: win; property: "p"; to: 1; duration: main.ms(450) }
        PauseAnimation { duration: main.ms(120) }
        NumberAnimation { target: win; property: "p"; to: 0; duration: main.ms(250) }
        ScriptAction { script: {
            const was = win.kind;
            win.warming = false;
            if (was === "network" && !win.wanted) win.warm("bluetooth");
            else if (!win.wanted) win.kind = "";
        } }
    }

    onWantedChanged: {
        if (wanted) {
            warmAnim.stop();
            warming = false;
            from = "";
            kind = shell.popup.kind;
            rect = shell.popup.rect;
            glyph = shell.popup.glyph;
            label = shell.popup.label;
            shell.popupHost = kind + "@" + myScreen;
            closeAnim.stop();
            cOpOut.stop();
            openAnim.start();
            cOpIn.restart();
        } else {
            openAnim.stop();
            cOpIn.stop();
            cOpOut.restart();
            closeAnim.start();
        }
    }
    // Same motion as the lock screen clock gliding into the bar: one expo-out curve drives the geometry
    // both ways, the content fades in late (after a short pause) and out first.
    property real cOp: 0
    NumberAnimation { id: openAnim; target: win; property: "p"; to: 1; duration: main.ms(700)
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] }
    NumberAnimation { id: closeAnim; target: win; property: "p"; to: 0; duration: main.ms(750)
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        onFinished: if (shell.popupHost === win.kind + "@" + win.myScreen) shell.popupHost = "" }

    SequentialAnimation { id: cOpIn
        PauseAnimation { duration: main.ms(300) }
        NumberAnimation { target: win; property: "cOp"; to: 1; duration: main.ms(300); easing.type: Easing.OutCubic } }
    NumberAnimation { id: cOpOut; target: win; property: "cOp"; to: 0; duration: main.ms(160) }

    // The surface stays mapped but empty, so opening never pays for creating a window or
    // compiling the menus. It only takes input while a menu is up.
    property bool warming: false
    readonly property bool live: wanted || (p > 0.002 && !warming)
    color: "transparent"
    visible: true
    mask: Region { item: win.live ? hitArea : null }
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { id: hitArea; anchors.fill: parent; onClicked: win.shell.closePopup() }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: win.wanted
        Keys.onEscapePressed: {
            if (win.openItem && win.openItem.typing) scope.forceActiveFocus();
            else win.goBack();
        }
    }

    Rectangle {
        id: card
        x: win.lerp(win.rect.x, win.tx, win.p)
        y: win.lerp(win.rect.y, win.ty, win.p)
        width: win.lerp(win.rect.w, win.tw, win.p)
        height: win.lerp(win.rect.h, win.th, win.p)
        radius: win.lerp(8, 22, win.p)
        // starts out as the bar's own colour so the button seems to lift off the bar
        color: Qt.alpha(Qt.tint(main.bg, Qt.rgba(main.page.r, main.page.g, main.page.b, win.clamp01(win.p * 2.2))), main.menuAlpha)
        border.width: 1
        border.color: main.border
        opacity: win.warming ? 0.01 : Math.min(1, 0.25 + win.p * 6)
        clip: true

        MouseArea { anchors.fill: parent }   // swallow clicks inside the card

        // both menus are built once, up front; the open one is simply revealed
        readonly property real reveal: win.warming ? 1 : win.cOp
        Loader {
            id: netLoader
            width: win.tw; height: parent.height
            asynchronous: true; sourceComponent: netComp
            visible: win.kind === "network" && card.reveal > 0.01
            opacity: card.reveal
            transform: Translate { y: (1 - card.reveal) * 8 }
        }
        Loader {
            id: btLoader
            width: win.tw; height: parent.height
            asynchronous: true; sourceComponent: btComp
            visible: win.kind === "bluetooth" && card.reveal > 0.01
            opacity: card.reveal
            transform: Translate { y: (1 - card.reveal) * 8 }
        }
        Loader {
            id: calLoader
            width: win.tw; height: parent.height
            asynchronous: true; sourceComponent: calComp
            visible: win.kind === "calendar" && card.reveal > 0.01
            opacity: card.reveal
            transform: Translate { y: (1 - card.reveal) * 8 }
        }
        Component { id: calComp
            CalendarPopup {
                active: win.wanted && win.kind === "calendar"; settled: active && win.p > 0.85; shell: win.shell
                onRequestClose: win.shell.closePopup()
            } }
        Loader {
            id: notifLoader
            width: win.tw; height: parent.height
            asynchronous: true; sourceComponent: notifComp
            visible: win.kind === "notifications" && card.reveal > 0.01
            opacity: card.reveal
            transform: Translate { y: (1 - card.reveal) * 8 }
        }
        Component { id: notifComp
            NotificationsPopup {
                active: win.wanted && win.kind === "notifications"; settled: active && win.p > 0.85; shell: win.shell
                onRequestClose: win.shell.closePopup()
            } }
        Loader {
            id: quickLoader
            width: win.tw; height: parent.height
            asynchronous: true; sourceComponent: quickComp
            visible: win.kind === "quick" && card.reveal > 0.01
            opacity: card.reveal
            transform: Translate { y: (1 - card.reveal) * 8 }
        }
        Component { id: quickComp
            QuickPopup {
                active: win.wanted && win.kind === "quick"; settled: active && win.p > 0.85; shell: win.shell
                onRequestMenu: k => win.switchKind(k)
                onRequestClose: win.shell.closePopup()
            } }
        Component { id: netComp; NetworkPopup { active: win.wanted && win.kind === "network"; settled: active && win.p > 0.85 } }
        Component { id: btComp; BluetoothPopup { active: win.wanted && win.kind === "bluetooth"; settled: active && win.p > 0.85 } }
    }

    BackButton {
        x: win.tx + 10; y: win.ty + 9
        visible: win.from !== "" && win.p > 0.9
        opacity: win.cOp
        onClicked: win.goBack()
    }

    // the button's own icon and label ride along and settle into the header
    Row {
        id: morph
        spacing: 4
        readonly property real x0: win.rect.x + (win.rect.w - implicitWidth) / 2
        readonly property real y0: win.rect.y + (win.rect.h - implicitHeight) / 2
        x: win.lerp(x0, win.tx + 18, win.p)
        y: win.lerp(y0, win.ty + 14, win.p)
        visible: win.p > 0.002
        Text {
            visible: win.from === ""
            text: win.glyph
            color: win.p > 0.6 ? main.accent : main.icon
            Behavior on color { ColorAnimation { duration: main.ms(200) } }
            font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: win.lerp(13, 22, win.p) }
        }
        Text {
            text: win.label
            color: main.text
            opacity: Math.max(0, 1 - win.p * 4)
            font { family: main.font; weight: 500 }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
