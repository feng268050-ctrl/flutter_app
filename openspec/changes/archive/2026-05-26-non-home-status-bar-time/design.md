## Context

The app has two top-bar patterns:

1. **Home** (`MainActivity` / `activity_main.xml`): WiFi icon top-right; large `GlowGlassTextView` (`home_real_time`) centered on the dashboard, updated via `TimeGlobalManager` + `SimpleDateFormat("HH:mm")`.
2. **Non-home** screens: shared `EquipmentStatusBar` (`equipment_status_bar.xml`) with optional back-to-home (`callback_content`), title, device status icons, and `wifi_content` (remote lock + connected/disconnected WiFi icons). No time display today.

`TimeGlobalManager` already ticks every second on the main thread and exposes `TimeUpdateListener`. `system-date-time-management` spec requires the home clock to track system time changes.

## Goals / Non-Goals

**Goals:**

- Show compact current time immediately after the WiFi icon group on every `EquipmentStatusBar` instance.
- Reuse `TimeGlobalManager` (or direct `System.currentTimeMillis()` with the same listener) so status-bar time stays aligned with home and Settings date/time changes.
- Start/stop updates with view attach/detach to avoid leaks.
- Match status-bar visual density (light text, ~20sp class, adequate left margin from WiFi icons).

**Non-Goals:**

- Changing home layout or `home_real_time` behavior.
- New settings, tap-to-edit time, or NTP policy changes.
- Showing time when `wifi_content` is hidden via `use_connect` (if ever used); time remains tied to the same right-side cluster as WiFi when visible.

## Decisions

### 1. Implement time inside `EquipmentStatusBar` only

**Choice:** Add `TextView` (`status_bar_time` or similar) inside `wifi_content` (or as sibling immediately after it in the horizontal row), wired in `EquipmentStatusBar.java`.

**Rationale:** All non-home screens already embed this component; one change covers Monitor, Settings, Engineer Mode, Quick Mode, network activities, etc.

**Alternative:** Per-activity time views — rejected (duplication, drift risk).

### 2. Subscribe to `TimeGlobalManager` on attach

**Choice:** In `onAttachedToWindow`, register `TimeUpdateListener`; format with `SimpleDateFormat("HH:mm", Locale.getDefault())`; unregister in `onDetachedFromWindow` (alongside existing receiver cleanup).

**Rationale:** Same pipeline as home; single place for WiFi NTP sync side effects; satisfies extended `system-date-time-management` consistency.

**Alternative:** Local `Handler` posting every 1000 ms — works but duplicates `TimeGlobalManager` ticker; only use if listener multi-registration becomes an issue (see risks).

### 3. Time format `HH:mm` (locale-default)

**Choice:** Minute-resolution 24h or locale-appropriate hour display via `SimpleDateFormat` pattern `HH:mm` and default locale — same as `MainActivity.bindTime()`.

**Rationale:** Compact fit beside 30dp icons; consistent with home dashboard (without 150sp styling).

**Alternative:** `yyyy-MM-dd HH:mm` — rejected for width on 1280dp HMI top bar.

### 4. Layout placement

**Choice:** Add `TextView` after WiFi on/off `ImageView` children inside `wifi_content`, with `layout_marginStart` ~12–16dp, `gravity="center_vertical"`, white/light gray text (`#F2F2F2` or existing `equipment_status_text` color family).

**Rationale:** User asked for time **behind** (after) the WiFi icon; keeps remote lock + WiFi + time as one trailing cluster.

## Risks / Trade-offs

- **[Risk] `TimeGlobalManager` holds a single listener** — today `MainActivity` sets one listener for home; registering from `EquipmentStatusBar` may overwrite home updates.  
  **Mitigation:** Refactor `TimeGlobalManager` to support multiple listeners (copy-on-write set) or use a broadcast-style fan-out; **minimum fix:** status bar reads `getCurrentTime()` on attach and uses its own main-thread `Handler` tick if multi-listener refactor is out of scope for this change — design prefers **multi-listener** small refactor since both surfaces must update.

- **[Risk] Quick Mode hides entire status bar when laser on** — time hides with bar; acceptable.

- **[Risk] RTL locales** — `wifi_content` is end-aligned; time after WiFi remains correct in LTR; verify margin in RTL if app supports it.

## Migration Plan

- Ship in normal app release; no data migration.
- Rollback: remove `TextView` and listener registration.

## Open Questions

- None blocking: format confirmed as `HH:mm`; no tap action.
