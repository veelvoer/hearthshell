// qmllint disable
import QtQuick
import QtQuick.Layouts

// One zone of the bar (left, centre or right): loads the chosen modules in order.
RowLayout {
    id: zone
    required property var bar          // the Bar window
    property string name: ""
    property var ids: []
    spacing: bar.shell.cfg.modSpacing

    Repeater {
        model: zone.ids
        Loader {
            id: ld
            required property string modelData
            source: zone.bar.shell.moduleFile(modelData)
            visible: status === Loader.Ready && !!item && item.available !== false
            Layout.alignment: Qt.AlignVCenter
            readonly property bool bare: modelData === "workspaces" || modelData === "clock"
            Layout.leftMargin: bare ? 5 : 0
            Layout.rightMargin: bare ? 5 : 0
            onLoaded: {
                item.bar = zone.bar;
                item.zone = zone.name;
                if (modelData === "clock") zone.bar.clockItem = item;
            }
            Component.onDestruction: if (modelData === "clock" && zone.bar.clockItem === item) zone.bar.clockItem = null
        }
    }
}
