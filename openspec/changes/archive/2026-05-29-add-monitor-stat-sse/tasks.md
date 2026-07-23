## 1. Spec and documentation alignment

- [x] 1.1 Add `device-local-http-monitor-stat-sse` to the global local-HTTP API reference (link the route, headers, and SSE event types)
- [x] 1.2 Add a dedicated external-client document describing Monitor field meanings (include both used and unused fields, derived from code comments); place it at `openspec/changes/add-monitor-stat-sse/monitor-field-mapping.md`

## 2. SSE endpoint implementation (device local HTTP)

- [x] 2.1 Add `GET /v1/monitor/stat` route to `DeviceLocalHttpServer`
- [x] 2.2 Implement monitor stat SSE publisher that writes proper SSE frames and headers
- [x] 2.3 Implement 100ms sampling loop that reads the latest `DeviceStatus` / `DeviceData`
- [x] 2.4 Implement change detection and ensure `event: stat` is emitted only when changed
- [x] 2.5 Add `event: heartbeat` at least every 15 seconds while connected
- [x] 2.6 Implement subscriber fan-out (single sampler loop; multiple clients receive same events)
- [x] 2.7 Handle disconnect cleanup (stop sampler when no subscribers; close streams)
- [x] 2.8 Define and enforce behavior for slow/stalled clients (bounded buffering and drop/close strategy)

## 3. Payload and model correctness

- [x] 3.1 Ensure JSON payload uses `{ "deviceStatus": <obj|null>, "deviceData": <obj|null> }`
- [x] 3.2 Ensure `deviceStatus` and `deviceData` JSON shapes match `command.stat_response` snapshot objects for the same app version
- [x] 3.3 Ensure comparisons use raw-field semantics (avoid formatted string helpers); reuse existing `dataChange(...)` where appropriate
- [x] 3.4 Add `deviceStatus.cameraStatus` (0/1) to the shared snapshot used by `command.stat_response` and LAN monitor consumers, sourced from camera comm health

## 4. Tests and verification

- [x] 4.1 Add unit/integration tests for SSE framing (event/data lines + blank separator) and headers
- [x] 4.2 Add tests for change-only emission (unchanged inputs produce no `stat` events)
- [x] 4.3 Add tests for 100ms sampling cadence behavior (allowing scheduler tolerance)
- [x] 4.4 Manual verification: connect via `curl -N` and observe `stat` and `heartbeat` events under real device state changes
