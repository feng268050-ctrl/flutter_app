#!/usr/bin/env python3
"""Keep child ARB files in sync with Flutter gen-l10n parent-locale rules.

- app_en.arb: template (all English strings + @metadata)
- app_zh.arb: parent for Chinese (Simplified; all keys, no @metadata)
- app_en_US.arb / app_zh_CN.arb: locale header only (inherit parent)
- app_zh_TW.arb: only keys whose values differ from app_zh.arb

Run via: make l10n-sync  (or make l10n for sync + flutter gen-l10n)
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from zh_s2t import apply_tw_product_terms, simplified_to_traditional

L10N_DIR = Path(__file__).resolve().parents[2] / "app" / "hmi" / "lib" / "l10n"

# Language option labels are endonyms (always English / 简体中文 / 繁體中文).
# Never OpenCC-convert or locale-translate these — keep them identical to zh.
ENDONYM_KEYS = frozenset(
    {
        "languageOptionChinese",
        "languageOptionEnglish",
        "languageOptionTraditionalChinese",
    }
)


def _load(path: Path) -> dict[str, object]:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def _write(path: Path, data: dict[str, object]) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def _message_keys(data: dict[str, object]) -> list[str]:
    return sorted(
        k
        for k in data
        if isinstance(k, str) and not k.startswith("@") and k != "@@locale"
    )


def main() -> int:
    en_path = L10N_DIR / "app_en.arb"
    zh_path = L10N_DIR / "app_zh.arb"
    tw_path = L10N_DIR / "app_zh_TW.arb"

    if not en_path.is_file() or not zh_path.is_file():
        print("Missing app_en.arb or app_zh.arb", file=sys.stderr)
        return 1

    zh = _load(zh_path)
    existing_tw = _load(tw_path) if tw_path.is_file() else {"@@locale": "zh_TW"}

    _write(L10N_DIR / "app_en_US.arb", {"@@locale": "en_US"})
    _write(L10N_DIR / "app_zh_CN.arb", {"@@locale": "zh_CN"})

    tw_out: dict[str, object] = {"@@locale": "zh_TW"}
    auto_filled = 0
    inherited_unchanged = 0
    for key in _message_keys(zh):
        parent_val = zh[key]
        if not isinstance(parent_val, str):
            continue
        # Endonyms must stay in each language’s own script under every locale.
        if key in ENDONYM_KEYS:
            inherited_unchanged += 1
            continue
        if key in existing_tw and existing_tw[key] != parent_val:
            tw_out[key] = apply_tw_product_terms(str(existing_tw[key]))
            continue
        converted = simplified_to_traditional(parent_val)
        if converted != parent_val:
            tw_out[key] = converted
            auto_filled += 1
        else:
            inherited_unchanged += 1

    _write(tw_path, tw_out)

    override_count = len(tw_out) - 1
    print("Wrote app_en_US.arb, app_zh_CN.arb (locale only)")
    print(
        f"Wrote app_zh_TW.arb with {override_count} override(s) "
        f"({auto_filled} auto s2t, {inherited_unchanged} inherit zh unchanged)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
