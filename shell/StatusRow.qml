import QtQuick

Item {
    id: row
    property string glyph: ""
    property string text1: ""
    property string text2: ""
    property bool dim: false
    height: 16

    Text {
        width: 18; anchors.verticalCenter: parent.verticalCenter
        text: row.glyph; color: row.dim ? main.muted : main.accent
        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 13 }
    }
    Text {
        id: t1
        x: 24; anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, row.width - 24)
        elide: Text.ElideRight; text: row.text1
        color: row.dim ? main.muted : main.text; font { family: main.font; pixelSize: 11; weight: 700 }
    }
    Text {
        x: t1.x + t1.width + 6; anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, row.width - x); elide: Text.ElideRight
        text: row.text2; color: main.muted; font { family: main.font; pixelSize: 10 }
    }
}
