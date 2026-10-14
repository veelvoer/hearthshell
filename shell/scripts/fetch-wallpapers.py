#!/usr/bin/env python3
"""Download the wallpaper sources listed in wallpapers.json and recolour them for each theme.

usage: fetch-wallpapers.py [theme-id ...]   (no argument = every built-in theme)

Nothing is bundled: each image is downloaded from its original repository to a temporary
file, recoloured into the theme's palette (see posterize.py) and written to
wallpapers/<theme>/<n>.jpg. Existing images are kept, so it is safe to run again.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

from posterize import posterize
from themelib import IM, QS, load_themes


def download(url: str, dest: pathlib.Path) -> bool:
    req = urllib.request.Request(url, headers={"User-Agent": "hearthshell-installer"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp, open(dest, "wb") as out:
            out.write(resp.read())
    except OSError as err:
        print(f"    could not download ({err})")
        return False
    return True


def main() -> None:
    manifest = json.loads((QS / "wallpapers.json").read_text())
    themes = load_themes()
    wanted = sys.argv[1:] or list(manifest["themes"])
    failures = 0
    for tid in wanted:
        if tid not in manifest["themes"] or tid not in themes:
            print(f"skipping unknown theme {tid}")
            continue
        folder = QS / "wallpapers" / tid
        folder.mkdir(parents=True, exist_ok=True)
        print(f"{themes[tid]['name']}")
        for i, item in enumerate(manifest["themes"][tid], start=1):
            dst = folder / f"{i}.jpg"
            if dst.exists():
                continue
            url = manifest["bases"][item["source"]] + urllib.parse.quote(item["path"])
            with tempfile.TemporaryDirectory() as tmp:
                raw = pathlib.Path(tmp) / pathlib.Path(item["path"]).name
                print(f"  {i}/4 {item['path']}")
                if not download(url, raw):
                    failures += 1
                    continue
                try:
                    if item["mode"] == "asis":
                        subprocess.run([IM, f"{raw}[0]", "-resize", "3840x2160>", "-quality", "90", str(dst)], check=True)
                    else:
                        posterize(themes[tid], str(raw), str(dst))
                except (OSError, subprocess.CalledProcessError) as err:
                    print(f"    could not convert ({err}); is ImageMagick installed?")
                    failures += 1
    print("done" if not failures else f"done, {failures} image(s) missing (themes fall back to a plain gradient)")


if __name__ == "__main__":
    main()
