# camera-communication-alarm Specification

## Purpose

Product camera communication alarm **C002**: map HAL IP-camera health into the shared `cyber_alarm` stack (not a parallel camera-only warn UI).

## Requirements

### Requirement: C-series communication alarm codes for camera

Industrial camera communication faults SHALL use alarm code **C002** from the product alarm catalog. The App MUST NOT use **C001** for camera communication.

#### Scenario: Camera fault uses C002 not C001

- **WHEN** the app raises a camera communication alarm from IP-camera health
- **THEN** the warn episode, history row, and popup SHALL use alarm code **C002**
- **AND** the app MUST NOT use **C001** for that camera fault

### Requirement: IP-camera health drives C002 through cyber_alarm

The App SHALL map HAL `IpCameraController` health into the existing `cyber_alarm` inbound port (`AlarmSignalSource`): **unhealthy** → active C002 (rising), **healthy** → inactive C002 (falling). Phase **unknown** MUST NOT raise or retain C002. The App MUST reuse the process `WarnAlarmCoordinator`, presentation host, catalog, and historical log already used for Modbus-backed codes — MUST NOT introduce a parallel camera-only warn dialog or episode state machine.

Presentation while boot self-check is gated SHALL follow the existing App `WarnGate` / coordinator behavior (no competing modal). Recovery and single-popup-per-fault semantics SHALL follow existing episode policy.

C002 dialog severity SHALL follow existing Advanced Settings `allowWorkAfterCameraAlarm` via `LaserAlarmPolicy` (WARN when bypass OFF, INFO when ON). Looping warn SFX SHALL start only when the C002 warn dialog is presented (same moment as the popup), and MUST NOT play for a queued C002 while another dialog is showing or when no dialog is visible. SFX MUST NOT play when that policy resolves the code to INFO.

#### Scenario: Fault detected after unhealthy health

- **WHEN** `IpCameraController.health` transitions to unhealthy
- **AND** warn presentation is not gated
- **AND** `allowWorkAfterCameraAlarm` is false
- **THEN** the coordinator SHALL arm a C002 episode
- **AND** the operator SHALL see a warn popup with the product catalog C002 title/body
- **AND** the popup MUST use WARN styling
- **AND** the warn alarm sound SHALL play while that popup is showing

#### Scenario: Queued C002 stays silent behind another dialog

- **WHEN** another warn dialog is already showing
- **AND** C002 becomes active and is queued
- **THEN** the looping warn alarm sound MUST NOT switch to C002
- **AND** C002 sound SHALL start only when the C002 popup is presented

#### Scenario: Fault with camera bypass shows info dialog without SFX

- **WHEN** camera health is unhealthy
- **AND** `allowWorkAfterCameraAlarm` is true
- **THEN** any C002 popup shown MUST use INFO styling
- **AND** MUST NOT play the looping warn alarm sound

#### Scenario: Recovery clears alarm

- **WHEN** a subsequent health update reports healthy while C002 was active
- **THEN** the C002 episode fault SHALL clear
- **AND** the camera communication popup SHALL be dismissed or not re-shown for that fault cycle per existing recover policy

#### Scenario: No duplicate popups while fault persists

- **WHEN** camera health remains unhealthy across multiple health samples
- **THEN** the app SHALL NOT spam repeated popups for the same active C002 fault

#### Scenario: Unknown health does not raise C002

- **WHEN** camera health phase is unknown (not yet primed, probe quiet, or path reconfigure)
- **THEN** the app SHALL NOT raise or retain C002 solely due to unknown

#### Scenario: Uses existing warn stack only

- **WHEN** camera health becomes unhealthy
- **THEN** C002 SHALL be delivered as `AlarmSignalEvent`s into the same coordinator as Modbus alarms
- **AND** the App MUST NOT open a separate camera-only warn host or duplicate episode controller

### Requirement: C002 health probes must not displace MediaMTX stream clients

Camera communication C002 SHALL continue to follow HAL `IpCameraHealth` only. Probe implementations used to drive that health MUST NOT steal the camera’s exclusive `/PR0` or `/PR1` consumers from the product MediaMTX upstream. A false unhealthy caused by the probe itself competing for PR0/PR1 is a defect.

#### Scenario: Probe under live relay does not force C002

- **WHEN** MediaMTX is successfully relaying camera PR0 (or PR1)
- **AND** the camera host remains reachable
- **AND** HAL health probing is running
- **THEN** C002 MUST NOT rise solely because the health probe opened a competing PR0/PR1 session

### Requirement: Camera C002 participates in laser work policy

While C002 fault is active in the warn episode map, existing `LaserWorkGuard` / `LaserAlarmPolicy` SHALL treat camera as blocking unless `allowWorkAfterCameraAlarm` is ON (or `keepLaserOnWhileAlarmed` applies to runtime interrupt). Fault and recovery edges SHALL re-evaluate soft laser interrupt via the existing guard.

#### Scenario: Unbypassed C002 can clear laser enable

- **WHEN** C002 becomes active
- **AND** `allowWorkAfterCameraAlarm` is false
- **AND** `keepLaserOnWhileAlarmed` is false
- **THEN** laser work interrupt evaluation SHALL run and MAY clear `control.laser_enable` per existing guard behavior

#### Scenario: Bypassed C002 does not block for camera alone

- **WHEN** C002 is active
- **AND** `allowWorkAfterCameraAlarm` is true
- **AND** no other blocking coded alarms are active
- **THEN** camera-alone policy SHALL NOT block ready/work for C002

### Requirement: Camera program firmware upgrade quiets C002

While a camera program firmware apply session is flashing, rebooting the camera, or waiting for the camera to come back online, the App SHALL suspend IP-camera communication health probes used for C002 and SHALL suppress C002 alarm edges for that window (including clearing any active C002 raised for the upgrade path). When the session ends (success or failure), the App SHALL resume probes and end C002 suppression.

#### Scenario: Flash window does not raise C002

- **WHEN** camera CGI flash / reboot / wait-online is in progress
- **THEN** IP-camera health probes used for C002 SHALL be suspended
- **AND** unhealthy health MUST NOT raise or retain C002 for that quiet window

#### Scenario: Quiet ends after session

- **WHEN** the camera program firmware session completes or fails
- **THEN** health probes SHALL resume
- **AND** C002 suppression SHALL end
