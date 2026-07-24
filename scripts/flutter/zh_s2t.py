#!/usr/bin/env python3
"""Simplified → Traditional Chinese (OpenCC s2t) for ARB sync.

Uses vendored OpenCC dictionaries under data/opencc/ (Apache-2.0).
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

_DATA_DIR = Path(__file__).resolve().parent / "data" / "opencc"


def _parse_dictionary(path: Path) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            src, *targets = parts
            pairs.append((src, targets[0]))
    return pairs


@lru_cache(maxsize=1)
def _phrase_pairs() -> tuple[tuple[str, str], ...]:
    path = _DATA_DIR / "STPhrases.txt"
    if not path.is_file():
        return ()
    pairs = _parse_dictionary(path)
    pairs.sort(key=lambda p: len(p[0]), reverse=True)
    return tuple(pairs)


@lru_cache(maxsize=1)
def _char_map() -> dict[str, str]:
    path = _DATA_DIR / "STCharacters.txt"
    if not path.is_file():
        return {}
    mapping: dict[str, str] = {}
    for src, dst in _parse_dictionary(path):
        mapping[src] = dst
    return mapping


def apply_tw_product_terms(text: str) -> str:
    """Enforce Taiwan product copy after OpenCC (see ui-theme-i18n-tracker.md)."""
    if not text:
        return text
    # LaserCyber "device" (welding hardware) is 設備 in zh_TW, not 裝置.
    return text.replace("裝置", "設備")


def simplified_to_traditional(text: str) -> str:
    """Convert a UI string from Simplified to Traditional (OpenCC s2t rules)."""
    if not text:
        return text
    out = text
    for src, dst in _phrase_pairs():
        if src in out:
            out = out.replace(src, dst)
    char_map = _char_map()
    if char_map:
        out = "".join(char_map.get(ch, ch) for ch in out)
    return apply_tw_product_terms(out)
