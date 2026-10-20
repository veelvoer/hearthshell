import QtQuick
import Quickshell
import Quickshell.Wayland

// The widgets on the desktop: one small window per widget, between the wallpaper and your apps.
Item {
    id: root
    required property var shell
    visible: false
    readonly property bool on: shell.cfg.homeEnabled && !shell.editor.open
    readonly property var pairs: {
        const out = [];
        if (!shell.cfg.homeEnabled) return out;
        for (const s of shell.screens) for (const w of (shell.cfg.homeWidgets || [])) if (shell.widgetTypes[w.type]) out.push({ "screen": s, "spec": w });
        return out;
    }

    Variants {
        model: root.pairs
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData.screen
            readonly property var spec: modelData.spec
            readonly property var def: root.shell.widgetTypes[spec.type]
            readonly property real k: spec.scale * screen.height / 1080
            // a shadow reaches outside the widget, so the window needs room for it or the shadow is cut off in a square
            readonly property real pad: root.shell.widgetDefs.val(spec, "shadow") ? Math.ceil(46 * k) : 0
            visible: root.on
            color: "transparent"
            anchors { top: true; left: true }
            margins { left: Math.round(spec.x * screen.width) - pad; top: Math.round(spec.y * screen.height) - pad }
            implicitWidth: Math.ceil(def.w * k) + pad * 2; implicitHeight: Math.ceil(def.h * k) + pad * 2
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-widget"
            WlrLayershell.keyboardFocus: spec.type === "note" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            DesktopWidget {
                x: win.pad; y: win.pad; spec: win.spec; shell: root.shell; scale: win.k; transformOrigin: Item.TopLeft
                originX: Math.round(win.spec.x * win.screen.width); originY: Math.round(win.spec.y * win.screen.height)
                screenW: win.screen.width; screenH: win.screen.height
            }
        }
    }
}
