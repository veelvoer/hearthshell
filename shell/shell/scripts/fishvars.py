#!/usr/bin/env python3
"""Back up and restore the fish universal variables hearthshell overwrites.

usage: fishvars.py backup <name>... | restore

`backup` records the current value (or "unset") of each variable the first time it
runs; `restore` puts every recorded variable back exactly as it was. Used by
apply-theme.py (backup) and uninstall.sh (restore).
"""
import json
import os
import pathlib
import shlex
import subprocess
import sys

STATE = pathlib.Path(os.environ.get("XDG_STATE_HOME") or pathlib.Path.home() / ".local" / "state") / "hearthshell"
BACKUP = STATE / "fish-vars.json"
SEP = "\x1f"


def fish(script: str) -> str:
    try:
        out = subprocess.run(["fish", "-c", script], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout


def backup(names: list[str]) -> None:
    """Record the original values once; later runs never overwrite the backup."""
    if BACKUP.exists():
        return
    saved: dict[str, list[str] | None] = {n: None for n in names}
    for n in names:
        out = fish(f"if set -q -U {n}; printf 'SET\\t'; string join \\x1f -- ${n}; end")
        line = out.rstrip("\n")
        if line.startswith("SET\t"):
            body = line[4:]
            saved[n] = body.split(SEP) if body != "" else []
    STATE.mkdir(parents=True, exist_ok=True)
    BACKUP.write_text(json.dumps(saved, indent=2))


def restore() -> None:
    if not BACKUP.exists():
        return
    saved: dict[str, list[str] | None] = json.loads(BACKUP.read_text())
    cmds = []
    for name, vals in saved.items():
        if vals is None:
            cmds.append(f"set -e -U {name}")
        else:
            cmds.append(f"set -U {name} " + " ".join(shlex.quote(v) for v in vals))
    fish("; ".join(cmds))
    BACKUP.unlink()


def main() -> None:
    if len(sys.argv) >= 2 and sys.argv[1] == "restore":
        restore()
    elif len(sys.argv) >= 3 and sys.argv[1] == "backup":
        backup(sys.argv[2:])
    else:
        sys.exit("usage: fishvars.py backup <name>... | restore")


if __name__ == "__main__":
    main()
