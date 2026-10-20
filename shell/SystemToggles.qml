import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    property int nightLevel: 2
    property bool nightOn: false
    property bool gameOn: false
    property bool airplaneOn: false
    property bool caffeineOn: false
    property int watchers: 0
    signal reloaded()

    function watch(on) { watchers = Math.max(0, watchers + (on ? 1 : -1)); }

    function nightExpr(on) {
        return 'hl.config({decoration={screen_shader="' + (on ? Quickshell.shellPath("shaders/night-" + nightLevel + ".frag") : "") + '"}})';
    }
    function applyNight() { run(["hyprctl", "eval", nightExpr(nightOn)]); }
    function toggleNight() { nightOn = !nightOn; applyNight(); }
    onNightLevelChanged: if (nightOn) applyNight()

    function toggleGame() {
        if (gameOn) {
            gameOn = false;
            run(["hyprctl", "reload"]);
            restoreNight.restart();
        } else {
            gameOn = true;
            run(["hyprctl", "eval", 'hl.config({animations={enabled=false},decoration={blur={enabled=false},shadow={enabled=false},rounding=0},general={gaps_in=0,gaps_out=0}})']);
        }
    }
    function toggleAirplane() {
        airplaneOn = !airplaneOn;
        run(["rfkill", airplaneOn ? "block" : "unblock", "all"]);
    }
    function toggleCaffeine() {
        caffeineOn = !caffeineOn;
        run(["sh", "-c", caffeineOn
            ? "setsid -f systemd-inhibit --what=idle:sleep --who=hearthshell --why=hearth-caffeine sleep infinity >/dev/null 2>&1"
            : "pkill -f '[w]hy=hearth-caffeine'"]);
    }
    function screenshot() {
        run(["sh", "-c", "sleep 0.5; g=$(slurp) && grim -g \"$g\" - | wl-copy && notify-send -a Screenshot 'Copied to clipboard' 2>/dev/null; true"]);
    }
    function run(cmd) { runner.command = cmd; runner.running = false; runner.running = true; }

    Process { id: runner }
    Timer { id: restoreNight; interval: 900; onTriggered: { if (root.nightOn) root.applyNight(); root.reloaded(); } }

    Process {
        id: poll
        command: ["sh", "-c", "n=$(hyprctl getoption decoration:screen_shader -j 2>/dev/null | grep -c '/night-'); a=$(hyprctl getoption animations:enabled -j 2>/dev/null | grep -c '\"bool\": false'); y=$(rfkill list 2>/dev/null | grep -c 'Soft blocked: yes'); z=$(rfkill list 2>/dev/null | grep -c 'Soft blocked: no'); c=$(pgrep -fc '[w]hy=hearth-caffeine'); echo \"$n $a $y $z $c\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number);
                if (p.length < 5 || p.some(isNaN)) return;
                root.nightOn = p[0] > 0;
                root.gameOn = p[1] > 0;
                root.airplaneOn = p[2] > 0 && p[3] === 0;
                root.caffeineOn = p[4] > 0;
            }
        }
    }
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.watchers > 0
        onTriggered: poll.running = true
    }
}
