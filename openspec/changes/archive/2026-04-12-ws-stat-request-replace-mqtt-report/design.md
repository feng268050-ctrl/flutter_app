## Context

Today the app schedules `TimingJobType.MQTT_UP_DEVICE_STATUS` in `LaserApplication.startDeviceCacheDto`: roughly every 60 seconds it packs a `DeviceInfoVo` via `DeviceStatusPut.packVoData`, wraps it in `DeviceInfoMq`, and publishes over MQTT when connected. The device WebSocket already uses a unified JSON envelope (`v`, `type`, `id`, `ts`, `payload`) and handles other `command.*` flows (for example process-parameter delivery and ACKs). The product direction is to shed MQTT responsibilities in favor of WS.

## Goals / Non-Goals

**Goals:**

- On server demand, respond on the device WebSocket with a single snapshot object under `payload.data`, correlated to the inbound command via `payload.request_id`.
- Shape `data` as the same aggregate information previously sent inside the MQTT device-info message **excluding** the `device` property (server-side identity is already bound to the connection / SN).
- Remove the timer-driven MQTT publish for this snapshot; remove dead task wiring (`MQTT_UP_DEVICE_STATUS`) and misleading “MQTT” naming on code paths that are now transport-agnostic.
- Keep local Modbus/cache refresh behavior unchanged except where it existed only to feed the MQTT timer.

**Non-Goals:**

- Removing MQTT entirely from the app or other MQTT message types.
- Changing how `device` identity is represented on the wire for other APIs.
- Defining server-side scheduling of how often to send `command.stat_request` (server policy).

## Decisions

1. **Command names** — Use `command.stat_request` (inbound) and `command.stat_response` (outbound), mirroring the existing `command.*` / `command.*_ack` pattern already used in `DeviceWebSocketConnectionManager`. Rationale: consistent routing and logging with other WS commands; clear pairing by name.

2. **Correlation** — Set `payload.request_id` to the **top-level inbound frame `id`** of `command.stat_request` (same pattern as `command.send_process_param_ack` using `request_id`). Rationale: matches existing envelope spec and server expectations for request tracing.

3. **Snapshot assembly** — Reuse `DeviceStatusPut.packVoData` (or a thin wrapper) to gather `staticData`, `deviceInfo`, `advancedSettings`, `deviceStatus`, `deviceData`, and `warns`. Strip `device` before serialization into `payload.data`. Rationale: one source of truth, minimal behavioral drift from the MQTT-era payload.

4. **Neutral naming** — Introduce a dedicated DTO or rename the aggregate type used for WS export (e.g. `DeviceRemoteSnapshot` or similar) so public field names and class names do not encode MQTT/MQ; migrate `DeviceInfoVo` usage for this path or map VO → snapshot explicitly. Rationale: aligns with migration narrative and avoids implying MQTT is required.

5. **When to respond** — Only send `command.stat_response` when the WS session is online per existing connectivity rules (after valid `connected`); if offline, drop the request with diagnostic logging (same class of behavior as other outbound commands). Optional: skip building payload if Wi-Fi SSID is unknown—**decision**: mirror prior MQTT guard only if product still requires it; prefer documenting in tasks whether to keep the `<unknown ssid>` early return or always respond when WS is up (open for implementer to confirm with product—default toward **always respond when WS online** so server polling is not silent).

6. **Removal of timer** — Delete `startDeviceCacheDto` registration and the `MQTT_UP_DEVICE_STATUS` enum value if unused; remove `DeviceInfoMq` publish from that path. Keep `DeviceInfoMq` / Gson adapters only if still required for inbound MQTT compatibility elsewhere.

## Risks / Trade-offs

- **[Risk] Backend relied on unsolicited MQTT heartbeats** → Mitigation: document **BREAKING** change in release notes; server sends `command.stat_request` on its own cadence.

- **[Risk] Payload size spikes on demand** → Mitigation: same size as before minus `device`; monitor WS max frame limits if any.

- **[Risk] Renaming types breaks Gson or persisted JSON** → Mitigation: WS payload uses explicit DTO fields; do not rename database entities; limit renames to the export DTO and method names.

## Migration Plan

1. Ship app with WS handler + server issuing `command.stat_request`.
2. Deprecate MQTT topic usage for device info in backend once traffic confirms WS responses.
3. Remove client timer in the same change (or same release) so duplicate pushes do not occur.

## Open Questions

- Whether to retain the “no publish when Wi-Fi name unknown” guard for WS responses (see decision 5).
- Exact JSON keys for `data` sub-object: keep Java bean property names (`deviceInfo`, `advancedSettings`, …) for backward compatibility with consumers that parsed MQTT JSON, or snake_case—**default**: preserve existing serialized names unless server contract mandates otherwise.
