## Context

lws-ui ships FrostUI (Kotlin/Compose + View interop): blur target/capture, `FrostCardView`, dialog overlay host, buttons, clock glyph blur, status chrome. lws-hmi App already prototypes pieces under `app/hmi/lib/ui/cyber/` (`CyberBackdropBlur`, sample modes, status indicator, Home clock/quick actions) but they are **not** a reusable package. Roadmap P3.0 requires `packages/cyber_ui` with **Cyber\*** public API and Frosted Glass as the initial design language (`docs/flutter-pi-hmi-plan.md` §6.3; archived `cyber-ui` identity spec).

Constraints from this repo’s standards:

- Path package under `packages/` like `cyber_hal` (`publish_to: none`, Flutter SDK ^3.5, `flutter_lints`).
- Minimize scope; match existing Dart style; no drive-by App refactors.
- Product App owns routes/features (DDD modules); CyberUI owns reusable chrome only.
- Device iteration: `make build-app` / `make push-app`; validate on ynh960.
- Public names **Cyber\***; internal frost renderer OK; no long-term `Frost*` App API.

## Goals / Non-Goals

**Goals:**

- Land `packages/cyber_ui` with backdrop sampling API + core glass widgets used by Home (and ready for Settings/Monitor).
- Move App stand-ins into the package (or re-export once) so product code depends on `package:cyber_ui/...`.
- Preserve three sample modes (`realtime` / `firstFrame` / `onChange`) already proven in App.
- Port **click SFX** registry (lws-ui `FrostUiClickSoundRegistry`) so Cyber controls can play tap feedback without owning ALSA/media volume.
- Establish a theme/renderer seam so Frosted Glass can be swapped later without renaming CyberCard/Dialog call sites.
- Document consumption rules (no bare `BackdropFilter` in features).

**Non-Goals:**

- CyberIME / soft keyboard (follow-on change).
- Full parity with every FrostUI control (sliders, **FrostAudioPlayerCard**, volume chrome) in v1 — click SFX is in; media player card is not.
- Line-by-line Kotlin port or Compose runtime.
- Android APK CyberUI backends / P5.0.
- Rewriting all Settings Material tabs to glass in the same milestone.
- Replacing `cyber_hal` media volume / Settings Display & Sound with UI-kit audio.

## Decisions

### D1 — Path package first (not submodule-on-day-one)

**Choice:** Create `packages/cyber_ui` in-repo, App `pubspec` path dependency — same as current `cyber_hal`.

**Why:** Matches AGENTS / cyber_hal workflow; avoids blocking on a new git remote. Promote to submodule when a second product App needs an independent release cadence.

**Alternatives:** Immediate submodule → slower; keep widgets only in `app/hmi` → blocks reuse and contradicts P3.0.

### D2 — Public Cyber\* API; Frost as renderer

**Choice:** Export `CyberCard`, `CyberBackdropBlur`, `CyberBlurSampleMode`, `showCyberDialog` / `CyberModal`, `CyberButton`, `CyberStatusIndicator`, `CyberHomeClock` (or keep HomeClock as App widget that *uses* Cyber blur primitives). Internal packages may use `frost_*` file names.

**Why:** Archived cyber-ui identity + plan §6.3; Apps must not depend on `Frost*` forever.

### D3 — Sample mode enum (product default realtime)

**Choice:** Keep `CyberBlurSampleMode { realtime, firstFrame, onChange }` with **default `realtime`**. Plan §6.3 historically preferred frozen-default for dialogs; product Home already chose live sampling. Document: **cards/home chrome default realtime**; **heavy dialogs MAY default firstFrame** via factory/`showCyberDialog` params.

**Why:** Honor current product direction without deleting frozen/on-change paths needed for RK3566 cost control.

**Alternatives:** Force frozen default everywhere → regresses Home; live-only → drops capture API.

### D4 — Port order (v1 slice)

1. Package scaffold + blur primitives (lift from App).
2. `CyberCard` / quick-action glass (Home buttons).
3. Status indicator.
4. Click-sound registry + App Linux/asset backend registration; wire into tappable Cyber chrome.
5. Dialog/modal host skeleton (`showCyberDialog` + frozen/realtime backdrop).
6. Clock: either move glyph painter into cyber_ui or keep App `HomeClock` calling Cyber blur APIs — prefer **primitives in package, composition in App** for clock until glyph API stabilizes.
7. Wire App; delete duplicate `lib/ui/cyber` files.

**Why:** Highest reuse first; dialogs are higher risk (overlay + capture policy).

### D5 — Capture root API

**Choice:** Keep `CyberBlurBackdropScope` + `CyberBlurBackdropTarget` (sibling consumers) as in current Home.

**Why:** Matches lws-ui sibling `FrostCaptureTarget` locator pattern; InheritedWidget-only parent chain failed for Home clock/buttons.

### D6 — Theme seam

**Choice:** `CyberTheme` / `CyberGlassTheme` InheritedWidget or ThemeExtension holding intensities, tints, radii, edge tokens. Widgets read theme; App can override at root.

**Why:** Design swappability requirement without rewriting call sites.

### D7 — Testing / acceptance

**Choice:** Package unit/widget tests for sample modes, overlay color resolve, card smoke, click-registry no-op when unregistered; App navigation tests still pass. Device: ynh960 Home glass + one dialog smoke + optional click hear-test via `make build-app` / `make push-app`.

### D8 — Click sound registry (injectable backend)

**Choice:** Mirror lws-ui `FrostUiClickSoundRegistry`: CyberUI defines `CyberClickSound` (abstract/`typedef`) + `CyberClickSoundRegistry.register` / `playClick()`. Widgets (`CyberButton`, `CyberCard` taps, checkbox/segmented when ported) call `playClick()` when `clickSoundEnabled` is true (default true). **App** registers the Linux player at bootstrap (asset short click via existing ALSA/`mpg123` path or a tiny dedicated wav/mp3) — package does **not** hard-depend on `cyber_hal` audio.

**Why:** Same decoupling as Android `GlobalSoundManager::playClickSound`; keeps cyber_ui free of board audio details; missing registration is silent no-op (tests + early boot).

**Alternatives:** Bundle player inside cyber_ui → couples to ALSA; always use system click → none on flutter-pi.

**Not included:** `FrostAudioPlayerCard` / long-form media UI (still Non-Goal).

## Risks / Trade-offs

- **[Risk] Realtime blur GPU cost on RK3566** → Mitigation: intensity caps, capture scale divisor for frozen paths, fake-glass fallback, prefer firstFrame for large dialogs.
- **[Risk] Glyph clock ≠ rectangular card blur** → Mitigation: separate APIs; do not force clock through `CyberCard`.
- **[Risk] Plan §6.3 frozen-default vs product realtime-default** → Mitigation: document dual defaults (chrome vs dialog factories) in package README + design.
- **[Risk] Incomplete FrostUI port leaves App hybrids** → Mitigation: explicit v1 inventory; Material OK for Settings tabs until CyberCard lands.
- **[Risk] Click SFX fails or blocks UI on device** → Mitigation: registry no-op if unregistered; play async; never throw into gesture handlers.
- **[Trade-off] In-repo package vs submodule** → Faster ship; versioning across products deferred.

## Migration Plan

1. Scaffold `packages/cyber_ui` + README + analysis_options.
2. Move blur/status code from App → package; App temporarily re-exports or updates imports.
3. Introduce `CyberCard` / dialog APIs; migrate Home quick actions + clock consumers.
4. Add click-sound registry + App backend registration; smoke Home taps.
5. Update product specs / OpenSpec archive when change completes.
6. Rollback: revert App pubspec path dep and restore `lib/ui/cyber` from git if package regresses device UI.

## Open Questions

1. Should `CyberHomeClock` live in cyber_ui or stay product-specific in `app/hmi`? (Recommend product-specific until glyph API is stable.)
2. Exact dialog capture policy parity with lws-ui `FrostBackdropCapturePolicy` (AUTO / IME / MANUAL) — v1 minimal vs full?
3. When to split git submodule / CI pin — after second consumer appears?
4. Click asset: reuse a short clip from lws-ui, or a new tiny wav under `packages/cyber_ui/assets` / App assets?
