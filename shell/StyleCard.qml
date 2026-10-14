// qmllint disable
import QtQuick

// Bar preset card: a tiny screen with the preset's bar sketched on top.
Item {
    id: card
    property string styleId: "classic"
    property string label: ""
    property bool selected: false
    signal picked()
    implicitWidth: 120; implicitHeight: 92

    Item {
        anchors.fill: parent
        scale: m.pressed ? 0.96 : 1
        y: m.containsMouse ? -2 : 0
        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
        Behavior on y { NumberAnimation { duration: main.ms(180); easing.type: Easing.OutCubic } }

        Rectangle {
            id: frame
            anchors.fill: parent; radius: 14; color: main.page
            border.width: card.selected ? 2 : 1
            border.color: card.selected ? main.accent : (m.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : main.line)
            Behavior on border.color { ColorAnimation { duration: main.ms(180) } }

            Rectangle {   // the "screen"
                x: 8; y: 8; width: parent.width - 16; height: 48; radius: 8; color: Qt.darker(main.bg, 1.3)
                clip: true

                component Dots: Row {
                    spacing: 2
                    property int n: 3
                    Repeater { model: parent.n; Rectangle { width: 4; height: 4; radius: 2; color: main.accent; opacity: 0.9 } }
                }
                component Pill: Rectangle {
                    height: 10; radius: 5; color: main.bg; border.width: 1; border.color: main.line
                }

                // classic: one wide pill
                Pill { visible: card.styleId === "classic"; x: 5; y: 5; width: parent.width - 10
                    Dots { x: 5; anchors.verticalCenter: parent.verticalCenter }
                    Dots { n: 2; anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter } }
                // pill: everything in one small pill
                Pill { visible: card.styleId === "pill"; width: 62; anchors.horizontalCenter: parent.horizontalCenter; y: 5
                    Dots { n: 6; anchors.centerIn: parent } }
                // islands: three pills
                Pill { visible: card.styleId === "islands"; x: 5; y: 5; width: 24; Dots { anchors.centerIn: parent } }
                Pill { visible: card.styleId === "islands"; y: 5; width: 16; anchors.horizontalCenter: parent.horizontalCenter }
                Pill { visible: card.styleId === "islands"; y: 5; width: 20; anchors.right: parent.right; anchors.rightMargin: 5
                    Dots { n: 2; anchors.centerIn: parent } }
                // flat: edge to edge, rounded below
                Rectangle { visible: card.styleId === "flat"; x: 0; y: -6; width: parent.width; height: 18; radius: 7; color: main.bg
                    border.width: 1; border.color: main.line
                    Dots { x: 6; y: 9 } Dots { n: 2; anchors.right: parent.right; anchors.rightMargin: 6; y: 9 } }
                // minimal: no surface at all
                Item { visible: card.styleId === "minimal"; x: 7; y: 6; width: parent.width - 14; height: 6
                    Dots { n: 4 } Dots { n: 2; anchors.right: parent.right } }

                Rectangle { x: 10; y: 24; width: 36; height: 16; radius: 4; color: main.card; opacity: 0.8 }
                Rectangle { x: 52; y: 24; width: 38; height: 16; radius: 4; color: main.card; opacity: 0.55 }
            }
            Text {
                x: 10; y: 64; text: card.label; color: card.selected ? main.accent : main.text
                font { family: main.font; pixelSize: 12; weight: 600 }
            }
        }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.picked() }
}
