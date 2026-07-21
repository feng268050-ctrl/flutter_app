## Context

Today `HomePerfHud` (`app/hmi/lib/features/home/presentation/home_perf_hud.dart`) is positioned top-left on Home only. It watches `AppServices.sysInfo` at 1 Hz and renders one monospace line: UI/RAST/PANEL FPS + SoC/GPU °C. `SysInfoSnapshot` in `cyber_hal` already carries memory, load average, uptime, and CPU freq/cores — the HUD simply does not display them.

Product navigation uses `MaterialApp` routes (`Home` / `Settings` / `Monitor` / Demo). A Home-only Stack child cannot remain visible after push. The app root already wraps content in `MaterialApp.builder` (`_matchFlutterPiDensity`) and `AppScope`, which is the natural place for a global, non-interactive overlay.

Common Settings → Misc currently persists Show Startup Self-Check in a dedicated file (`/var/lib/hmi/boot-self-check`). Adding another Misc toggle as a second one-off file is the wrong direction: Misc prefs SHALL share one JSON document.

## Goals / Non-Goals

**Goals:**

- Persist an engineering system status card on all product routes **when enabled**.
- Place it vertically centered on the left edge (narrow strip; one metric per row).
- Relocate Home FPS + SoC/GPU thermal rows into that card; add memory, CPU load, and uptime.
- Reuse existing `SysInfo.watch` — no parallel polling path; only while the overlay is shown.
- Keep first paint free of blocking I/O; missing fields show `--`.
- Expose **Show System Status Overlay** in Common Settings → Misc; **default disabled**.
- Persist **all Common Settings → Misc** operator preferences in **`/var/lib/hmi/misc-settings.json`** (unified JSON).

**Non-Goals:**

- Welding-gun / Modbus alarm temperatures (Monitor Alarm Information).
- New HAL APIs beyond what `SysInfoSnapshot` already exposes (unless a gap is found during apply).
- Redesigning Home layout or Cyber glass chrome beyond what the card needs.
- Exact pixel-perfect mock from lws-ui (engineering utility, not product marketing chrome).
- Per-metric row toggles or advanced HUD configuration.
- Moving Sound Effect, brightness, network, etc. into `misc-settings.json` (those are not Misc-section prefs).

## Decisions

### D1 — Mount via `MaterialApp.builder` stack (global)

Wrap the existing density-matcher output in a `Stack`: route child + optional `Positioned` status card. The card reads `AppServices.sysInfo` the same way `HomePerfHud` does today, but only when the preference is enabled.

**Why not** put it only on Home or per-page Scaffold: fails the “global” requirement.  
**Why not** `OverlayEntry` / `CyberOverlayHost`: heavier than needed for a permanent, non-modal strip; builder Stack is simpler and always present.

### D2 — Replace `HomePerfHud` with `SystemStatusCard` (or rename/move)

Implement a dedicated widget under a shared presentation path (e.g. `app/hmi/lib/features/system_status/` or `app/hmi/lib/ui/system_status/`). Delete Home’s `Positioned` + `HomePerfHud` usage. Prefer moving/renaming rather than leaving a dead Home-only file.

### D3 — Layout: left + vertical center, one row per metric

Use `Align(alignment: Alignment.centerLeft)` or `Positioned(left: …, top/bottom: 0)` with a vertically centered column. Fixed narrow width (~160–220 logical px) so Home mode heroes stay usable. Row pattern: short label + value (e.g. `UI    56`, `SoC   48°C`, `MEM   312/512 MB`, `LOAD  0.42`, `UP    1d 2h`).

**Metric set (initial):**

| Row | Source field(s) |
|-----|-----------------|
| UI FPS | `uiFps` |
| Raster FPS | `rasterFps` |
| Panel Hz | `panelRefreshHz` |
| SoC °C | `socThermal` |
| GPU °C | `gpuThermal` |
| Memory | `memoryAvailableBytes` / `memoryTotalBytes` (show used or available vs total) |
| CPU load | `loadAverage.one` (optionally show 1/5/15 compactly on one row if space allows — default **one** primary load row; freq MAY be a second row `CPU MHz`) |
| Uptime | `uptime` formatted as compact duration |

### D4 — Visual: compact frosted/dark card, `IgnorePointer`

Prefer a small `CyberCard` / frosted surface if it stays readable over Home artwork; otherwise a semi-opaque dark panel with monospace text matching the current HUD contrast. Always wrap with `IgnorePointer` so taps pass through to Home mode entries / Settings.

### D5 — Watch interval 1 s (only while visible)

Keep `Duration(seconds: 1)` like `HomePerfHud` so FPS and load feel live **while the overlay is enabled**. When disabled, do not subscribe to `SysInfo.watch` for this card. Device Information tab can remain at 2 s — no coupling required.

### D6 — Spec delta for `product-home-ui`

Update Home requirements so host engineering metrics are **not** required on Home; the global overlay owns them when enabled. Do not revive welding-gun temperatures on Home (they remain Monitor).

### D7 — Unified Misc JSON store

**Path:** `/var/lib/hmi/misc-settings.json` (`${OsPaths.varHmi}/misc-settings.json`).

**Shape (illustrative; stable key names in code):**

```json
{
  "showStartupSelfCheck": true,
  "showSystemStatusOverlay": false,
  "showGroundLockAlarm": false
}
```

- App-owned: Dart reads/writes the whole document (warm-read at start; rewrite on each Misc key change). Missing file → defaults. Missing key → that key’s default. Corrupt JSON → treat as missing keys / defaults (soft-fail; do not crash).
- **Defaults:** `showStartupSelfCheck` = **true** (unchanged); `showSystemStatusOverlay` = **false**; `showGroundLockAlarm` reserved / default false until product wires it (UI may remain stub until then).
- **Legacy migration:** If `misc-settings.json` is absent but `/var/lib/hmi/boot-self-check` exists, import that boolean into `showStartupSelfCheck`, write JSON, and stop using the legacy file as the source of truth (MAY delete or leave the legacy file unread thereafter).
- Expose one `MiscSettingsStore` (or equivalent) via app-root scope; `BootSelfCheckSettings` either wraps this store or is replaced so boot self-check and overlay share one instance.
- Common Settings → Misc switches read/write through this store. Overlay toggle takes effect immediately.

**Why not** separate `system-status-overlay` file: user requirement and avoids Misc file sprawl.  
**Why not** put Sound Effect / brightness here: different Common Settings sections with existing contracts.

## Risks / Trade-offs

- **[Risk] Left-centered card overlaps Home Quick Mode hero** → Keep width narrow; default off reduces impact.
- **[Risk] Continuous 1 Hz rebuilds** → Only while enabled.
- **[Risk] Concurrent writes** → Single-process HMI; serialize updates through one store instance.
- **[Risk] Legacy boot-self-check boards** → One-time import into JSON on first warm-read.
- **[Trade-off] Load average vs % CPU** → Load average is already in HAL; % idle later if needed.

## Migration Plan

1. Land `MiscSettingsStore` + JSON path + legacy `boot-self-check` import; rewire Show Startup Self-Check; add Show System Status Overlay key (default false).
2. Gate overlay on `showSystemStatusOverlay`; remove Home HUD.
3. Tests: defaults, JSON round-trip, legacy import, overlay toggle; navigation/widget coverage.
4. Device: `make build-app` / `make push-app`; default hidden; Misc toggles; restart keeps JSON values.
5. Rollback: revert store + overlay; optional restore of `BootSelfCheckSettings` file path if needed.

## Open Questions

- None blocking. Exact JSON key naming can follow camelCase as above unless an existing product schema prefers snake_case — pick one in implementation and keep it stable.
