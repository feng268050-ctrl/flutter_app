## Context

The app persists operator-visible alarms in Room table `warn_table` (`WarnTable`). `DeviceStatusPut.getWarnList` loads the same rows used in `command.stat_response` `payload.data.warns` (first page, localized `content` via `AlarmCodeEnums`). Monitor LAN clients already consume `GET /v1/monitor/stat` via `MonitorStatSseHub` (fan-out, `SseFlushingResponse`, 15s heartbeat). There is no LAN stream for warns; cloud clear is not wired.

On-device clear exists in `WarnLogFragment` → `WarnTableViewModel.deleteAll` but does not consistently notify remote consumers.

## Goals / Non-Goals

**Goals:**

- Expose `GET /v1/monitor/alerts` SSE with `list` on connect, `new` on insert, `clear` on wipe.
- Keep warn JSON identical to `command.stat_response` `warns` entries (`id`, `ymdDate`, `hmDate`, `code`, `content`, `time`, `newTime`, `level` when set).
- Handle `command.clear_alerts` / `command.clear_alerts_ack` on the existing WS dispatcher.
- Single code path for clear (UI + WS) that notifies the alerts SSE hub.

**Non-Goals:**

- Changing warn pagination policy in `stat_response` (still first page / 10 rows).
- Streaming Modbus-derived **live** control-card alarm bits without DB persistence (only persisted `WarnTable` rows).
- Cloud or LAN APIs to delete individual warns by id (full clear only).

## Decisions

1. **Hub pattern mirrors monitor stat**  
   Add `MonitorAlertsSseHub` + `MonitorAlertsHttpPublisher` with the same subscriber queue, `SseFlushingResponse`, and 15s `heartbeat` as `MonitorStatSseHub`.  
   *Alternative:* Piggyback on `/v1/monitor/stat` — rejected; warns change on different cadence and would bloat stat payloads.

2. **Warn snapshot loader shared with stat**  
   Extract or expose a package-visible helper used by `DeviceStatusPut.getWarnList` and the alerts hub’s `list` event so LAN and WS never diverge on localization or query limits.  
   *Alternative:* Duplicate query in the hub — rejected for drift risk.

3. **`list` payload is a JSON array in `data`**  
   First SSE frame: `event: list`, `data: [<WarnTable>, ...]` (same array as `warns` in stat).  
   `event: new`: `data: {<single warn>}` per inserted row after dedupe/insert in `saveWarnTables` / `creationAddOrUpdate` / lens/camera alarm paths.  
   `event: clear`: `data: {}` after `deleteAll` completes.  
   *Alternative:* Wrap in `{ "alerts": [] }` — rejected; user asked for list message shape aligned with stat array.

4. **Change notification via `WarnLogChangedEvent` + typed detail**  
   Extend `WarnLogChangedEvent` (or add a small sealed-style enum: `INSERTED`, `CLEARED`, optional `WarnTable` payload) and post from `WarnTableViewModel` after successful insert batch and after `deleteAll`. Hub subscribes on a background thread via EventBus.  
   *Alternative:* Poll DB every 100ms — rejected; wasteful and misses instant UX.

5. **WS clear command**  
   Register `command.clear_alerts` in `DeviceWebSocketConnectionManager` when session is online; empty `payload` `{}`. Background: `deleteAll`, post clear event, `sendCommandDataAck("command.clear_alerts_ack", ...)`. Gate with same “online” rules as `command.stat_request`.  
   Reuse `sendCommandDataAck` / `sendUploadVideoAck` payload shape.

6. **Route registration**  
   `DeviceLocalHttpServer`: `GET /v1/monitor/alerts` → `serveMonitorAlerts()` alongside `/v1/monitor/stat`.

## Risks / Trade-offs

- **[Risk] `new` events only fire if insert paths post events** → Mitigation: post from `saveWarnTables` (after batch insert), `creationAddOrUpdate`, `saveLensHeavyContaminationWarnLog`, and camera comm alarm save path; unit-test hub reactions.
- **[Risk] `deleteAll` is async without callback today** → Mitigation: run clear on executor and invoke hub + EventBus in the same runnable after `deleteAll` returns.
- **[Risk] Multiple SSE subscribers duplicate work** → Mitigation: one EventBus listener in the hub fan-out to all subscribers (same as stat sampling loop).
- **[Trade-off] `list` still capped at stat page size** → Documented; full history remains HMI pagination only.

## Migration Plan

1. Ship app update; no server migration beyond publishing `command.clear_alerts` when product enables remote clear.
2. LAN clients add optional subscription to `/v1/monitor/alerts`; existing `/v1/monitor/stat` unchanged.
3. Rollback: disable server clear command; endpoint harmless if unused.

## Open Questions

- None blocking implementation; confirm with product whether `clear` should include `request_id` echo for LAN auditing (optional follow-up).
