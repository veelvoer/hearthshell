import QtQuick
import QtQuick.Layouts

// A stack of MenuSection blocks, in the order chosen in Settings > Menus (each section places itself by row number).
GridLayout {
    property var shell: null
    property string menu: ""
    columns: 1
    rowSpacing: spacing
    property real spacing: 8
}
