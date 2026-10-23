import QtQuick
import QtQuick.Layouts

// One block of a menu (for example "Outputs" in the Sound menu). The user can hide it and move it in Settings > Menus.
Item {
    id: root
    property var shell: null
    property string menu: ""
    property string section: ""
    property bool want: true                  // the menu itself has a reason to show it (a device exists, a list is not empty...)
    property real spacing: 8
    default property alias content: inner.data
    readonly property bool shown: want && (!shell || shell.menuSectionOn(menu, section))
    visible: shown
    Layout.fillWidth: true
    Layout.row: shell ? Math.max(0, shell.menuOrder(menu).indexOf(section)) : -1
    Layout.preferredHeight: shown ? inner.implicitHeight : 0
    implicitHeight: shown ? inner.implicitHeight : 0
    Column { id: inner; width: parent.width; spacing: root.spacing }
}
