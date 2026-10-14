// qmllint disable
import Quickshell
import QtQuick
import QtQuick.Layouts

Text {
    text: Qt.formatDateTime(clock.date, (cfg.clockDate ? "ddd d MMM  " : "") + (cfg.clock24 ? "hh:mm" : "h:mm") + (cfg.clockSeconds ? ":ss" : "") + (cfg.clock24 ? "" : " AP"))
    color: main.text
    anchors.centerIn: parent

    font {
        family: main.font
        letterSpacing: 0
        pixelSize: main.barPx + 1
        weight: 600
    }
    SystemClock {
        id: clock
        precision: cfg.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
