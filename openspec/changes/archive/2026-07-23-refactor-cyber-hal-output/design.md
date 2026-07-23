## Context

Today `package:cyber_hal/output` is flat: `Backlight` + `Volume` (+ Linux media audio). Common Settings **Display & Sound** mixes locale stubs, brightness, RGB LED, screen-off (stub), volume, and sound-effect (App `SoundEffectStore`). Top-level `package:cyber_hal/display.dart` already means **DisplayStack** (flutter-pi vs Weston), unrelated to brightness. Weston’s launch config forces `idle-time=0`, so compositor DPMS is not the product screen-off path today.

Stakeholders: HAL package consumers, Common Settings operators, existing backlight/volume/sound-effect tests.

## Goals / Non-Goals

**Goals:**

- Nest `hal/output` as **display** `{Backlight, AutoSleep}` and **sound** `{Volume, ButtonFeedback}` with sub-imports (same pattern as `hal/network`, `hal/input`).
- Make Screen-off Time and Sound Effect consume HAL APIs (persist + apply).
- Reorder Common Settings Display & Sound; place **RGB LED after** the main settings group.
- Move **DisplayStack** (embedder detection) into `hal/sys_info` and **delete** top-level `display.dart` (avoids clash with `output/display`).

**Non-Goals:**

- Changing GPIO RGB LED API or product LED catalog.
- Enabling Weston’s compositor `idle-time` / full DRM DPMS as the primary AutoSleep mechanism in this change.
- Moving click **assets** or `CyberClickSoundRegistry` into `cyber_hal` (CyberUI stays HAL-free).
- Language / unit platform stores; Android backends; warn/alarm loop audio.

## Decisions

### D1 — Public import layout

| Import | Exports |
|--------|---------|
| `package:cyber_hal/output.dart` | Barrel: display + sound public APIs (+ Linux types as today) |
| `package:cyber_hal/output/display.dart` | `Backlight`, `AutoSleep` (+ display Linux backends) |
| `package:cyber_hal/output/display/backlight.dart` | `Backlight` abstract API |
| `package:cyber_hal/output/display/auto_sleep.dart` | `AutoSleep` abstract API |
| `package:cyber_hal/output/sound.dart` | `Volume`, `ButtonFeedback`, media audio as today |
| `package:cyber_hal/output/sound/volume.dart` | `Volume` / `MediaAudioController` surface |
| `package:cyber_hal/output/sound/button_feedback.dart` | `ButtonFeedback` |

**Rationale:** Mirrors `input/{keyboard,mouse}` and `network/{wifi,ethernet,proxy}`. Nested folders make “display vs sound” discoverable without a second top-level domain.

**Alternatives considered:** Flatten only with longer type names (`DisplayBacklight`) — rejected (worse than folders). Keep a top-level `display.dart` for DisplayStack — **rejected** (name clash with `output/display`; see D2).

**Compat:** Same change updates App + package tests to new paths. Optional one-line deprecated re-exports at old `output/backlight.dart` / `output/volume.dart` only if needed for an in-flight consumer; prefer delete + fix call sites in-repo.

### D2 — DisplayStack moves into `sys_info`; delete top-level `display.dart`

Embedder/stack detection (`DisplayStack`, `DisplayStackProbe`, mouse-availability gates) SHALL live under `package:cyber_hal/sys_info.dart` (implementation under `src/sys_info/`). **Delete** `package:cyber_hal/display.dart` so “display” in public imports means only `hal/output/display`.

**Rationale:** Top-level `display.dart` collides conceptually with `output/display` (Backlight / AutoSleep). Stack identity is host inventory, which already belongs with `SysInfo`.

### D3 — `AutoSleep`: absolute sysfs 0 to power off; double-tap to wake

**API:** discrete policy enum (`minutes10` / `minutes30` / `minutes60` / `never`). Persist in `/var/lib/hmi/display.conf` under key `auto_sleep` (`OutputPrefs.displayConf` / `OutputPrefs.keyAutoSleep`).

**Blank (Linux):** Write **absolute / physical sysfs brightness `0`** (panel off) — **not** logical 0 / hardware floor. Remember the prior **logical** percent for restore. Do **not** write the blank into the persisted brightness preference.

**Wake:** Require a **double-tap** (or equivalent double pointer-down within a short window) while blanked to restore the prior logical brightness. Ordinary single moves / single taps while blanked MUST NOT wake. While awake, `noteActivity` only resets the idle timer.

**Alternatives:** Logical-0 blank — rejected (panel stays lit at floor). Any-activity wake — rejected (accidental wake). Weston `idle-time` — deferred.

### D4 — `ButtonFeedback`: selected asset + play via audio HAL

**API:** get/set the active **Flutter asset key** (string), not an Effect index. Persist the asset key in `/var/lib/hmi/sound.conf` under key `button_feedback` (`OutputPrefs.soundConf` / `OutputPrefs.keyButtonFeedback`). `play()` / click playback SHALL call the injected sound HAL (`MediaAudioController.playOneShotAsset` or `Volume` media path) inside `ButtonFeedback`.

**App role:** Settings UI presents the product catalog (Effect 1/2/3 labels ↔ asset keys) and calls `setAssetKey` (and optional preview via `play`). CyberUI registry backend MAY be a thin wrapper that only calls `ButtonFeedback.play()` — no App-side `playOneShotAsset` for clicks.

**HAL owns playback:** `LinuxButtonFeedback` is constructed with a `MediaAudioController` (or equivalent). Assets remain Flutter bundle keys resolved by the media controller; CyberUI stays free of `cyber_hal` imports except via the App-registered backend.

**Alternatives:** Index-only prefs + App plays — rejected (user: HAL controls play). Bundle assets inside `cyber_hal` — rejected (product-owned samples).

### D5 — Common Settings layout

Under section **Display & Sound**:

1. **Main `SettingsGroup` (display then sound):** Language, Unit, Screen Brightness, Screen-off Time, Volume, Sound Effect (ButtonFeedback).
2. **After that group:** RGB LED in its **own** following `SettingsGroup` (or equivalent chrome) so it is visually after the display/sound card, still under the same section header.

**Rationale:** Matches “移动到分组后面”; RGB LED is GPIO product chrome, not an `output` level.

### D6 — Media audio stays under `sound`

`MediaAudioController` / `LinuxMediaAudioController` continue to live with Volume under `output/sound` (playback is sound domain). Warn/alarm code keeps importing sound barrel / `output.dart`.

### D7 — Preference files (`display.conf` / `sound.conf`)

Mouse-style `key=value` files (upsert preserves sibling keys):

| File | Keys |
|------|------|
| `/var/lib/hmi/display.conf` | `backlight` (0–100), `auto_sleep` (`10`/`30`/`60`/`never`) |
| `/var/lib/hmi/sound.conf` | `volume` (0–100), `button_feedback` (Flutter asset key) |

Centralized as `OutputPrefs` + `key_value_conf` helpers. **No** per-knob files and **no** legacy aliases.


### D8 — Src tree

Prefer:

```text
lib/src/output/display/{linux_sysfs_backlight,auto_sleep,…}
lib/src/output/sound/{linux_media_audio_controller,button_feedback,…}
lib/src/stub/{stub_backlight,stub_volume,stub_auto_sleep,stub_button_feedback}
```

Move existing files; update internal imports.

## Risks / Trade-offs

- **[Risk] Absolute-0 blank looks like a hung panel** → Mitigation: double-tap wake only; document in Settings; Never remains default-safe.
- **[Risk] AutoSleep blanking fights operator brightness** → Mitigation: restore exact prior logical percent; never persist absolute 0 as the user brightness preference.
- **[Risk] Idle activity signals miss keyboard-only / BT HID** → Mitigation: injectable activity port; App wires pointer + key + Cyber click paths as available; Never remains default-safe.
- **[Risk] Import churn breaks out-of-tree apps** → Mitigation: this monorepo is the consumer; update all in-tree imports in the same change.
- **[Trade-off] Backlight blank ≠ true panel power-off** → Acceptable for v1; document; future may add DRM/DPMS or Weston idle.
- **[Trade-off] Naming `ButtonFeedback` vs UI “Sound Effect”** → Keep operator-facing “Sound Effect” label; HAL type uses `ButtonFeedback`.

## Migration Plan

1. Land HAL layout + APIs + stubs + unit tests.
2. Point App façades / `AppServices` at new imports; migrate Screen-off + Sound Effect + click bootstrap.
3. Reorder Common Settings; move RGB LED after the group.
4. Update `cyber_hal` README module map; run package + App tests / analyze.
5. Rollback: revert change; new `display.conf` / `sound.conf` prefs are development-only (no legacy aliases).

## Open Questions

- Exact AutoSleep activity injection surface (callback vs Stream) — decide at implement time; prefer minimal App hook.
- Double-tap window duration (default ~400ms) — tune at implement time.
- Whether blank uses a dedicated `setAbsoluteBrightness(0)` vs internal AutoSleep sysfs write — prefer a Backlight API so stubs/tests stay consistent.
