// qmllint disable
import QtQuick

// The bar clock. Fixed width in the centre zone (the lock-screen morph lands on it).
Item {
    id: root
    property var bar: null
    property string zone: ""
    width: zone === "center" && !cfg.clockDate ? 100 : face.implicitWidth + 4
    height: main.barPx + 11
    opacity: bar && bar.shell.holdBar ? 0 : 1
    Clock { id: face; anchors.centerIn: parent }
}
