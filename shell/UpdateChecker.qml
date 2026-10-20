import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    property string repo: "veelvoer/hearthshell"
    property string phase: "idle"       // idle | checking | current | available | updating | updated | restored | error
    property string installed: ""
    property string latest: ""
    property var commits: []            // newest first: { sha, msg, date }
    property int behind: 0              // -1 = installed version unknown
    property string message: ""
    property real checkedAt: 0
    readonly property bool busy: phase === "checking" || phase === "updating"
    readonly property string script: Quickshell.shellPath("scripts/update.sh")

    function short(sha) { return sha && sha.length >= 7 ? sha.slice(0, 7) : (sha || ""); }
    function ago(iso) {
        const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min ago";
        if (s < 86400) return Math.round(s / 3600) + " h ago";
        const d = Math.round(s / 86400);
        return d + (d === 1 ? " day ago" : " days ago");
    }
    function fail(text) { message = text; phase = "error"; }

    function check() {
        if (busy) return;
        phase = "checking"; message = "";
        version.reload();
        fetch.running = true;
    }
    function checkIfStale() { if (!busy && Date.now() - checkedAt > 600000) check(); }
    function update() {
        if (busy) return;
        phase = "updating"; message = "";
        run.command = ["sh", root.script];
        run.running = true;
    }
    function restore() {
        if (busy) return;
        phase = "updating"; message = "";
        run.command = ["sh", root.script, "--restore"];
        run.running = true;
    }

    FileView {
        id: version
        path: Quickshell.shellPath(".version")
        printErrors: false
        onLoaded: root.installed = text().trim()
        onLoadFailed: root.installed = ""
    }
    Process {
        id: fetch
        command: ["curl", "-fsS", "-m", "15", "-H", "Accept: application/vnd.github+json",
                  "https://api.github.com/repos/" + root.repo + "/commits?per_page=30"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d;
                try { d = JSON.parse(text); } catch (e) { root.fail("Could not reach GitHub. Check your internet connection."); return; }
                if (!Array.isArray(d)) { root.fail(d && d.message ? d.message : "GitHub sent an unexpected answer."); return; }
                root.commits = d.map(c => ({ "sha": c.sha, "msg": c.commit.message.split("\n")[0], "date": c.commit.author.date }));
                root.latest = root.commits.length > 0 ? root.commits[0].sha : "";
                const i = root.commits.findIndex(c => c.sha === root.installed);
                root.behind = root.installed === "" ? -1 : (i < 0 ? root.commits.length : i);
                root.checkedAt = Date.now();
                root.phase = root.behind === 0 ? "current" : "available";
            }
        }
    }
    Process {
        id: run
        stdout: StdioCollector { id: runOut }
        stderr: StdioCollector { id: runErr }
        onExited: code => {
            version.reload();
            if (code === 0) {
                root.phase = command.indexOf("--restore") >= 0 ? "restored" : "updated";
                root.message = runOut.text.trim().split("\n").pop();
                root.checkedAt = 0;
            } else root.fail((runErr.text.trim().split("\n").pop()) || "The update did not finish.");
        }
    }
}
