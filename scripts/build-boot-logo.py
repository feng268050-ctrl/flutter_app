#!/usr/bin/env python3
"""Generate U-Boot/kernel boot logos from board/logo/splash_icon.png."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "board/logo/splash_icon.png"
LCD_PARAM = ROOT / "board/960_lcd_param_rk356x.txt"
OUT = ROOT / "board/logo/logo.bmp"
OUT_KERNEL = ROOT / "board/logo/logo_kernel.bmp"

BG_COLOR = (255, 255, 255)


def _read_lcd_param() -> tuple[int, int, int]:
    """Return (lcd0_x, lcd0_y, lcd0_rotation) from board param file."""
    lcd_x, lcd_y, rotation = 800, 1280, 90
    if not LCD_PARAM.is_file():
        return lcd_x, lcd_y, rotation

    for line in LCD_PARAM.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//") or line.startswith("#"):
            continue
        m = re.match(r"lcd0_x\s*=\s*(\d+)", line)
        if m:
            lcd_x = int(m.group(1))
            continue
        m = re.match(r"lcd0_y\s*=\s*(\d+)", line)
        if m:
            lcd_y = int(m.group(1))
            continue
        m = re.match(r"lcd0_rotation\s*=\s*(\d+)", line)
        if m:
            rotation = int(m.group(1))
    return lcd_x, lcd_y, rotation


def _canvas_size(lcd_x: int, lcd_y: int, rotation: int) -> tuple[int, int, bool]:
    """BMP size = MIPI video mode (lcd0_x × lcd0_y). Rotate icon when panel is landscape."""
    rotate_icon = rotation in (90, 270)
    return lcd_x, lcd_y, rotate_icon


def _render_with_pillow(canvas_w: int, canvas_h: int, rotate_icon: bool):
    from PIL import Image

    icon = Image.open(SRC).convert("RGBA")
    icon.thumbnail((canvas_w, canvas_h), Image.Resampling.LANCZOS)
    if rotate_icon:
        icon = icon.rotate(-90, expand=True, resample=Image.Resampling.BICUBIC)
        icon.thumbnail((canvas_w, canvas_h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (canvas_w, canvas_h), BG_COLOR)
    x = (canvas_w - icon.width) // 2
    y = (canvas_h - icon.height) // 2
    canvas.paste(icon, (x, y), icon)
    return canvas


def _render_with_magick(canvas_w: int, canvas_h: int, rotate_icon: bool) -> None:
    tmp = OUT.with_suffix(".magick.bmp")
    rotate_args = ["-rotate", "-90"] if rotate_icon else []
    for cmd in (
        [
            "magick",
            str(SRC),
            "-background",
            "white",
            "-gravity",
            "center",
            "-resize",
            f"{canvas_w}x{canvas_h}>",
            *rotate_args,
            "-resize",
            f"{canvas_w}x{canvas_h}>",
            "-extent",
            f"{canvas_w}x{canvas_h}",
            str(tmp),
        ],
        [
            "convert",
            str(SRC),
            "-background",
            "white",
            "-gravity",
            "center",
            "-resize",
            f"{canvas_w}x{canvas_h}>",
            *rotate_args,
            "-resize",
            f"{canvas_w}x{canvas_h}>",
            "-extent",
            f"{canvas_w}x{canvas_h}",
            str(tmp),
        ],
    ):
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            shutil.move(str(tmp), OUT)
            return
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    raise RuntimeError("ImageMagick (magick/convert) not available")


def _is_up_to_date() -> bool:
    if not (OUT.is_file() and OUT_KERNEL.is_file()):
        return False
    out_mtime = OUT.stat().st_mtime
    script_mtime = Path(__file__).stat().st_mtime
    for dep in (SRC, LCD_PARAM):
        if dep.is_file() and dep.stat().st_mtime > out_mtime:
            return False
    return out_mtime >= script_mtime


def main() -> int:
    if not SRC.is_file():
        print(f"ERROR: missing {SRC}", file=sys.stderr)
        return 1

    lcd_x, lcd_y, rotation = _read_lcd_param()
    canvas_w, canvas_h, rotate_icon = _canvas_size(lcd_x, lcd_y, rotation)

    OUT.parent.mkdir(parents=True, exist_ok=True)

    if _is_up_to_date():
        print(f"boot logo up to date: {OUT} ({canvas_w}x{canvas_h})")
        return 0

    try:
        canvas = _render_with_pillow(canvas_w, canvas_h, rotate_icon)
        # PIL BMP writer emits BGR; manual RGB bytes swap red/blue on the panel.
        canvas.save(OUT, "BMP")
    except ImportError:
        _render_with_magick(canvas_w, canvas_h, rotate_icon)

    shutil.copy2(OUT, OUT_KERNEL)
    print(
        f"boot logo: {OUT} ({canvas_w}x{canvas_h}, "
        f"lcd0={lcd_x}x{lcd_y} rotation={rotation}°)"
    )
    print(f"boot logo: {OUT_KERNEL} (copy)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
