#!/usr/bin/env python3
"""Generate U-Boot/kernel boot logos and Weston desktop-shell splash.

Kernel FIT logos (logo.bmp) stay on the MIPI native canvas (lcd0_x × lcd0_y)
with the icon pre-rotated so they look upright when DRM scans out without a
compositor transform.

Weston uses the same physical mode plus transform=rotate-270 (landscape
logical 1280×800). desktop-shell paints background-image in that logical
space — so boot-splash.png must be landscape with an upright icon, not a
copy of logo.bmp (which would look sideways after Weston's transform).
"""

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
# Logical landscape for Weston desktop-shell (see weston.ini transform).
OUT_WESTON_PNG = (
    ROOT
    / "overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/share/hmi/boot-splash.png"
)

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


def _kernel_canvas(lcd_x: int, lcd_y: int, rotation: int) -> tuple[int, int, bool]:
    """BMP size = MIPI video mode. Rotate icon when panel is used landscape."""
    rotate_icon = rotation in (90, 270)
    return lcd_x, lcd_y, rotate_icon


def _weston_canvas(lcd_x: int, lcd_y: int, rotation: int) -> tuple[int, int]:
    """Logical size after Weston's output transform (rotate-270 → swap)."""
    if rotation in (90, 270):
        return lcd_y, lcd_x  # 1280×800 landscape
    return lcd_x, lcd_y


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


def _render_with_magick(
    out_path: Path, canvas_w: int, canvas_h: int, rotate_icon: bool, fmt: str
) -> None:
    tmp = out_path.with_suffix(f".magick{out_path.suffix}")
    rotate_args = ["-rotate", "-90"] if rotate_icon else []
    for cmd_name in ("magick", "convert"):
        cmd = [
            cmd_name,
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
        ]
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            shutil.move(str(tmp), out_path)
            return
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    raise RuntimeError(f"ImageMagick (magick/convert) not available for {fmt}")


def _is_up_to_date(weston_w: int, weston_h: int) -> bool:
    if not (OUT.is_file() and OUT_KERNEL.is_file() and OUT_WESTON_PNG.is_file()):
        return False
    # Force regenerate when Weston PNG geometry is still the old portrait copy.
    try:
        from PIL import Image

        with Image.open(OUT_WESTON_PNG) as im:
            if im.size != (weston_w, weston_h):
                return False
    except Exception:
        # No Pillow / unreadable — fall through to mtime checks; still regenerate
        # if script is newer.
        pass
    out_mtime = OUT.stat().st_mtime
    script_mtime = Path(__file__).stat().st_mtime
    for dep in (SRC, LCD_PARAM):
        if dep.is_file() and dep.stat().st_mtime > out_mtime:
            return False
    if OUT_WESTON_PNG.stat().st_mtime < out_mtime:
        return False
    if OUT_WESTON_PNG.stat().st_mtime < script_mtime:
        return False
    return out_mtime >= script_mtime


def _write_weston_png(canvas) -> None:
    OUT_WESTON_PNG.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT_WESTON_PNG, "PNG")


def main() -> int:
    if not SRC.is_file():
        print(f"ERROR: missing {SRC}", file=sys.stderr)
        return 1

    lcd_x, lcd_y, rotation = _read_lcd_param()
    kernel_w, kernel_h, rotate_icon = _kernel_canvas(lcd_x, lcd_y, rotation)
    weston_w, weston_h = _weston_canvas(lcd_x, lcd_y, rotation)

    OUT.parent.mkdir(parents=True, exist_ok=True)

    if _is_up_to_date(weston_w, weston_h):
        print(
            f"boot logo up to date: {OUT} ({kernel_w}x{kernel_h}); "
            f"Weston {OUT_WESTON_PNG.name} ({weston_w}x{weston_h})"
        )
        return 0

    try:
        kernel_canvas = _render_with_pillow(kernel_w, kernel_h, rotate_icon)
        # PIL BMP writer emits BGR; manual RGB bytes swap red/blue on the panel.
        kernel_canvas.save(OUT, "BMP")
        weston_canvas = _render_with_pillow(weston_w, weston_h, rotate_icon=False)
        _write_weston_png(weston_canvas)
    except ImportError:
        _render_with_magick(OUT, kernel_w, kernel_h, rotate_icon, "BMP")
        try:
            _render_with_magick(
                OUT_WESTON_PNG, weston_w, weston_h, False, "PNG"
            )
        except RuntimeError as e:
            print(f"WARNING: skip {OUT_WESTON_PNG}: {e}", file=sys.stderr)

    shutil.copy2(OUT, OUT_KERNEL)
    print(
        f"boot logo: {OUT} ({kernel_w}x{kernel_h}, "
        f"lcd0={lcd_x}x{lcd_y} rotation={rotation}°, icon_pre_rotate={rotate_icon})"
    )
    print(f"boot logo: {OUT_KERNEL} (copy)")
    if OUT_WESTON_PNG.is_file():
        print(
            f"boot logo: {OUT_WESTON_PNG} "
            f"(Weston splash {weston_w}x{weston_h}, upright, no pre-rotate)"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
