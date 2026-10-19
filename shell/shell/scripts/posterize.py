#!/usr/bin/env python3
"""Posterize a photo to a theme palette (flat, muted, moody wallpapers).

usage: posterize.py <theme-id> <input> <output.jpg> [width]
"""
import pathlib
import subprocess
import sys
import tempfile

from themelib import IM, Theme, load_themes, mix


def ramp(t: Theme) -> list[str]:
    """Dark-to-light tonal ramp: deep dim background up to a soft accent-tinted highlight."""
    bg, fg, acc = t["bg"], t["text"], t["wsa"]
    dim = mix(bg, "#000000", 0.4)
    return [dim, mix(dim, bg, 0.6), bg, mix(bg, acc, 0.3), mix(bg, acc, 0.62), mix(acc, fg, 0.5), fg]


def posterize(t: Theme, src: str, dst: str, width: str = "2560") -> None:
    with tempfile.TemporaryDirectory() as tmp:
        clut = pathlib.Path(tmp) / "clut.png"
        cmd = [IM] + [f"xc:{c}" for c in ramp(t)]
        subprocess.run(cmd + ["+append", "-filter", "triangle", "-resize", "256x1!", str(clut)], check=True)
        # luminance -> tonal ramp, posterized to flat bands, with a trace of the photo's own colour
        subprocess.run([
            IM, src, "-resize", f"{width}x", "-modulate", "92,100",
            "(", "+clone", "-colorspace", "gray", "-contrast-stretch", "1%x0.5%", "-posterize", "9",
            "-colorspace", "sRGB", "-type", "TrueColor", str(clut), "-clut", ")",
            "(", "-clone", "0", "-posterize", "5", ")",
            "-delete", "0", "-compose", "blend", "-define", "compose:args=18", "-composite",
            "-quality", "90", dst,
        ], check=True)


def main() -> None:
    tid, src, dst = sys.argv[1:4]
    width = sys.argv[4] if len(sys.argv) > 4 else "2560"
    posterize(load_themes()[tid], src, dst, width)


if __name__ == "__main__":
    main()
