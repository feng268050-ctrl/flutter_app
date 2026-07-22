# advanced-settings-dangerous-operations Specification

## Purpose

Five dangerous-operation toggles — persistence, defaults, hints, and App-layer policy APIs for laser enable / runtime interrupt / warn severity.
## Requirements
### Requirement: Dangerous Operations toggles persist App-side with lws-ui defaults

Advanced Settings SHALL expose a **Dangerous Operations** group with five CyberUI switches in this order:

| Control | Key | Default |
|---------|-----|---------|
| Keep Laser On while Alarmed | `keepLaserOnWhileAlarmed` | OFF |
| Allow Work after Camera Alarm | `allowWorkAfterCameraAlarm` | OFF |
| Allow Work after Gas Alarm | `allowWorkAfterGasAlarm` | OFF |
| Allow Work after Lens Contamination | `allowWorkAfterLensContamination` | OFF |
| Allow Work after Feeder Alarm | `allowWorkAfterFeederAlarm` | OFF |

Each row SHALL show a localized secondary hint. Values SHALL persist in the App advanced-settings store. Toggling MUST NOT issue a Modbus write solely for the switch change.

#### Scenario: Fresh defaults all off

- **WHEN** the advanced-settings store is created with no file
- **THEN** all five dangerous-operation toggles default to OFF

#### Scenario: Hints visible

- **WHEN** the operator views Dangerous Operations
- **THEN** each switch shows its hint text below the title

### Requirement: Dangerous operations policy via App facade

The App SHALL expose a dangerous-operations facade (parity with lws-ui `DangerousOperationsSettings` + `LaserEnableAlarmGuard` rules) that laser-enable preflight, runtime interrupt, and warn-severity consumers consult:

- **allowWorkAfterCameraAlarm** bypasses C002 for enable/runtime block when ON
- **allowWorkAfterGasAlarm** bypasses A001
- **allowWorkAfterLensContamination** bypasses L001
- **allowWorkAfterFeederAlarm** bypasses W001/W002
- **keepLaserOnWhileAlarmed** when ON prevents runtime force-off for coded alarms while laser enable is active; it MUST NOT by itself pass laser-enable preflight for alarms that still require allow-* (preflight rules follow lws-ui: keepLaserOn affects runtime interrupt; per-code allow-* affect enable blocking for those codes; other coded alarms still block enable unless product policy says otherwise — implement pure policy helpers matching lws-ui `LaserEnableAlarmGuard`)

Ready/LED style indicators SHALL use allow-* only and MUST ignore keepLaserOnWhileAlarmed.

Warn presentation SHALL consult the facade for INFO vs WARN styling on bypassable codes. Turning a bypass OFF SHALL invoke the App laser re-evaluate entry point when wired (soft-fail if full laser interrupt Host is not yet available).

#### Scenario: Facade not UI state

- **WHEN** laser enable preflight or runtime interrupt evaluates a bypass
- **THEN** it reads the App dangerous-operations facade
- **AND** MUST NOT read CyberSwitch widget state directly

#### Scenario: Toggle off re-evaluates when interrupt exists

- **WHEN** laser interrupt evaluation is available
- **AND** the operator turns a bypass OFF while a matching fault is active and laser enable is on
- **THEN** the App SHALL re-evaluate runtime interrupt

#### Scenario: Toggle off invokes re-evaluate hook

- **WHEN** the operator turns Allow Work after Gas Alarm OFF
- **THEN** the App laser re-evaluate entry point is invoked
