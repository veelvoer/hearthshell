#!/usr/bin/env python3
"""Add a user wallpaper to a theme.

usage: add-wallpaper.py <theme-id> <image> [original|themed]
Prints the new wallpaper number on success.
"""
import pathlib
import subprocess
import sys

from themelib import IM, QS, load_themes
from posterize import posterize


def main() -> None:
    tid, src = sys.argv[1], sys.argv[2]
    mode = sys.argv[3] if len(sys.argv) > 3 else "original"
    themes = load_themes()
    if tid not in themes:
        sys.exit(f"unknown theme: {tid}")
    if not pathlib.Path(src).is_file():
        sys.exit(f"not a file: {src}")
    folder = QS / "wallpapers" / tid
    folder.mkdir(parents=True, exist_ok=True)
    n = 1
    while (folder / f"{n}.jpg").exists():
        n += 1
    dst = str(folder / f"{n}.jpg")
    if mode == "themed":
        posterize(themes[tid], src, dst, "3840")
    else:
        subprocess.run([IM, f"{src}[0]", "-resize", "3840x2160>", "-quality", "90", dst], check=True)
    print(n)


if __name__ == "__main__":
    main()
