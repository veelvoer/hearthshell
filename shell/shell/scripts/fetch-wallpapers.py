#!/usr/bin/env python3
"""Download the wallpaper sources listed in wallpapers.json and recolour them for each theme.

usage: fetch-wallpapers.py [theme-id ...]   (no argument = every built-in theme)

Nothing is bundled: each image is downloaded from its original repository to a temporary
file, recoloured into the theme's palette (see posterize.py) and written to
wallpapers/<theme>/<n>.jpg. Existing images are kept, so it is safe to run again.
Several images are processed at once.
"""
import concurrent.futures
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import threading
import urllib.parse
import urllib.request
from typing import Any

from posterize import posterize
from themelib import IM, QS, load_themes

LOCK = threading.Lock()


def say(msg: str) -> None:
    with LOCK:
        print(msg, flush=True)


def download(url: str, dest: pathlib.Path) -> bool:
    req = urllib.request.Request(url, headers={"User-Agent": "hearthshell-installer"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp, open(dest, "wb") as out:
                out.write(resp.read())
            return True
        except OSError as err:
            if attempt == 2:
                say(f"    could not download {url.rsplit('/', 1)[-1]} ({err})")
    return False


def fetch_one(job: dict[str, Any]) -> bool:
    """Download one source image and write the recoloured wallpaper. Returns success."""
    item, dst, theme = job["item"], job["dst"], job["theme"]
    url = job["base"] + urllib.parse.quote(item["path"])
    with tempfile.TemporaryDirectory() as tmp:
        raw = pathlib.Path(tmp) / pathlib.Path(item["path"]).name
        if not download(url, raw):
            return False
        try:
            if item["mode"] == "asis":
                subprocess.run([IM, f"{raw}[0]", "-resize", "3840x2160>", "-quality", "90", str(dst)],
                               check=True, capture_output=True)
            else:
                posterize(theme, str(raw), str(dst))
        except (OSError, subprocess.CalledProcessError):
            say(f"    could not convert {raw.name}; is ImageMagick installed?")
            return False
    return True


def main() -> None:
    manifest = json.loads((QS / "wallpapers.json").read_text())
    themes = load_themes()
    wanted = sys.argv[1:] or list(manifest["themes"])
    jobs: list[dict[str, Any]] = []
    for tid in wanted:
        if tid not in manifest["themes"] or tid not in themes:
            say(f"skipping unknown theme {tid}")
            continue
        folder = QS / "wallpapers" / tid
        folder.mkdir(parents=True, exist_ok=True)
        for i, item in enumerate(manifest["themes"][tid], start=1):
            dst = folder / f"{i}.jpg"
            if not dst.exists():
                jobs.append({"item": item, "dst": dst, "theme": themes[tid], "tid": tid, "n": i,
                             "base": manifest["bases"][item["source"]]})
    if not jobs:
        say("all wallpapers are already there")
        return
    workers = max(1, min(4, os.cpu_count() or 1))
    say(f"preparing {len(jobs)} wallpaper(s) with {workers} workers ...")
    failures = 0
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(fetch_one, j): j for j in jobs}
        for fut in concurrent.futures.as_completed(futures):
            j = futures[fut]
            done += 1
            ok = fut.result()
            failures += 0 if ok else 1
            say(f"  [{done}/{len(jobs)}] {themes[j['tid']]['name']} #{j['n']}  {'ok' if ok else 'FAILED'}")
    say("done" if not failures else f"done, {failures} image(s) missing (themes fall back to a plain gradient)")


if __name__ == "__main__":
    main()
