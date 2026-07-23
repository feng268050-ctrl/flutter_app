## Why

The app still pushes a periodic aggregate device snapshot over MQTT (`DeviceInfoMq` on a 60s timer), which couples telemetry to MQTT and duplicates what we want to drive through the device WebSocket. We need on-demand snapshots initiated by the server over WS so we can retire MQTT for this path and align with the broader goal of replacing MQTT with WS incrementally.

## What Changes

- Handle inbound unified-envelope frames with `type` `command.stat_request` on the device WebSocket; reply with `command.stat_response` whose `payload` is `{ "request_id": "<inbound top-level id>", "data": <object> }`.
- Build `data` from the same sources as today’s packed snapshot (via `DeviceStatusPut.packVoData` and related assembly), but **omit** the `device` field that existed on the legacy MQTT-oriented aggregate; serialize the remainder as the `data` object (neutral naming in code and types—no MQTT/MQ prefixes for this structure).
- **Remove** the periodic MQTT publish path: `LaserApplication.startDeviceCacheDto` / `TimingJobType.MQTT_UP_DEVICE_STATUS` and any wiring that exists only to push that message on a timer.
- Rename or replace types/methods that exist only for “MQTT device info” wording where they describe this aggregate (e.g. VO/DTO naming, `applyInstalledAppVersionForMqtt`-style helpers) so the snapshot is channel-agnostic.

## Capabilities

### New Capabilities

- `device-remote-snapshot`: Defines the neutral aggregate device snapshot (`data`) the app exposes to the backend—same information as the former packed VO minus `device`, independent of transport (WS today; not named after MQTT).

### Modified Capabilities

- `device-ws-unified-envelope`: Add normative requirements for `command.stat_request` (inbound) and `command.stat_response` (outbound), including correlation via `request_id` and placement of business fields under `payload` per the unified envelope.

## Impact

- **App**: `DeviceWebSocketConnectionManager` (or equivalent WS dispatcher), snapshot assembly (`DeviceStatusPut`, DTOs), `LaserApplication` init path, `TimingJobTaskManager` / `TimingJobType`, MQTT publish usage for device info.
- **Backend / ops**: **BREAKING** for any workflow that depended solely on unsolicited ~60s MQTT device-info messages; the server must request snapshots via WS `command.stat_request` (or use other existing channels) to obtain the same data on demand.
