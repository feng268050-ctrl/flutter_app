#!/usr/bin/env python3
"""Regenerate camera_stop_{orange,green,blue}_icon.webp from gray camera_stop_icon.webp.

Preserves luminance so the play (▶) mark stays visible vs the camera body.
Requires: pip install pillow

Usage (from repo root):
  python3 -m venv .venv-icons && .venv-icons/bin/pip install pillow
  .venv-icons/bin/python3 scripts/generate_camera_stop_colored_icons.py
"""
from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
RES = REPO / "app" / "src" / "main" / "res"
DENSITIES = ("mipmap-xxhdpi", "mipmap-xxxhdpi")
COLORS = {
    "orange": "#F46E01",
    "green": "#37F3D2",
    "blue": "#0151F4",
}


def _hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def colorize_preserve_luminance(src: Path, dst: Path, hex_color: str) -> None:
    tr, tg, tb = _hex_rgb(hex_color)
    th, ts, _ = colorsys.rgb_to_hsv(tr / 255, tg / 255, tb / 255)
    img = Image.open(src).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            nr, ng, nb = colorsys.hsv_to_rgb(th, ts, lum)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    img.save(dst, "WEBP", quality=95)


def main() -> None:
    for density in DENSITIES:
        src = RES / density / "camera_stop_icon.webp"
        if not src.is_file():
            raise SystemExit(f"missing source: {src}")
        for name, color in COLORS.items():
            dst = RES / density / f"camera_stop_{name}_icon.webp"
            colorize_preserve_luminance(src, dst, color)
            print(dst)


if __name__ == "__main__":
    main()
