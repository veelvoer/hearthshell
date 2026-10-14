"""Shared helpers for the Quickshell theme scripts."""
import json
import pathlib
import shutil
from typing import Any

QS = pathlib.Path(__file__).resolve().parent.parent
# ImageMagick 7 ships `magick`; ImageMagick 6 (older Debian/Ubuntu) only has `convert`
IM = "magick" if shutil.which("magick") else "convert"
Theme = dict[str, Any]


def rgb(c: str) -> tuple[int, ...]:
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def mix(a: str, b: str, f: float) -> str:
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * f) for x, y in zip(rgb(a), rgb(b)))


def bare(c: str) -> str:
    return c.lstrip("#")[:6]


def load_themes() -> dict[str, Theme]:
    """Built-in themes plus the user's custom ones (custom-themes.json)."""
    themes: dict[str, Theme] = json.loads((QS / "themes.json").read_text())
    custom = QS / "custom-themes.json"
    if custom.exists():
        try:
            themes.update(json.loads(custom.read_text()))
        except (OSError, ValueError):
            pass
    return themes
