// qmllint disable
import QtQuick

// Theme menu: every theme as a tile, tap one to switch the whole desktop to it.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    readonly property real wantedWidth: shell ? shell.menuWidth("theme") : 360
    readonly property int cols: shell ? shell.menuOpt("theme", "columns") : 2
    readonly property real wantedHeight: 62 + grid.implicitHeight + 14

    Text { x: 54; y: 15; text: "Theme"; color: main.text; font { family: main.serif; pixelSize: 18 } }

    Flickable {
        x: 12; y: 58; width: parent.width - 24; height: Math.max(0, parent.height - 58 - 12)
        contentWidth: width; contentHeight: grid.implicitHeight
        clip: true; boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        Flow {
            id: grid
            width: parent.width; spacing: 10
            Repeater {
                model: root.shell ? root.shell.themeList.order : []
                ThemeTile {
                    required property string modelData
                    themeId: modelData
                    info: root.shell.themeList.data[modelData]
                    selected: root.shell.cfg.theme === modelData
                    width: (grid.width - 10 * (root.cols - 1)) / root.cols; height: root.cols === 1 ? 120 : 104
                    onPicked: root.shell.setTheme(modelData)
                }
            }
        }
    }
}
