// qmllint disable
import QtQuick

// An icon-font glyph centred by its drawn shape (not by its line box, which sits off-centre for most icons).
Item {
    id: root
    property string glyph: ""
    property real size: 14
    property color color: main.text
    anchors.centerIn: parent
    width: size; height: size
    TextMetrics {
        id: tm
        text: root.glyph
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: root.size }
    }
    Text {
        id: t
        text: root.glyph; color: root.color
        font: tm.font
        x: root.width / 2 - (tm.tightBoundingRect.x + tm.tightBoundingRect.width / 2)
        y: root.height / 2 - (tm.tightBoundingRect.y + tm.tightBoundingRect.height / 2) - t.baselineOffset
    }
}
