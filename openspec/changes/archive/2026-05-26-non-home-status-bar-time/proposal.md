## Why

On the home dashboard, operators already see a large real-time clock driven by system time. On every other screen that uses the shared `EquipmentStatusBar`, only the WiFi (and optional remote-lock) indicators appear in the top-right—there is no compact time reference. Showing the current system time beside the WiFi icon on non-home pages gives operators consistent temporal context without duplicating the home hero clock layout.

## What Changes

- Add a **compact time label** in `EquipmentStatusBar`, placed **immediately to the right of the WiFi indicator group** (`wifi_content`), visible on all screens that embed the status bar (Monitor, Settings, Engineer Mode, Quick Mode, WiFi/Bluetooth/Upgrade flows, etc.).
- Drive the label from **device system time** (same source of truth as the home clock), refreshing at least once per second while the status bar is attached.
- Use a **readable, status-bar-appropriate format** (e.g. `HH:mm` in the user's default locale, matching the home dashboard minute display unless product prefers date inclusion).
- **Do not** show this compact time on **MainActivity** (home); home continues to use the existing large `home_real_time` display only.
- Preserve existing WiFi / remote-lock layout and click behavior; time is display-only (no new navigation).

## Capabilities

### New Capabilities

- `equipment-status-bar-time-display`: Compact system-time label beside WiFi on `EquipmentStatusBar`, lifecycle-safe ticking, and exclusion from the home dashboard.

### Modified Capabilities

- `system-date-time-management`: Extend home-clock consistency requirement so manual/automatic date-time changes also update the non-home status-bar time without app restart.

## Impact

- **UI**: `equipment_status_bar.xml`, `EquipmentStatusBar.java`, styles/dimensions for status-bar typography.
- **Time source**: Reuse `TimeGlobalManager` (or equivalent system-time listener) already used by `MainActivity.bindTime()`.
- **Screens**: All layouts/activities hosting `EquipmentStatusBar`; no change to `activity_main.xml` home clock.
- **Localization**: Format via `Locale.getDefault()`; no new user-facing strings required if showing numeric time only.
- **Non-goals**: Date/time settings UI changes, NTP/sync policy changes, making the compact clock tappable, or replacing the home hero clock.
