import QtQuick

// One block of a menu (for example "Outputs" in the Sound menu). The user can hide it and move it in Settings > Menus.
Item {
    id: root
    property var shell: null
    property string menu: ""
    property string section: ""
    property bool want: true                  // the menu itself has a reason to show it (a device exists, a list is not empty...)
    property real spacing: 8
    property real inset: 0
    default property alias content: inner.data
    readonly property bool shown: want && (!shell || shell.menuSectionOn(menu, section))
    visible: shown
    width: parent ? parent.width : 0
    implicitHeight: shown ? inner.implicitHeight : 0
    height: implicitHeight
    onHeightChanged: relay()
    onVisibleChanged: relay()
    onSectionChanged: relay()
    Component.onCompleted: relay()
    function relay() { if (parent && parent.relayout) parent.relayout(); }
    Column { id: inner; x: root.inset; width: parent.width - root.inset * 2; spacing: root.spacing }
}
