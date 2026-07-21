## 1. Unified Misc JSON store

- [x] 1.1 Add `MiscSettingsStore` (or equivalent) reading/writing `/var/lib/hmi/misc-settings.json` with per-key defaults, warm-read, soft-fail on corrupt JSON, and unit tests
- [x] 1.2 Migrate Show Startup Self-Check onto the store (import legacy `/var/lib/hmi/boot-self-check` once if JSON key missing); update `BootSelfCheckSettings` / scope consumers
- [x] 1.3 Add `showSystemStatusOverlay` key (default **false**); expose store via app-root scope
- [x] 1.4 Wire Common Settings → Misc **Show System Status Overlay** switch; keep Show Startup Self-Check on the same store

## 2. System status card widget

- [x] 2.1 Add a `SystemStatusCard` (or equivalent) widget that watches `AppServices.sysInfo` at ~1 Hz only while visible and renders one row per metric
- [x] 2.2 Format rows for UI FPS, raster FPS, panel Hz, SoC °C, GPU °C, memory (available/total), CPU load (`loadAverage.one`), and uptime; use `--` for nulls
- [x] 2.3 Style as a compact left-edge card (CyberCard / frosted or dark panel) wrapped in `IgnorePointer`

## 3. Global overlay wiring

- [x] 3.1 Mount the card in `MaterialApp.builder` (Stack over density-matched content), left + vertically centered, only when `showSystemStatusOverlay` is true
- [x] 3.2 Guard with `AppScope.maybeOf` / misc scope so tests without services do not crash; default remains hidden
- [x] 3.3 Remove `HomePerfHud` from `home_page.dart` and delete or relocate the old Home-only HUD file

## 4. Tests and verification

- [x] 4.1 Unit/widget tests: JSON round-trip, legacy boot-self-check import, default no overlay, Misc toggle shows/hides card; Home has no local HUD
- [x] 4.2 Run `flutter analyze` / relevant tests under `app/hmi/`
- [x] 4.3 On device after push: confirm `/var/lib/hmi/misc-settings.json`; default hidden; Misc on/off across routes; values survive app restart
