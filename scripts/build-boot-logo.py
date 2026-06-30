#!/usr/bin/env python3
"""Generate U-Boot/kernel boot logos from board/logo/splash_icon.png."""

from __future__ import annotations

import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "board/logo/splash_icon.png"
OUT = ROOT / "board/logo/logo.bmp"
OUT_KERNEL = ROOT / "board/logo/logo_kernel.bmp"

# ynh960 MIPI native timing (portrait); logo centered on black canvas.
CANVAS_W = 800
CANVAS_H = 1280
ICON_SCALE = 0.55


def _png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"not a PNG: {path}")
        f.read(4)  # length
        if f.read(4) != b"IHDR":
            raise ValueError(f"PNG missing IHDR: {path}")
        w, h = struct.unpack(">II", f.read(8))
        return w, h


def _write_bmp(path: Path, pixels: bytes, width: int, height: int) -> None:
    row_bytes = width * 3
    pad = (4 - (row_bytes % 4)) % 4
    stride = row_bytes + pad
    pixel_data = b"".join(
        pixels[y * width * 3 : (y + 1) * width * 3] + b"\x00" * pad
        for y in range(height - 1, -1, -1)
    )
    header = struct.pack(
        "<2sIHHI",
        b"BM",
        14 + 40 + len(pixel_data),
        0,
        0,
        14 + 40,
    )
    dib = struct.pack(
        "<IIIHHIIIIII",
        40,
        width,
        height,
        1,
        24,
        0,
        len(pixel_data),
        0,
        0,
        0,
        0,
    )
    path.write_bytes(header + dib + pixel_data)


def _render_with_pillow() -> bytes:
    from PIL import Image

    icon = Image.open(SRC).convert("RGBA")
    target = int(min(CANVAS_W, CANVAS_H) * ICON_SCALE)
    icon.thumbnail((target, target), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (CANVAS_W, CANVAS_H), (0, 0, 0))
    x = (CANVAS_W - icon.width) // 2
    y = (CANVAS_H - icon.height) // 2
    canvas.paste(icon, (x, y), icon)
    return canvas.tobytes()


def _render_with_magick() -> bytes:
    tmp = OUT.with_suffix(".magick.bmp")
    for cmd in (
        [
            "magick",
            str(SRC),
            "-background",
            "black",
            "-gravity",
            "center",
            "-resize",
            f"{int(min(CANVAS_W, CANVAS_H) * ICON_SCALE)}x"
            f"{int(min(CANVAS_W, CANVAS_H) * ICON_SCALE)}>",
            "-extent",
            f"{CANVAS_W}x{CANVAS_H}",
            str(tmp),
        ],
        [
            "convert",
            str(SRC),
            "-background",
            "black",
            "-gravity",
            "center",
            "-resize",
            f"{int(min(CANVAS_W, CANVAS_H) * ICON_SCALE)}x"
            f"{int(min(CANVAS_W, CANVAS_H) * ICON_SCALE)}>",
            "-extent",
            f"{CANVAS_W}x{CANVAS_H}",
            str(tmp),
        ],
    ):
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            data = tmp.read_bytes()
            tmp.unlink(missing_ok=True)
            if len(data) < 54:
                raise RuntimeError("magick produced empty BMP")
            return data
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    raise RuntimeError("ImageMagick (magick/convert) not available")


def main() -> int:
    if not SRC.is_file():
        print(f"ERROR: missing {SRC}", file=sys.stderr)
        return 1

    OUT.parent.mkdir(parents=True, exist_ok=True)

    if (
        OUT.is_file()
        and OUT_KERNEL.is_file()
        and OUT.stat().st_mtime >= SRC.stat().st_mtime
    ):
        print(f"boot logo up to date: {OUT}")
        return 0

    try:
        pixels = _render_with_pillow()
        _write_bmp(OUT, pixels, CANVAS_W, CANVAS_H)
    except ImportError:
        bmp = _render_with_magick()
        OUT.write_bytes(bmp)

    shutil.copy2(OUT, OUT_KERNEL)
    print(f"boot logo: {OUT} ({CANVAS_W}x{CANVAS_H})")
    print(f"boot logo: {OUT_KERNEL} (copy)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
