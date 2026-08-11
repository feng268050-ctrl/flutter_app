#!/usr/bin/env python3
"""Recolor welding default laser-enable trapezoid WebP to actionOrange (#F46E01).

Preserves the baked vertical gradient / rim highlights. Does not touch green/blue
variants. Requires Pillow (pip install pillow).

Usage:
  python3 scripts/recolor-laser-enable-btn.py
  python3 scripts/recolor-laser-enable-btn.py --restore
"""
from __future__ import annotations

import argparse
from colorsys import hsv_to_rgb, rgb_to_hsv
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "app/lws_hmi/assets/process/laser_enable_btn.webp"
BACKUP = ASSET.with_suffix(".webp.bak")

# ProcessModeOutlineChrome.actionOrange
TARGET_RGB = (244, 110, 1)
LIFT_BASE = 0.03
LIFT_SHADOW = 0.07


def recolor(src: Path, dst: Path) -> None:
    th, ts, _ = rgb_to_hsv(*(c / 255 for c in TARGET_RGB))
    im = Image.open(src).convert("RGBA")
    arr = np.array(im, dtype=np.float32) / 255.0
    alpha = arr[..., 3]
    rgb = arr[..., :3]
    h, s, v = np.vectorize(lambda r, g, b: rgb_to_hsv(r, g, b))(
        rgb[..., 0], rgb[..., 1], rgb[..., 2]
    )
    body = (alpha > 0.06) & (v > 0.15) & (s > 0.35) & (h < 0.12)
    new_h = np.where(body, th, h)
    new_s = np.where(body, np.maximum(s, ts * 0.96), s)
    lift = np.where(body, LIFT_BASE + LIFT_SHADOW * (1.0 - v), 0.0)
    new_v = np.where(body, np.minimum(1.0, v + lift), v)
    r, g, b = np.vectorize(lambda hh, ss, vv: hsv_to_rgb(hh, ss, vv))(
        new_h, new_s, new_v
    )
    out = np.clip(
        np.stack([r * 255, g * 255, b * 255, alpha * 255], axis=-1), 0, 255
    ).astype(np.uint8)
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out).save(dst, lossless=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--restore",
        action="store_true",
        help="Restore laser_enable_btn.webp from .webp.bak",
    )
    args = parser.parse_args()
    if args.restore:
        if not BACKUP.is_file():
            raise SystemExit(f"backup missing: {BACKUP}")
        BACKUP.replace(ASSET)
        print(f"restored {ASSET}")
        return
    if not ASSET.is_file():
        raise SystemExit(f"asset missing: {ASSET}")
    if not BACKUP.is_file():
        BACKUP.write_bytes(ASSET.read_bytes())
        print(f"backup written: {BACKUP}")
    recolor(BACKUP, ASSET)
    print(f"recolored {ASSET} -> #{TARGET_RGB[0]:02X}{TARGET_RGB[1]:02X}{TARGET_RGB[2]:02X}")


if __name__ == "__main__":
    main()
