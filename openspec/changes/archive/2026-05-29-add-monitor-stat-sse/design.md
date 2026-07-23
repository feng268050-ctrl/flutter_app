## Context

The HMI “Monitor → Machine status” screen is driven by in-process cached objects `DeviceStatus` and `DeviceData` (via `MemoryCacheManager`), updating the UI when a change is detected. External LAN clients (e.g. a phone app) currently do not have an equivalent low-latency feed and would need to implement polling and interpretation logic themselves.

This change introduces a device-local SSE endpoint that emits `{ deviceStatus, deviceData }` updates at a 100ms sampling cadence, only when the values change.

## Goals / Non-Goals

**Goals:**

- Provide **LAN-friendly** real-time monitor updates via **SSE** at `GET /v1/monitor/stat`.
- Reuse the **same data semantics** as `command.stat_response` sub-objects `deviceStatus` and `deviceData`.
- Emit updates **only on change**, sampled at **100ms**, to reduce bandwidth and client work.
- Document how the current HMI Monitor screen interprets these fields so external clients can replicate UI behavior.

**Non-Goals:**

- Streaming the full remote snapshot (`staticData`, `deviceInfo`, `warns`, `processParameters`, etc.).
- Providing historical charts, persistence, or “missed events” replay.
- Adding authentication/authorization for the LAN endpoint in this change (security hardening can be a follow-up).
- Adding additional connectivity health signals beyond `deviceStatus`/`deviceData` (e.g. extra per-subsystem probes not already represented on the snapshot model).

## Decisions

### SSE framing and event types

- Use standard SSE response headers (`Content-Type: text/event-stream; charset=utf-8`, `Cache-Control: no-cache`) aligned with existing device-local `/ai` SSE endpoints.
- Emit:
  - `event: stat` for change events with JSON `data`
  - `event: heartbeat` periodically to keep intermediaries and clients alive

Rationale: Consistency with existing SSE usage in this repo and simple client consumption.

### Sampling and change detection

- Sample every **100ms**.
- Compare the newly sampled `{ deviceStatus, deviceData }` against the last emitted sample.
- Only emit `stat` when changed.

Rationale: Meets the user requirement and matches the HMI approach (change-triggered UI updates), while keeping traffic bounded.

Implementation note: `DeviceStatus` and `DeviceData` already have `dataChange(...)` helpers used in HMI; the endpoint can use the same semantics (compare raw fields rather than formatted strings).

### Fan-out and lifecycle

- Maintain a single sampler per logical publisher instance and fan-out to all connected SSE clients.
- On client disconnect, remove subscriber; when no subscribers remain, stop the sampler.

Rationale: Avoid per-client sampling loops and keep CPU stable as clients scale.

### Field mapping for external clients (current HMI Monitor usage)

See `monitor-field-mapping.md` in this change for the full field-by-field mapping, including fields not currently shown by HMI but still present on the wire.

The current “Monitor → Machine status” UI uses these fields/methods:

- **Gauges (from `deviceData`)**
  - **Left gauge**: `deviceData.blowAirPressure` (kPa). Displayed as “Blow pressure”; max used by UI gauge is 1500.
  - **Right gauge**: `deviceData.pumpSourceCurrent` (shown as “A” in gauge; UI max 100).

- **Status checkboxes (derived from `deviceStatus.machineStatusSeg1` bits via methods)**
  - **Laser**: `deviceStatus.isLaserOn()` (Bit0)
  - **Blow / air valve**: `deviceStatus.isAirValveOn()` (Bit4)
  - **Safety lock (ground lock)**: `deviceStatus.isSafetyGroundLockLocked()` (Bit5)
  - **Gun head switch**: `deviceStatus.isGunSwitchOn()` (Bit9)
  - **Red light**: `deviceStatus.isRedLightOn()` (Bit3)
  - **Wire feeding**: `deviceStatus.isWireFeedingOn()` (Bit2)

- **Camera checkbox**
  - Camera comm health is exposed on the snapshot as `deviceStatus.cameraStatus` (int `1` healthy / `0` fault), sourced from the same camera HTTP communication signal used by HMI.

The current “Monitor → Alarm Information” UI uses these fields/methods:

- **Lower-controller readiness gating**
  - HMI considers device “ready/online” only after it has received a valid `DeviceStatus` from the lower controller:
    - `statusReady = (deviceStatus.deviceType != null && deviceStatus.deviceType > 0)`
  - When not ready, the UI avoids showing “all healthy by default” and displays NEUTRAL/gray states instead.

- **Communication status tiles (derived from `DeviceStatus` alarm segments)**
  - **Laser device comm**: `deviceStatus.isLaserCommunicationAlarm()` (from `laserAlarmSeg1` Bit0)
  - **Gun head comm**: `deviceStatus.isGunCommunicationAlarm()` (from `gunAlarmSeg1` Bit0)
  - **Wire feeder comm**: `deviceStatus.isWireFeederCommunicationAlarm()` (from `wireFeederAlarmSeg1` Bit0)
  - **Camera comm**: `deviceStatus.cameraStatus` (int `1` healthy / `0` fault)

  Display semantics in HMI are resolved by `CommStatusDisplay.resolve(emulator, statusReady, commAlarm)`:
  - If `statusReady && !commAlarm` → HEALTHY (green)
  - Else if emulator → NEUTRAL (gray)
  - Else → FAULT (red)

- **Temperature / metric tiles (values from `DeviceData`, fault bits from `DeviceStatus`)**
  - **Gun motor temperature**
    - Value: `deviceData.gunMotorTempRaw` rendered via `deviceData.getGunMotorTempText()`
    - “Has reading”: `deviceData.hasGunMotorTempValue()` (raw > -999)
    - Fault bit: `deviceStatus.isGunMotorOverTemperatureAlarm()` (from `gunAlarmSeg2` Bit0)
  - **Motor driver board temperature**
    - Value: `deviceData.gunDriverBoardTempRaw` rendered via `deviceData.getGunDriverBoardTempText()`
    - “Has reading”: `deviceData.hasGunDriverBoardTempValue()`
    - Fault bit: `deviceStatus.isDriverTemperatureAlarm()` (from `gunAlarmSeg2` Bit1)
  - **Protective lens temperature**
    - Value: `deviceData.protectionBoardTempRaw` rendered via `deviceData.getProtectionBoardTempText()`
    - “Has reading”: `deviceData.hasProtectionBoardTempValue()`
    - Fault bit: `deviceStatus.isProtectionBoardTemperatureAlarm()` (from `gunAlarmSeg2` Bit2)
  - **Collimator / straight track temperature**
    - Value: `deviceData.collimatorTempRaw` rendered via `deviceData.getCollimatorTempText()`
    - “Has reading”: `deviceData.hasCollimatorTempValue()`
    - Fault bit: `deviceStatus.isStraightTrackTemperatureAlarm()` (from `gunAlarmSeg2` Bit3)

  Display semantics in HMI are resolved by `CommStatusDisplay.resolveMetric(ready, hasValue, fault)`:
  - If `!ready || !hasValue` → NEUTRAL (gray)
  - Else if `fault` → FAULT (red)
  - Else → HEALTHY (green)

  Raw temperature special values are encoded in the `*TempRaw` integers:
  - `<= -999` indicates “no sensor / error” and is treated as “no reading” by the UI.

External clients may either:
- Recompute these booleans from `machineStatusSeg1` using the same bit mapping, or
- Use the raw fields directly if mirroring the device JSON model.

## Risks / Trade-offs

- **[CPU/allocations]** Frequent sampling + JSON serialization could allocate heavily → **Mitigation**: change-only emission, shared sampler fan-out, and use raw-field comparisons before serializing.
- **[Slow clients/backpressure]** Writing to a stalled socket can block publisher thread → **Mitigation**: bounded buffering and dropping/closing slow subscribers; write on a dedicated thread.
- **[Inconsistent snapshots]** `deviceStatus` and `deviceData` are cached independently and may update at different instants → **Mitigation**: define emission as “best-effort” snapshot at sampling time; clients should tolerate partial changes.
- **[LAN exposure]** Endpoint accessible on LAN → **Mitigation**: document network expectations; consider follow-up auth/token or binding to trusted interfaces.

