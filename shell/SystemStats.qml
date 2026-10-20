import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    property real cpu: 0
    property real mem: 0
    property real temp: 0
    property real disk: 0
    property var last: null
    property int watchers: 0
    function watch(on) { watchers = Math.max(0, watchers + (on ? 1 : -1)); }

    Process {
        id: read
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1; df -P / | tail -1 | awk '{print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 3) return;
                const c = l[0].trim().split(/\s+/).slice(1).map(Number);
                const total = c.reduce((x, y) => x + y, 0), idle = c[3] + (c[4] || 0);
                if (root.last && total > root.last.total) root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.last.idle) / (total - root.last.total)));
                root.last = { "total": total, "idle": idle };
                const mt = Number(l[1].replace(/\D/g, "")), ma = Number(l[2].replace(/\D/g, ""));
                if (mt > 0) root.mem = 1 - ma / mt;
                const tl = l.slice(3).find(x => /^\d+$/.test(x.trim())), dl = l.slice(3).find(x => /%$/.test(x.trim()));
                root.temp = tl ? Number(tl) / 1000 : 0;
                root.disk = dl ? Number(dl.replace("%", "")) / 100 : 0;
            }
        }
    }
    Timer { interval: 1500; repeat: true; triggeredOnStart: true; running: root.watchers > 0; onTriggered: read.running = true }
}
