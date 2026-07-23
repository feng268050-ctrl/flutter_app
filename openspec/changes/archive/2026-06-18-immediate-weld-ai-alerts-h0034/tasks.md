## 1. Remove deferred weld alert coordinator

- [x] 1.1 Delete `WeldDeferredWarnCoordinator`, `DeferredExternalWarnAlarm`, `WeldLaserAlertTiming` and related unit tests
- [x] 1.2 Move `LensCheckResultEvent` subscription into `LensHeavyContaminationWarnAlarm.start/stop`
- [x] 1.3 Update `LaserApplication` lifecycle to start/stop lens alarm instead of coordinator

## 2. L001 immediate coded-alarm pipeline

- [x] 2.1 Show L001 via `DeviceDialogHandler.showPassiveWarnDialog` on heavy detect (no `isLaserOn()` gate)
- [x] 2.2 Retain warn log, laser-enable block, and dangerous-operations bypass semantics

## 3. H0034 zero-point offset coded alarm

- [x] 3.1 Add `AlarmCodeConstants.ALARM_H0034`, `AlarmCodeEnums.H0034`, and `zero_point_offset_alarm_title` strings
- [x] 3.2 Add `WarnTableViewModel.saveZeroPointOffsetWarnLog`
- [x] 3.3 Refactor `ZeroPointOffsetWarnAlarm` to use H0034, warn_table log, and AutoDialogQueue passive warn
- [x] 3.4 Preserve dual-button dialog (confirm / go to settings) and `ZeroPointPendingCorrectionStore` jump semantics

## 4. OpenSpec

- [x] 4.1 Add change `immediate-weld-ai-alerts-h0034` (proposal, design, delta specs, tasks)
- [x] 4.2 Sync modified requirements into `openspec/specs/`

## 5. Verification

- [x] 5.1 Unit tests: handler / guard tests pass
- [x] 5.2 Manual: `make alarm CODE=L001` during laser ON — dialog stays open
- [x] 5.3 Manual: zero-point offset outside tolerance — H0034 dialog + warn_table row
