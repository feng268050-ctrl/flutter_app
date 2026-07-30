# app-modbus-live Specification

## Purpose
Product App rules for process-wide Modbus continuous poll ensure versus per-route/per-widget attribute watch subscriptions (interest bound at subscribe time; boot self-check intercept).

## Requirements

### Requirement: Process-wide poll ensure is separate from attribute watches
The product App SHALL expose an ensure path (e.g. `AppServices.ensureModbusLive`) that starts continuous Modbus polling on the shared HAL instance when allowed, and MUST NOT open a process-wide `watchAttributes` subscription or accept a `watchIds` allowlist as part of that ensure. Route-level bootstrap (Home after boot self-check, Monitor, Settings, Demo) MAY call ensure so polling runs even when the entry route is not Home.

#### Scenario: Ensure starts poll without attribute fan-out
- **WHEN** a top-level route calls ensure after intercepts allow
- **THEN** the shared Modbus HAL continuous poll SHALL be started (or left running if already polling)
- **AND** ensure MUST NOT register a shared App broadcast of all attribute changes

#### Scenario: Boot self-check suppresses poll ensure
- **WHEN** boot self-check is active (`BootSelfCheckGate.isActive`)
- **AND** a route or feature calls ensure
- **THEN** continuous polling MUST NOT start until self-check is no longer active
- **AND** self-check SHALL continue to use one-shot attribute reads (not continuous watch) for its snapshot

### Requirement: Live UI surfaces subscribe with their own attribute ids
Each product surface that displays live Modbus fields (including Device Information, Monitor Alarm Information telemetry, and Demo Modbus tiles) SHALL subscribe via HAL `watchAttributes` (or an App façade that passes through to it) with an explicit id list for that surface’s interests. The surface MUST cancel its subscription on dispose. Surfaces MUST NOT rely on filtering a process-wide undifferentiating attribute broadcast as the primary interest mechanism. Surfaces that need communication-fault UI SHALL subscribe to `watchHealth` (or equivalent façade) themselves.

#### Scenario: Monitor alarm telemetry binds ids at subscribe
- **WHEN** Monitor Alarm Information telemetry starts
- **THEN** it SHALL watch with an id list covering gun temperatures, over-temp alarms, and catalog alarms it displays
- **AND** it MUST NOT depend on another screen’s watch allowlist

#### Scenario: Device Information binds device attribute ids
- **WHEN** Device Information starts live Modbus updates
- **THEN** it SHALL watch with ids for the Modbus-backed rows it shows (e.g. control card / laser / wire / gun head fields from the product catalog)
- **AND** disposing the tab SHALL cancel that watch only (poll remains if ensure already started)

#### Scenario: Two surfaces watch concurrently
- **WHEN** Device Information and Monitor Alarm telemetry are both subscribed
- **THEN** the HAL SHALL deliver filtered change lists to each subscriber according to that subscriber’s `ids`
- **AND** there SHALL still be a single continuous poll scheduler on the shared HAL instance

### Requirement: Remote live cache may watch continuous groups for LAN/cloud snapshot
The product App MAY run **one** App-owned live cache (e.g. `DeviceRemoteLiveCache`) that subscribes via `watchAttributes` with an **explicit** id list covering all attributes in continuous Modbus groups (`status` and `data`) for LAN Monitor SSE and/or remote snapshot reuse. That cache MUST NOT replace per-UI-surface narrow id watches. Its lifecycle MUST be bound to cloud/LAN runtime (not to `ensureModbusLive`). It MUST NOT call `readGroup` / on-demand register reads on a fixed SSE sample timer. A one-shot `readGroup('status')` / `readGroup('data')` (or equivalent) **at cache start** to seed the attr maps before the first SSE publish is ALLOWED and SHOULD be used so the first `deviceData` is not a sparse partial. Mapping HAL attrs → wire `deviceStatus` / `deviceData` MUST use the shared packer that emits lws-ui camelCase and register-scale `*TempRaw` (see `device-local-http-api`). Multiple UI watches and the live cache MAY coexist on the same HAL continuous poll.

#### Scenario: Live cache and Monitor UI watch together
- **WHEN** Monitor Machine Status is subscribed with a narrow id list
- **AND** the remote live cache is subscribed with full continuous `status`+`data` ids
- **THEN** both subscriptions SHALL receive filtered change lists from the single continuous poll
- **AND** Monitor SSE `stat` updates MUST follow live-cache mapped changes (not a second Modbus poll)

#### Scenario: Live cache seeds data group at start
- **WHEN** the remote live cache starts
- **THEN** it SHOULD populate `status` and `data` attr maps from a one-shot group read (or an equivalent full prime) before or with the first Monitor SSE `stat`
- **AND** subsequent updates MUST still come from `watchAttributes` / health (not a 100 ms sample timer)
