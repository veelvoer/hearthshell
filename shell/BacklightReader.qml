// qmllint disable
import Quickshell
import Quickshell.Io
import QtQuick

// Screen brightness straight from sysfs (no program is started, so nothing hitches the bar once a second).
Item {
    id: root
    property bool running: true
    property int interval: 1000
    readonly property bool available: dir !== "" && max > 0
    property int percent: -1
    property string dir: ""
    property int max: 0
    property int raw: -1

    Process {
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && { echo \"$d\"; break; }; done"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.dir = text.trim() }
    }
    FileView {
        id: maxFile
        path: root.dir !== "" ? root.dir + "/max_brightness" : ""
        onLoaded: root.max = parseInt(text().trim()) || 0
    }
    FileView {
        id: curFile
        path: root.dir !== "" ? root.dir + "/brightness" : ""
        onLoaded: {
            const v = parseInt(text().trim());
            if (isNaN(v) || root.max <= 0) return;
            root.raw = v;
            root.percent = Math.round(v * 100 / root.max);
        }
    }
    Timer { interval: root.interval; running: root.running && root.dir !== ""; repeat: true; triggeredOnStart: true; onTriggered: curFile.reload() }
}
