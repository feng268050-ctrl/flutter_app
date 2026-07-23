## 1. Visual assets and binding

- [x] 1.1 Add DataBinding variable `cameraCommAvailable` (or equivalent) to `camera_controller.xml`
- [x] 1.2 Extend `ImageButtonStateAdapter` with visual-only unavailable binding (e.g. `commUnavailableState`) that mutes idle icon without `setEnabled(false)`
- [x] 1.3 Update `camera_orange_icon.xml`, `camera_green_icon.xml`, `camera_blue_icon.xml` (or adapter alpha) so unavailable idle is visually distinct from available idle and recording

## 2. CameraController state and clicks

- [x] 2.1 Implement `refreshRecordVisualState()` resolving recording > unavailable > available per design
- [x] 2.2 Register / unregister `MemoryCacheManager` listener on `CAMERA_PING_REACHABLE` in attach/detach; call refresh on main thread
- [x] 2.3 Update click handler: recording → stop; fault + idle → toast `unable_to_open_the_camera_title` only; healthy + idle → existing `checkAndStartRecord()`
- [x] 2.4 Call refresh after `startRecord()`, `stopRecord()`, and `initRecord()`; keep preflight transient disable behavior unchanged

## 3. Tests

- [x] 3.1 Unit test state resolution: recording overrides fault; fault shows unavailable visual flag; healthy shows available
- [x] 3.2 Unit test click routing: fault idle does not invoke preflight coordinator; healthy idle still does

## 4. Verification

- [ ] 4.1 Manual: Engineer/Quick float — disconnect camera ping → unavailable visual; tap → camera unavailable toast, no record start
- [ ] 4.2 Manual: reconnect (3 stable pings) → available visual; tap → record starts as today
- [ ] 4.3 Manual: recording continues and stop works if ping fails mid-session
- [x] 4.4 `make build` and relevant unit tests pass
