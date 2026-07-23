## 1. Layout and Fragment skeleton

- [x] 1.1 Add `fragment_laser_live_monitor_overlay.xml` (PR1 preview stack + `DetectionOverlayView` + compact gauges/tiles sidebar; enlarge dialog body sizing as needed)
- [x] 1.2 Create `LaserLiveMonitorOverlayFragment` with view binding, empty-state / camera-unavailable placeholders
- [x] 1.3 Wire sidebar gauges/tiles to dialog-variant frosted components and existing MemoryCache / DeviceStatus bindings (v1 field set 1:1)

## 2. Preview and detect subscription

- [x] 2.1 Start EasyPlayer (or equivalent) on `MediaMtxRelayUrls.localPr1()` when fragment starts; async stop + release on destroy/dismiss
- [x] 2.2 Subscribe to `StreamDetectResultBus` while visible; map results to `DetectionOverlayView` boxes; clear on empty/stale; never start/stop detect pipeline from fragment
- [x] 2.3 Handle Laser OFF More Monitor case (preview + gauges OK, boxes may be empty)

## 3. Overlay host integration

- [x] 3.1 Update `MachineStatusOverlay` to attach `LaserLiveMonitorOverlayFragment` into `#work_status_content` (replace gauges-only fragment for this overlay path)
- [x] 3.2 Preserve `showConfirm` true/false chrome; keep singleton Handle reuse / no-op when overlay already showing
- [x] 3.3 Update `MachineStatusOverlayPreloader` for the new body layout

## 4. Quick Mode gun path + More Monitor keep

- [x] 4.1 In `GeneralOperationsFragment.deviceStatusListen`, add Engineer-equivalent gun-edge open/close via `WorkStatusDialogBuilder` while Laser Enable ON
- [x] 4.2 Close overlay on End of work / fragment-or-activity destroy paths already used for laser exit
- [x] 4.3 Keep Logo / More Monitor → `MachineStatusOverlay.show(..., true)` pointing at same body
- [x] 4.4 Ensure CNC Cut / CNC fragments are untouched

## 5. Engineer path and regression

- [x] 5.1 Verify Engineer Mode gun auto path picks up new body without logic changes beyond host attach
- [x] 5.2 Regression: Laser Enable gates, alarm interrupt, Recording Work, Monitor/AI Vision tabs unchanged
- [x] 5.3 Manual matrix: Engineer gun on/off; Quick gun on/off; More Monitor with Laser ON/OFF; dual-entry no second instance; no EasyPlayer stop ANR; PR0 recording + overlay smoke

## 6. Docs / cleanup (optional same PR or follow-up)

- [x] 6.1 Mark in-overlay `MachineStatusDialogFragment` unused path for follow-up cleanup if fully replaced
- [x] 6.2 Sync `docs/laser-live-monitor-overlay-design.md` status to “in progress / implemented” when tasks complete
