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
    // click for the calendar
    MouseArea {
        anchors.fill: parent; anchors.margins: -2
        cursorShape: Qt.PointingHandCursor
        onClicked: if (bar) bar.openPopup("calendar", root, String.fromCodePoint(0xF00ED), "")
    }
}
