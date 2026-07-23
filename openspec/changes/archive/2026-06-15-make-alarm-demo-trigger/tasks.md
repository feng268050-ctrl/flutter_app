## 1. Production — alarm laser interrupt

- [x] 1.1 Extend `LaserEnableAlarmGuard.isWorkBlocked`: bypassable trio (A001/C002/L001) keep dangerous-operations bypass; all other `AlarmCodeEnums` codes block when `WarnCacheManager.isWarn(code)`; add `isBypassableAlarmCode` helper
- [x] 1.2 Integrate `DemoAlarmStickyTracker.isSticky(code)` into blocking predicates (trio respects bypass; other codes always block when sticky)
- [x] 1.3 Call `LaserWorkGuard.evaluateAndInterruptIfNeeded` from `DeviceDialogHandler` when enqueueing passive/immediate warn with non-empty `AlarmCodeEnums` `errorCode`
- [x] 1.4 Unit tests: E006 active → `isWorkBlocked` true with no bypass; C002 bypass ON → not blocked; C002 bypass OFF → blocked; empty `errorCode` dialog does not trigger interrupt hook

## 2. App — demo alarm core

- [x] 2.1 Add `DemoAlarmStickyTracker` (mark / isSticky / clear) with unit tests
- [x] 2.2 Add `DemoAlarmTrigger` — resolve `AlarmCodeEnums`, build `WarnDialogVo`, mark sticky, arm `WarnCacheManager`, `showPassiveWarnDialog`, `evaluateAndInterruptIfNeeded`; gate on `!BuildConfig.RELEASE_CHANNEL`
- [x] 2.3 Register non-exported `DemoAlarmReceiver` for `com.lasercyber.lws.ui.action.DEMO_ALARM` in manifest; wire from `LaserApplication`
- [x] 2.4 Extend `DeviceStatusConvert.closeWarn` to no-op while `DemoAlarmStickyTracker.isSticky(code)`
- [x] 2.5 Clear sticky mark when operator dismisses demo warn dialog

## 3. Makefile and script

- [x] 3.1 Add `scripts/make/trigger-alarm.sh` with `trigger` subcommand
- [x] 3.2 Add `alarm` Makefile target, `.PHONY`, and `make help` entry (`make alarm CODE=C002`)
- [x] 3.3 Fail fast when `CODE` is missing; print logcat hint after send

## 4. Tests and verification

- [x] 4.1 Unit test: demo sticky + `closeWarn` no-op; cleared on dismiss
- [x] 4.2 Unit test: `DemoAlarmTrigger` ignores unknown code and `RELEASE_CHANNEL`
- [x] 4.3 Manual: real/simulated E006 with laser ON → laser forced off when warn appears
- [x] 4.4 Manual: `make alarm CODE=C002` with laser ON, ping healthy, bypass OFF → dialog stays + laser off; bypass ON → dialog shown, laser may stay on
- [x] 4.5 Manual: `make alarm CODE=E006` with laser ON → laser off regardless of dangerous-operations toggles
- [x] 4.6 Manual: `RELEASE=1` build ignores demo broadcast
