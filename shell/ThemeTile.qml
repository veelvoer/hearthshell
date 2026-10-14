// qmllint disable
import QtQuick
import QtQuick.Effects

// Theme picker tile: wallpaper preview + swatches.
Item {
    id: tile
    property string themeId: ""
    property var info: ({})
    property bool selected: false
    signal picked()
    implicitWidth: 150; implicitHeight: 118

    Item {
        id: lift
        anchors.fill: parent
        y: mouse.containsMouse ? -2 : 0
        scale: mouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
        Behavior on y { NumberAnimation { duration: main.ms(180); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }

        Rectangle {
            id: frame
            anchors.fill: parent; radius: 14; color: tile.info.bg || "#222"
            border.width: tile.selected ? 2 : 1
            border.color: tile.selected ? tile.info.wsa : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : main.line)
            Behavior on border.color { ColorAnimation { duration: main.ms(180) } }

            Item {
                id: thumbBox
                x: 5; y: 5; width: parent.width - 10; height: 68
                Image {
                    id: img; anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(320, 180)
                    source: Qt.resolvedUrl("wallpapers/" + tile.themeId + "/1.jpg")
                    visible: false; layer.enabled: true
                }
                Item {
                    id: maskItem; anchors.fill: parent; visible: false; layer.enabled: true
                    Rectangle { anchors.fill: parent; radius: 10 }
                }
                MultiEffect {
                    anchors.fill: parent; source: img
                    maskEnabled: true; maskSource: maskItem
                    opacity: img.status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: main.ms(300) } }
                }
            }
            Text {
                x: 10; y: 78; text: tile.info.name || ""; color: tile.info.text
                font { family: main.serif; pixelSize: 14 }
            }
            Rectangle {
                visible: !!tile.info.custom
                x: 10; y: 11; height: 16; width: tag.implicitWidth + 12; radius: 8; color: Qt.rgba(0, 0, 0, 0.55)
                Text { id: tag; anchors.centerIn: parent; text: "CUSTOM"; color: "white"
                    font { family: main.font; pixelSize: 9; weight: 700; letterSpacing: 0.8 } }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 10; y: 82; spacing: 4
                Repeater {
                    model: [tile.info.wsa, tile.info.icon, tile.info.wsti]
                    Rectangle { width: 9; height: 9; radius: 4.5; color: modelData }
                }
            }
            Rectangle {
                visible: opacity > 0; opacity: tile.selected ? 1 : 0
                width: 20; height: 20; radius: 10; x: parent.width - 28; y: 10
                color: tile.info.wsa
                Behavior on opacity { NumberAnimation { duration: main.ms(200) } }
                Text { anchors.centerIn: parent; text: "✓"; color: tile.info.bg; font { pixelSize: 12; bold: true } }
            }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.picked() }
}
