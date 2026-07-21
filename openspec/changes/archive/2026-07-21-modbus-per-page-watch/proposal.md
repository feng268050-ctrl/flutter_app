## Why

The App currently funnels all Modbus attribute changes through a single `AppServices` broadcast (`ensureModbusLive` → one HAL watch → fan-out). Pages then filter in callbacks with `switch (c.id)`, while also optionally passing `watchIds` that only widen a process-wide allowlist. That fights the HAL model: `watchAttributes(ids:)` is meant for **per-subscriber** interest. Refactor now so continuous poll stays process-wide and each UI surface binds its interest at subscribe time.

## What Changes

- **`ensureModbusLive` / route bootstrap**: only ensure continuous `startPolling` (plus existing intercepts: capability / boot self-check). No shared attribute watch, no `watchIds` on ensure.
- **Per-page (or per-feature) subscriptions**: Device Information, Monitor Alarm telemetry, Demo (and any future consumer) call `watchAttributes(ids: …)` (via `ModbusRtuClient` / HAL) with **that surface’s** attribute id list, and cancel on dispose.
- **Health**: subscribers that need C001-class UI call `watchHealth()` themselves (or a thin App helper that does not merge attribute streams).
- **Remove / shrink**: process-wide `modbusAttributeChanges` broadcast as the primary product path; `startLiveDemo`’s “one watch + optional watchIds widen” pattern; App-level pending-watchIds merge for ensure.
- HAL `ModbusHal` API unchanged in shape; App usage aligned with multi-subscriber watch.

## Capabilities

### New Capabilities

- `app-modbus-live`: Product App rules for process-wide Modbus poll ensure vs per-route/per-widget attribute watch subscriptions (ids bound at subscribe time; boot self-check intercept).

### Modified Capabilities

- `hal-modbus-config`: Clarify that multiple concurrent `watchAttributes` subscribers MAY each pass distinct `ids`, and App MUST NOT replace that with a single undifferentiating fan-out as the long-term product pattern for multi-screen live UI.

## Impact

- `app/hmi/lib/app/app_services.dart` — slim `ensureModbusLive`; drop attribute/health broadcast as primary API (or keep health-only if useful).
- `app/hmi/lib/modbus/modbus_rtu_client.dart` — replace/repurpose `startLiveDemo`; expose watch-with-ids helpers.
- `gun_alarm_telemetry.dart`, `device_information_tab.dart`, `p2_demo_page.dart` — subscribe with explicit id lists; dispose cancels own watches.
- Home / Monitor / Settings route `scheduleEnsureModbusLive` — poll-only ensure remains.
- Boot self-check — still one-shot `readAttribute`; still suppresses poll until dialog completes.
- Tests: navigation / Monitor / Device Info / Demo Modbus wiring.
- Docs: OpenSpec deltas; brief App comment on route ensure vs page watch.
