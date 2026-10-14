#!/usr/bin/env python3
"""Create or delete a custom theme.

usage: custom-theme.py save <json> | delete <id>
  save json: {name, bg, text, accent, accent2, muted, wallpaper?}
Prints the theme id. A first wallpaper is made by posterizing `wallpaper` (when given).
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys

from themelib import QS, Theme, load_themes, mix
from posterize import posterize

CUSTOM = QS / "custom-themes.json"
SOFT = ["#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092"]


def read_custom() -> dict[str, Theme]:
    try:
        return json.loads(CUSTOM.read_text())
    except (OSError, ValueError):
        return {}


def build(spec: dict) -> Theme:
    bg, text, acc, acc2, muted = (spec[k] for k in ("bg", "text", "accent", "accent2", "muted"))
    names = ["red", "green", "yellow", "blue", "magenta", "cyan"]
    return {
        "name": spec["name"], "blurb": "Custom theme", "custom": True, "walls": 0,
        "grad": [acc.lstrip("#"), acc2.lstrip("#"), mix(acc, acc2, 0.5).lstrip("#")],
        "bg": bg, "border": acc + "7f", "text": text, "wsa": acc, "wso": muted,
        "wsi": mix(bg, text, 0.1), "wst": bg, "wsti": mix(text, bg, 0.25), "icon": acc2,
        "term": {n: mix(c, acc, 0.1) for n, c in zip(names, SOFT)},
    }


def save(spec: dict) -> str:
    name = spec["name"].strip() or "Custom"
    spec["name"] = name
    tid = "custom-" + (re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "theme")
    theme = build(spec)
    store = read_custom()
    store[tid] = theme
    folder = QS / "wallpapers" / tid
    folder.mkdir(parents=True, exist_ok=True)
    wall = spec.get("wallpaper")
    if wall and pathlib.Path(wall).is_file() and not (folder / "1.jpg").exists():
        merged = {**load_themes(), tid: theme}
        posterize(merged[tid], wall, str(folder / "1.jpg"))
        theme["walls"] = 1
    elif (folder / "1.jpg").exists():
        theme["walls"] = 1
    CUSTOM.write_text(json.dumps(store, indent=2))
    return tid


def delete(tid: str) -> None:
    store = read_custom()
    if tid in store:
        del store[tid]
        CUSTOM.write_text(json.dumps(store, indent=2))
        shutil.rmtree(QS / "wallpapers" / tid, ignore_errors=True)


def main() -> None:
    cmd = sys.argv[1]
    if cmd == "save":
        print(save(json.loads(sys.argv[2])))
    elif cmd == "delete":
        delete(sys.argv[2])
    else:
        sys.exit("usage: custom-theme.py save <json> | delete <id>")


if __name__ == "__main__":
    main()
