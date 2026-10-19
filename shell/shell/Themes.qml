// qmllint disable
import Quickshell
import Quickshell.Io
import QtQuick

// Theme data: built-ins from themes.json plus the user's own from custom-themes.json.
// `walls` is the number of bundled images in wallpapers/<id>/ (1.jpg, 2.jpg, ...).
QtObject {
    id: root
    property int rev: 0
    property var builtinFile: FileView { path: Quickshell.shellPath("themes.json"); blockLoading: true }
    property var customFile: FileView {
        path: Quickshell.shellPath("custom-themes.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: { reload(); root.rev++; }
    }
    readonly property var builtin: JSON.parse(builtinFile.text())
    readonly property var custom: {
        root.rev;
        try { return JSON.parse(customFile.text()); } catch (e) { return ({}); }
    }
    readonly property var data: Object.assign({}, builtin, custom)
    readonly property var order: Object.keys(data)
    function reloadCustom() { customFile.reload(); rev++; }
}
