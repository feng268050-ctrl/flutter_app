#!/usr/bin/env python3
"""Generate resolution-independent boot logos from board/logo/splash_icon.png.

U-Boot / kernel (resource.img ``logo.bmp``, ``logo_kernel.bmp``): icon-sized
24-bit BMP. Bootloader centers the bitmap on the panel (``splashpos=m,m`` /
Rockchip resource loader); the asset MUST NOT be baked to panel resolution.
The icon is pre-rotated −90° so it reads upright on a landscape-mounted
portrait MIPI panel (DRM scanout has no compositor transform).

Weston desktop-shell: the same icon, **not** pre-rotated (Weston
``transform=rotate-270`` already maps to logical landscape). ``weston.ini``
uses ``background-type=pad`` and black ``background-color`` so the logo
stays centered on any output geometry.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "board/logo/splash_icon.png"
OUT = ROOT / "board/logo/logo.bmp"
OUT_KERNEL = ROOT / "board/logo/logo_kernel.bmp"
OUT_WESTON_PNG = (
    ROOT
    / "overlay/board/rockchip/common/rootfs-overlay/usr/share/hmi/boot-splash.png"
)

BG_COLOR = (0, 0, 0)
ICON_MAX = 512
# Kernel/U-Boot: native portrait scanout, landscape product → pre-rotate.
KERNEL_ROTATE_DEG = -90


def _have_pillow() -> bool:
    try:
        from PIL import Image  # noqa: F401

        return True
    except ImportError:
        return False


def _load_icon_rgba(*, rotate_deg: int = 0):
    from PIL import Image

    icon = Image.open(SRC).convert("RGBA")
    icon.thumbnail((ICON_MAX, ICON_MAX), Image.Resampling.LANCZOS)
    bbox = icon.getbbox()
    if bbox:
        icon = icon.crop(bbox)
    if rotate_deg:
        icon = icon.rotate(rotate_deg, expand=True, resample=Image.Resampling.BICUBIC)
        bbox = icon.getbbox()
        if bbox:
            icon = icon.crop(bbox)
    return icon


def _icon_size_pillow(*, rotate_deg: int = 0) -> tuple[int, int]:
    return _load_icon_rgba(rotate_deg=rotate_deg).size


def _render_bmp_pillow():
    from PIL import Image

    icon = _load_icon_rgba(rotate_deg=KERNEL_ROTATE_DEG)
    canvas = Image.new("RGB", icon.size, BG_COLOR)
    canvas.paste(icon, (0, 0), icon)
    return canvas


def _render_weston_png_pillow():
    """Upright RGBA icon; Weston pads on black background-color."""
    return _load_icon_rgba(rotate_deg=0)


def _magick_cmd() -> str | None:
    from shutil import which

    for name in ("magick", "convert"):
        if which(name):
            return name
    return None


def _image_size(path: Path) -> tuple[int, int] | None:
    if _have_pillow():
        from PIL import Image

        with Image.open(path) as im:
            return im.size
    cmd = _magick_cmd()
    if not cmd:
        return None
    try:
        out = subprocess.run(
            [cmd, "identify", "-format", "%w %h", str(path)],
            check=True,
            capture_output=True,
            text=True,
        )
        w, h = out.stdout.strip().split()
        return int(w), int(h)
    except (FileNotFoundError, subprocess.CalledProcessError, ValueError):
        return None


def _render_bmp_with_magick(out_path: Path) -> None:
    cmd = _magick_cmd()
    if not cmd:
        raise RuntimeError("ImageMagick (magick/convert) not available for BMP")
    tmp = out_path.with_suffix(f".magick{out_path.suffix}")
    subprocess.run(
        [
            cmd,
            str(SRC),
            "-background",
            "black",
            "-alpha",
            "remove",
            "-alpha",
            "off",
            "-resize",
            f"{ICON_MAX}x{ICON_MAX}>",
            "-trim",
            "+repage",
            "-rotate",
            str(KERNEL_ROTATE_DEG),
            "-trim",
            "+repage",
            str(tmp),
        ],
        check=True,
        capture_output=True,
    )
    shutil.move(str(tmp), out_path)


def _render_weston_png_with_magick(out_path: Path) -> None:
    cmd = _magick_cmd()
    if not cmd:
        raise RuntimeError("ImageMagick (magick/convert) not available for PNG")
    tmp = out_path.with_suffix(f".magick{out_path.suffix}")
    subprocess.run(
        [
            cmd,
            str(SRC),
            "-resize",
            f"{ICON_MAX}x{ICON_MAX}>",
            "-trim",
            "+repage",
            str(tmp),
        ],
        check=True,
        capture_output=True,
    )
    shutil.move(str(tmp), out_path)


def _is_up_to_date(bmp_wh: tuple[int, int], png_wh: tuple[int, int]) -> bool:
    if not (OUT.is_file() and OUT_KERNEL.is_file() and OUT_WESTON_PNG.is_file()):
        return False
    if _image_size(OUT) != bmp_wh or _image_size(OUT_WESTON_PNG) != png_wh:
        return False
    out_mtime = OUT.stat().st_mtime
    script_mtime = Path(__file__).stat().st_mtime
    if SRC.is_file() and SRC.stat().st_mtime > out_mtime:
        return False
    if OUT_WESTON_PNG.stat().st_mtime < script_mtime:
        return False
    return out_mtime >= script_mtime


def _render_all() -> tuple[tuple[int, int], tuple[int, int]]:
    if _have_pillow():
        bmp = _render_bmp_pillow()
        bmp.save(OUT, "BMP")
        png = _render_weston_png_pillow()
        OUT_WESTON_PNG.parent.mkdir(parents=True, exist_ok=True)
        png.save(OUT_WESTON_PNG, "PNG")
        return bmp.size, png.size

    _render_bmp_with_magick(OUT)
    try:
        OUT_WESTON_PNG.parent.mkdir(parents=True, exist_ok=True)
        _render_weston_png_with_magick(OUT_WESTON_PNG)
    except RuntimeError as e:
        print(f"WARNING: skip {OUT_WESTON_PNG}: {e}", file=sys.stderr)

    bmp_size = _image_size(OUT)
    png_size = _image_size(OUT_WESTON_PNG) if OUT_WESTON_PNG.is_file() else None
    if bmp_size is None:
        raise RuntimeError("boot logo rendered but size could not be determined")
    return bmp_size, png_size or bmp_size


def main() -> int:
    if not SRC.is_file():
        print(f"ERROR: missing {SRC}", file=sys.stderr)
        return 1

    OUT.parent.mkdir(parents=True, exist_ok=True)

    if _have_pillow():
        bmp_wh = _icon_size_pillow(rotate_deg=KERNEL_ROTATE_DEG)
        png_wh = _icon_size_pillow(rotate_deg=0)
    elif OUT.is_file():
        existing = _image_size(OUT)
        if existing is None:
            print(
                "ERROR: Pillow missing and could not read existing logo size; "
                "install Pillow or ImageMagick",
                file=sys.stderr,
            )
            return 1
        bmp_wh = existing
        png_wh = _image_size(OUT_WESTON_PNG) or existing
    else:
        print(
            "ERROR: Pillow not installed (pip install pillow) and no existing "
            "board/logo/logo.bmp",
            file=sys.stderr,
        )
        return 1

    if _is_up_to_date(bmp_wh, png_wh):
        print(
            f"boot logo up to date: {OUT} ({bmp_wh[0]}x{bmp_wh[1]}); "
            f"Weston {OUT_WESTON_PNG.name} ({png_wh[0]}x{png_wh[1]}, pad on black)"
        )
        return 0

    try:
        bmp_wh, png_wh = _render_all()
    except RuntimeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    shutil.copy2(OUT, OUT_KERNEL)
    print(
        f"boot logo: {OUT} ({bmp_wh[0]}x{bmp_wh[1]}, icon-sized, "
        f"pre-rotate {KERNEL_ROTATE_DEG}°; bootloader centers)"
    )
    print(f"boot logo: {OUT_KERNEL} (copy)")
    if OUT_WESTON_PNG.is_file():
        print(
            f"boot logo: {OUT_WESTON_PNG} "
            f"({png_wh[0]}x{png_wh[1]}, upright, Weston pad + black)"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
