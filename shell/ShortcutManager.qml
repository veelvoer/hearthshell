import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root
    visible: false
    required property var shell
    property bool capturing: false
    signal conflict(string id, string why)
    signal assigned(string id)

    readonly property string sig: JSON.stringify(shell.cfg.shortcuts || {})
    onSigChanged: debounce.restart()
    Component.onCompleted: { run(["hyprctl", "dispatch", 'hl.dsp.submap("reset")']); debounce.restart(); startup.start(); }
    // Hyprland forgets binds made at runtime whenever its config reloads, and the shell can start before Hyprland is ready
    Connections { target: Hyprland; function onRawEvent(ev) { if (ev.name === "configreloaded") debounce.restart(); } }
    Timer { id: startup; interval: 4000; repeat: true; property int n: 0; function start() { n = 0; running = true; }
        onTriggered: { root.apply(); if (++n >= 3) running = false; } }
    Timer { interval: 30000; repeat: true; running: true; onTriggered: audit.running = true }
    Process {
        id: audit
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const want = Object.keys(root.shell.cfg.shortcuts || {}).length;
                const have = (text.match(/"description": "hearthshell:/g) || []).length;
                if (want !== have) root.apply();
            }
        }
    }
    Timer { id: debounce; interval: 300; onTriggered: root.apply() }

    function run(cmd) { const p = runner.createObject(root, { "command": cmd }); p.running = true; }
    Component { id: runner; Process { onExited: destroy() } }

    function lua(s) { return JSON.stringify(String(s)); }
    function commandFor(a) {
        return "qs -p " + Quickshell.shellPath("shell.qml") + " ipc call shell " + a.fn + (a.arg ? " " + a.arg : "");
    }
    function apply() {
        const map = shell.cfg.shortcuts || {}, prev = shell.cfg.shortcutsApplied || [];
        const keys = [], lines = [];
        for (const a of shell.shortcutActions) if (map[a.id]) keys.push(map[a.id]);
        for (const k of new Set(prev.concat(keys))) lines.push("pcall(hl.unbind, " + lua(k) + ")");
        for (const a of shell.shortcutActions) {
            if (!map[a.id]) continue;
            lines.push("hl.bind(" + lua(map[a.id]) + ", hl.dsp.exec_cmd(" + lua(commandFor(a)) + "), { description = " + lua("hearthshell:" + a.id) + " })");
        }
        if (lines.length > 0) run(["hyprctl", "eval", lines.join("\n")]);
        if (JSON.stringify(prev) !== JSON.stringify(keys)) shell.set("shortcutsApplied", keys);
        // a bind that is already there is replaced, never doubled
    }

    // while a key combination is being recorded, Hyprland's own binds are switched off so the keys reach the settings window
    function beginCapture() {
        if (capturing) return;
        capturing = true;
        run(["hyprctl", "eval", 'hl.define_submap("hs_capture", function() hl.bind("SUPER + F20", hl.dsp.exec_cmd("true")) end)']);
        enterTimer.restart();
        failsafe.restart();
    }
    function endCapture() {
        failsafe.stop(); enterTimer.stop();
        capturing = false;
        run(["hyprctl", "dispatch", 'hl.dsp.submap("reset")']);
    }
    Timer { id: enterTimer; interval: 120; onTriggered: root.run(["hyprctl", "dispatch", 'hl.dsp.submap("hs_capture")']) }
    Timer { id: failsafe; interval: 20000; onTriggered: root.endCapture() }

    // ---- is a combination already taken by something that is not ours?
    property string pendingId: ""
    property string pendingCombo: ""
    function tryAssign(id, combo) {
        pendingId = id; pendingCombo = combo;
        check.running = true;
    }
    function maskOf(parts) {
        let m = 0;
        for (const p of parts) {
            const u = p.toUpperCase();
            if (u === "SHIFT") m |= 1; else if (u === "CTRL" || u === "CONTROL") m |= 4; else if (u === "ALT") m |= 8; else if (u === "SUPER" || u === "WIN" || u === "META") m |= 64;
        }
        return m;
    }
    Process {
        id: check
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = root.pendingCombo.split("+").map(s => s.trim());
                const key = parts[parts.length - 1].toLowerCase(), mask = root.maskOf(parts.slice(0, -1));
                let other = null;
                try {
                    for (const b of JSON.parse(text)) {
                        if ((b.description || "").indexOf("hearthshell:") === 0) continue;
                        if (b.submap && b.submap !== "") continue;
                        if (String(b.key).toLowerCase() === key && b.modmask === mask) { other = b; break; }
                    }
                } catch (e) { }
                if (other) root.conflict(root.pendingId, "Already used by your Hyprland config");
                else {
                    const map = Object.assign({}, root.shell.cfg.shortcuts || {});
                    for (const k in map) if (map[k] === root.pendingCombo && k !== root.pendingId) delete map[k];
                    map[root.pendingId] = root.pendingCombo;
                    root.shell.set("shortcuts", map);
                    root.assigned(root.pendingId);
                }
            }
        }
    }
}
