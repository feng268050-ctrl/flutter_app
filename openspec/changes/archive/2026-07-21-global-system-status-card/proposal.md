## Why

Engineering host metrics (UI/raster FPS, panel refresh, SoC/GPU temperature) are currently a single-line `HomePerfHud` only on the Home screen, so they disappear after navigation and are hard to scan. Operators and developers need a persistent, readable system status surface that stays visible across routes and can grow to include memory, CPU load, and uptime without cluttering Home chrome — but it must stay off by default so product screens stay clean unless an operator opts in. Misc toggles must not keep proliferating as separate one-off files under `/var/lib/hmi/`.

## What Changes

- Add a **global system status card overlay** that sits above page content on all product routes (Home, Settings, Monitor, and Demo when opened), vertically centered on the **left** side of the screen.
- Move the metrics currently shown by Home’s engineering perf HUD onto this card: UI FPS, raster FPS, panel refresh rate, SoC temperature, GPU temperature.
- Present **one metric per row** (label + value), instead of a single pipe-separated line.
- Add rows for **memory** (used/available or free vs total), **CPU load** (load average and/or frequency summary from existing `SysInfo`), and **system uptime**.
- Remove the Home-only `HomePerfHud` placement so Home no longer owns this engineering strip.
- Keep the overlay non-blocking for input (`IgnorePointer` or equivalent) and non-blocking for first paint (subscribe to `SysInfo.watch` after mount; missing values show `--` / `-`).
- Add Common Settings → Misc **“Show System Status Overlay”** switch; **default OFF**; persisted with other Misc prefs.
- **Unify Common Settings → Misc persistence** into a single JSON file: `/var/lib/hmi/misc-settings.json`. Migrate existing Misc prefs that used per-key files (at least Show Startup Self-Check / `boot-self-check`) into this file; future Misc toggles (e.g. Show Ground Lock Alarm when implemented) SHALL use the same store.

## Capabilities

### New Capabilities
- `system-status-overlay`: Global left-side system status card that streams `SysInfo` metrics (FPS, thermal, memory, CPU load, uptime) as one row per metric across product routes, gated by a Misc preference in `misc-settings.json` (default hidden).

### Modified Capabilities
- `product-home-ui`: Stop requiring Home-local engineering perf HUD / temperature strip for these host metrics; Home remains free of the single-line FPS+thermal overlay once the global card exists.
- `settings-ui`: Common Settings → Misc gains “Show System Status Overlay”; all Misc operator prefs share `/var/lib/hmi/misc-settings.json`.
- `linux-settings-persist`: Misc HMI prefs (boot self-check, system status overlay, and subsequent Misc keys) SHALL live in `misc-settings.json` rather than separate one-off files.
- `product-boot-self-check`: Show Startup Self-Check preference is read/written via the unified Misc JSON store (behavior/defaults unchanged).

## Impact

- **App UI:** New overlay widget wired from app root (`MaterialApp` builder / shell stack), visible only when preference is enabled; remove `HomePerfHud` from `home_page.dart`; Common Settings Misc switch; tests for default-hidden and toggle behavior.
- **Prefs:** New/extended App-owned store at `/var/lib/hmi/misc-settings.json`; migrate `BootSelfCheckSettings` off `/var/lib/hmi/boot-self-check` (one-time import of legacy file if present, then prefer JSON).
- **Data:** Reuse `package:cyber_hal/sys_info`. Prefer not starting `SysInfo.watch` while the overlay is disabled.
- **Visual:** Compact card; must not obscure primary Home mode entries more than a narrow left strip.
- **Out of scope:** Welding-gun / Modbus alarm temperatures (stay on Monitor); Settings Device Information identity rows; implementing Ground Lock Alarm behavior (only reserve the Misc JSON key when/if wired). Sound Effect and other non-Misc Common Settings (brightness, Wi‑Fi, …) keep their existing paths / helpers.
