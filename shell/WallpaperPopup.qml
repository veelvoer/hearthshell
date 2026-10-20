// qmllint disable
import QtQuick
import QtQuick.Effects

// Wallpaper menu: the wallpapers of the current theme, tap one to use it.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    readonly property real wantedHeight: 62 + body.implicitHeight + 14
    readonly property int count: shell ? shell.wallCount(shell.cfg.theme) : 0

    Text { x: 54; y: 15; text: "Wallpaper"; color: main.text; font { family: main.serif; pixelSize: 18 } }

    Flickable {
        x: 12; y: 58; width: parent.width - 24; height: Math.max(0, parent.height - 58 - 12)
        contentWidth: width; contentHeight: body.implicitHeight
        clip: true; boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        Column {
            id: body
            width: parent.width; spacing: 12
            Flow {
                id: thumbs
                width: parent.width; spacing: 10
                Repeater {
                    model: root.count
                    delegate: Item {
                        id: wp
                        required property int index
                        readonly property bool sel: !!root.shell && root.shell.wallIndex === index + 1
                        width: (thumbs.width - 10) / 2; height: width * 9 / 16
                        scale: wm.pressed ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: main.ms(170); easing.type: Easing.OutBack } }
                        Image {
                            id: wimg; anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(400, 225); visible: false; layer.enabled: true
                            source: root.shell ? Qt.resolvedUrl("wallpapers/" + root.shell.cfg.theme + "/" + (wp.index + 1) + ".jpg") : ""
                        }
                        Item { id: wmask; anchors.fill: parent; visible: false; layer.enabled: true
                            Rectangle { anchors.fill: parent; radius: 16 } }
                        MultiEffect {
                            anchors.fill: parent; source: wimg; maskEnabled: true; maskSource: wmask
                            opacity: wimg.status === Image.Ready ? (wp.sel || wm.containsMouse ? 1 : 0.82) : 0
                            Behavior on opacity { NumberAnimation { duration: main.ms(200) } }
                        }
                        Rectangle {
                            anchors.fill: parent; radius: 16; color: "transparent"
                            border.width: wp.sel ? 3 : 1; border.color: wp.sel ? main.accent : main.line
                            Behavior on border.color { ColorAnimation { duration: main.ms(180) } }
                        }
                        MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.shell.setWallpaper(wp.index + 1) }
                    }
                }
            }
            Row {
                spacing: 8
                HButton { label: "Shuffle"; onClicked: root.shell.shuffleWallpaper() }
                HButton { label: "Add your own…"; primary: true; onClicked: root.shell.pickWallpaper(themed.current === 1) }
            }
            Row {
                spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Added images"; color: main.muted; font { family: main.font; pixelSize: 12 } }
                HSegment { id: themed; options: ["Original", "Themed"]; segWidth: 70; current: 0; onPicked: i => current = i }
            }
        }
    }
}
