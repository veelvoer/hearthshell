#!/usr/bin/env python3
"""Extract a theme palette from an image.

usage: palette.py <image>   ->  JSON {bg, text, accent, accent2, muted}
"""
import colorsys
import json
import re
import subprocess
import sys

from themelib import IM, mix, rgb


def hsv(c: str) -> tuple[float, float, float]:
    r, g, b = (v / 255 for v in rgb(c))
    return colorsys.rgb_to_hsv(r, g, b)


def from_hsv(h: float, s: float, v: float) -> str:
    return "#%02x%02x%02x" % tuple(round(x * 255) for x in colorsys.hsv_to_rgb(h, s, v))


def swatches(path: str) -> list[str]:
    out = subprocess.run(
        [IM, f"{path}[0]", "-resize", "120x120!", "-colors", "12", "-unique-colors", "txt:-"],
        check=True, capture_output=True, text=True).stdout
    return re.findall(r"#[0-9A-Fa-f]{6}", out)


def main() -> None:
    cols = [c.lower() for c in swatches(sys.argv[1])]
    by_v = sorted(cols, key=lambda c: hsv(c)[2])
    by_s = sorted(cols, key=lambda c: hsv(c)[1] * (0.4 + hsv(c)[2]), reverse=True)
    h, s, v = hsv(by_v[0])
    bg = from_hsv(h, min(s, 0.45), min(v, 0.2) + 0.06)
    h, s, v = hsv(by_v[-1])
    text = from_hsv(h, min(s, 0.18), max(v, 0.88))
    accent = by_s[0]
    ah, asat, av = hsv(accent)
    accent = from_hsv(ah, max(asat, 0.45), max(av, 0.72))
    second = next((c for c in by_s[1:] if abs(hsv(c)[0] - ah) > 0.06), by_s[min(1, len(by_s) - 1)])
    sh, ssat, sv = hsv(second)
    accent2 = from_hsv(sh, max(ssat, 0.4), max(sv, 0.75))
    print(json.dumps({"bg": bg, "text": text, "accent": accent, "accent2": accent2, "muted": mix(bg, accent, 0.55)}))


if __name__ == "__main__":
    main()
