## 1. TimeGlobalManager multi-listener support

- [x] 1.1 Refactor `TimeGlobalManager` to support multiple `TimeUpdateListener` registrations (add/remove) without breaking `MainActivity.bindTime()`
- [x] 1.2 Ensure each listener receives an immediate callback on register and on `setCustomTime` / WiFi NTP sync completion

## 2. EquipmentStatusBar layout

- [x] 2.1 Add `TextView` for status-bar time inside `equipment_status_bar.xml` immediately after the WiFi icon `ImageView` children in `wifi_content`, with margin and light text styling consistent with the bar
- [x] 2.2 Verify layout on a representative screen (e.g. Monitor) at 1280×800: no overlap with title or status icons

## 3. EquipmentStatusBar logic

- [x] 3.1 In `EquipmentStatusBar`, register `TimeGlobalManager` listener in `onAttachedToWindow`, format with `SimpleDateFormat("HH:mm", Locale.getDefault())`, update `TextView`
- [x] 3.2 Unregister listener in `onDetachedFromWindow` alongside existing receiver cleanup
- [x] 3.3 Confirm home (`MainActivity`) is unchanged and does not show the compact status-bar time

## 4. Verification

- [x] 4.1 Manual: open Monitor/Settings — time appears after WiFi and ticks each minute boundary
- [x] 4.2 Manual: change system time in Settings → Date & Time — status-bar and home clocks both update without restart
- [x] 4.3 Manual: navigate away from a status-bar screen — no leaked callbacks (logcat / repeated attach-detach smoke test)
