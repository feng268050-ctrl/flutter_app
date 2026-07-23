## 1. Scope and mapping

- [x] 1.1 Add `LensDetProductionAlertMapper` (or equivalent) mapping `LensDetDetectResult` → `LensCheckResultEvent` (`level` 2 / 0, `status`, JSON `message` with `source=production_lens_det`)
- [x] 1.2 Add `ProductionWeldAlertScope` with unit tests: eligible only for Quick/Engineer + `CONTINUOUS_WELDING` / `POINT_WELDING`; expose `getActiveModeType()` on both Activities if needed
- [x] 1.3 Add 12s same-level dedup in publisher before posting heavy events

## 2. Laser-stop trigger (shared)

- [x] 2.1 Change `LensHeavyContaminationAlarmController` to show heavy dialog on **laser falling edge** (ON→OFF), not rising edge; guard `!isLaserOn()` before show
- [x] 2.2 Ensure no heavy/mild dialog is shown while laser is ON
- [x] 2.3 Optional: remove「点击确认可继续出光」suffix when showing after laser stop

## 3. Lens det wiring

- [x] 3.1 Wire `LensDetDetectCoordinator` → publisher → `LensCheckResultEvent` when scope eligible
- [x] 3.2 Filter `production_lens_det` in controller; ignore preview/live/process_video sources

## 4. Zero point offset alert

- [x] 4.1 On zero-point task finalize with `!isWithinPositionTolerance`, set `pendingZeroPointAlert` (production scope only)
- [x] 4.2 On laser falling edge, show dual-button dialog: body **零点偏移中心请及时校正**; confirm + **去设置** → `DeviceSettingActivity` tab `0`
- [x] 4.3 Add strings: `zero_point_offset_alert_body`, `zero_point_offset_alert_go_settings` (+ EN)
- [x] 4.4 Queue with dirty alert if both pending (dirty first, then zero point)

## 5. Tests

- [x] 5.1 Unit: falling-edge triggers dialog; rising-edge does not
- [x] 5.2 Unit: level 1 ignored in production scope
- [x] 5.3 Unit: zero-point pending only when outside tolerance; dialog only after laser off

## 6. Manual verification (`make sync`)

- [ ] 6.1 Continuous weld: stain during laser ON → no dialog; laser OFF → heavy dirty dialog (知道了 only)
- [ ] 6.2 Spot weld: zero offset during laser ON → auto 0090H may apply; laser OFF → zero offset dialog with 确认 + 去设置
- [ ] 6.3 CNC cut / AI Vision: no production dialogs
- [ ] 6.4 Confirm **去设置** opens Advanced Settings (零点校正可见)
