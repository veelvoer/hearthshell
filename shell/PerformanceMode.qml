import QtQuick
import Quickshell

Rectangle {
    id: root
    property var shell: null
    width: 100
    height: 40
    color: "transparent"

    readonly property var modes: [
        {
            id: "eco",
            label: "Eco",
            cpu: 1400,
            gpu: 300
        },
        {
            id: "normal",
            label: "Normal",
            cpu: 2400,
            gpu: 600
        },
        {
            id: "performance",
            label: "Perf",
            cpu: 3600,
            gpu: 1000
        }
    ]

    property string currentMode: shell?.cfg?.performanceMode || "normal"

    Row {
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.modes
            Rectangle {
                width: 28
                height: 28
                radius: 6
                color: root.currentMode === modelData.id ? "#2196F3" : "#424242"
                border.color: root.currentMode === modelData.id ? "#64B5F6" : "transparent"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: "#fff"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.shell.set("performanceMode", modelData.id);
                        root.applyMode(modelData);
                    }
                }
            }
        }
    }

    function applyMode(mode) {
        const cmd = `echo "${mode.cpu}" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || true`;
        const proc = Qt.createQmlObject('import Quickshell; Process { }', root);
        proc.command = ["sh", "-c", cmd];
        proc.running = true;
    }
}
