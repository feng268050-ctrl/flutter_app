# laser-live-monitor-overlay Specification

## Purpose

Shared Live Monitor overlay for Engineer and Quick Mode: PR1 preview, AI detection boxes, and machine-status gauges/tiles overlaid on video. Gun auto-open and More Monitor share one body; CNC is out of scope.

## Requirements

### Requirement: Live Monitor overlay shows PR1 preview with detection boxes and gauges

The App SHALL provide a shared overlay body (`LaserLiveMonitorOverlayFragment` or equivalent) that displays (1) a local MediaMTX **PR1** live preview, (2) AI detection boxes drawn via `DetectionOverlayView` (or equivalent) over that preview, and (3) machine-status gauges/tiles bound to existing device MemoryCache fields. The overlay MUST NOT start or stop the native stream-detect pipeline; it MUST only subscribe to published detect results (e.g. `StreamDetectResultBus`) while visible.

#### Scenario: Gun auto overlay shows preview and gauges

- **WHEN** Laser Enable is ON and the gun switch transitions to ON on Engineer Mode or Quick Mode welding pages
- **THEN** the work-status overlay MUST open without a confirm bar
- **AND** the body MUST show PR1 preview and machine-status gauges/tiles
- **AND** when detect results are available, boxes MUST be drawn on the preview

#### Scenario: Overlay dismiss stops preview only

- **WHEN** the Live Monitor overlay is dismissed (gun off debounce, End of work, confirm, or activity destroy)
- **THEN** PR1 preview playback MUST stop
- **AND** detect bus listeners registered by the overlay MUST be removed
- **AND** the detect pipeline lifecycle MUST remain owned by Laser Enable coordinators (not forced stopped solely because the overlay closed)

#### Scenario: Camera unavailable shows placeholder

- **WHEN** the overlay is visible and the camera/preview cannot start
- **THEN** the overlay MUST show a non-blocking unavailable placeholder
- **AND** the operator MUST still be able to close the overlay via the active close path

### Requirement: Quick Mode welding gun edge matches Engineer Mode

Quick Mode welding pages (`GeneralOperationsFragment`) SHALL open and close the same work-status Live Monitor overlay on gun edges while Laser Enable is ON, using `WorkStatusDialogBuilder` semantics equivalent to Engineer Mode (`createShowNoButtonDialog` on rising edge, `scheduleCloseOnGunOff` on falling edge, End of work / destroy cleanup). CNC Cut pages MUST NOT gain this auto overlay as part of this capability.

#### Scenario: Quick Mode gun rising edge opens overlay

- **WHEN** Laser Enable is ON on a Quick Mode welding page and gun switch rises to ON
- **THEN** the App MUST open the no-confirm Live Monitor overlay

#### Scenario: Quick Mode gun falling edge schedules close

- **WHEN** the Quick Mode gun auto overlay is showing and gun switch falls to OFF
- **THEN** the App MUST schedule close via `WorkStatusDialogBuilder.scheduleCloseOnGunOff` (or equivalent debounce close)

#### Scenario: CNC Cut is unchanged

- **WHEN** the operator uses CNC Cut
- **THEN** this capability MUST NOT introduce gun-triggered Live Monitor overlay behavior on CNC pages

### Requirement: More Monitor and gun auto share one body with distinct chrome

Quick Mode “More Monitor” (device logo / More Monitor control) MUST remain available and MUST open the **same** Live Monitor body with a confirm bar (`MachineStatusOverlay.show(..., true)` or equivalent). If the gun auto overlay is already visible, a More Monitor tap MUST reuse the active handle or no-op (MUST NOT open a second instance or force-convert confirm chrome in v1).

#### Scenario: More Monitor opens Live Monitor with confirm

- **WHEN** the operator taps More Monitor on Quick Mode
- **THEN** the Live Monitor overlay MUST appear with a confirm/dismiss action
- **AND** Laser Enable MAY be OFF (preview + gauges available; boxes MAY be empty)

#### Scenario: More Monitor while gun overlay visible

- **WHEN** the gun auto Live Monitor overlay is already displayed
- **AND** the operator taps More Monitor
- **THEN** the App MUST NOT present a second overlay instance
- **AND** MUST reuse the existing handle or ignore the tap

### Requirement: Live Monitor gauges keep dialog frosted glass chrome

Live Monitor gauges/tiles SHALL use dialog-variant frosted glass machine-status gauge/tile components with Modbus/status bindings functionally unchanged for the v1 field set. Active status tiles MAY tint the card fill to reflect on/off without a separate status-indicator glyph.

#### Scenario: Gauges remain frosted dialog variant

- **WHEN** Live Monitor overlay displays gauges/tiles on the preview
- **THEN** gauge/tile containers MUST use dialog-variant frosted glass chrome
- **AND** status tiles MUST continue to reflect `DeviceStatus` on/off bindings
