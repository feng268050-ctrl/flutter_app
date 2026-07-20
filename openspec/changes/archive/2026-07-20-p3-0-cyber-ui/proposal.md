## Why

Product Home / Settings / Monitor still use **Material stand-ins** under `app/hmi/lib/ui/cyber/` while lws-ui’s FrostUI (cards, dialogs, buttons, blur, clock chrome) remains Android-only. P3.0 requires a reusable **CyberUI** package so product Apps stop forking glass widgets and can share one Frosted Glass design language on flutter-pi (ynh960). Migrating now unblocks consistent glass chrome and retires ad-hoc stand-ins before more P4 surfaces land.

## What Changes

- Introduce **`packages/cyber_ui`** (path package first, same pattern as `cyber_hal`; submodule/remote repo later if needed) as the shared Flutter UI kit: public **`Cyber*`** APIs, internal Frosted Glass renderer aligned with lws-ui FrostUI.
- Port core FrostUI surfaces into CyberUI (priority order): backdrop blur sampling (`realtime` / `firstFrame` / `onChange`), `CyberCard`, dialog/modal host, buttons, status indicator, home clock glyphs — matching visual tokens from lws-ui, not a line-by-line Kotlin port.
- Port **UI click sound** (`FrostUiClickSoundRegistry` equivalent): injectable `CyberClickSound` + registry; Cyber controls/cards MAY play click on activate; App registers a Linux/ALSA (or asset) backend at startup. Distinct from HAL media volume / demo `shanghai_tan` playback.
- Wire **`app/hmi`** to depend on `cyber_ui`; replace `lib/ui/cyber/*` stand-ins and Home/Monitor Material glass usage with CyberUI widgets.
- Document and enforce §6.3 rules: product pages MUST NOT scatter bare `BackdropFilter`; sampling mode is a widget/API parameter (default **realtime** per current product direction; frozen/first-frame remaining first-class).
- Keep **CyberIME** out of this change’s implementation commit set (separate follow-on); proposal notes the P3.0 pairing only.

## Capabilities

### New Capabilities

- `cyber-ui`: Shared Flutter CyberUI package under `packages/cyber_ui` — Cyber* public widgets, Frosted Glass renderer, backdrop sample modes, click-sound registry, theme seam for future design swaps; App consumes via path dependency.

### Modified Capabilities

- `product-home-ui`: Home glass surfaces (clock, quick actions, future cards) SHALL use CyberUI widgets/APIs rather than in-app Material stand-ins.
- `product-monitor-ui`: Monitor chrome that needs frost/status glass SHALL prefer CyberUI components where applicable (status lights, frosted panels).
- `settings-ui`: Settings shell MAY adopt CyberUI cards/dialogs incrementally; Material tabs remain acceptable until dialog/card migrations land.
- `hmi-app-navigation`: No route inventory change required unless Cyber dialog host needs a documented overlay entry point (prefer in-place `showCyberDialog`).

## Impact

- **New:** `packages/cyber_ui/` (pubspec, lib, tests, README) — modeled after `packages/cyber_hal` layout and publish_to: none.
- **App:** `app/hmi/pubspec.yaml` path dep; delete or thin `app/hmi/lib/ui/cyber/` after migration; Home / Monitor / Settings call sites.
- **Docs:** Align `docs/flutter-pi-hmi-plan.md` §6.3 defaults with product sample-mode enum if needed; AGENTS rebuild remains `make build-app` / `make push-app`.
- **Reference:** lws-ui `frostui/` (blur, card, dialog, button, clock, border) + `docs/frostui.md` — behavior/token parity, Flutter idioms.
- **Out of scope:** CyberIME package; full FrostAudioPlayer / volume-card chrome; full P4 business page migration; Android APK CyberUI backend; per-SKU UI forks; Rust/hald. Media volume HAL remains `cyber_hal` / Settings — not replaced by click SFX.
- **Risks:** Realtime blur cost on RK3566 — CyberUI must keep scale-down / intensity caps and fake-glass fallback; glyph-clipped clock vs rectangular card blur remain distinct APIs; click SFX must not block UI or crash if audio backend missing.
