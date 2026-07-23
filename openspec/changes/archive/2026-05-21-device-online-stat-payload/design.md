## Context

The Android app already builds a **remote snapshot** via `DeviceStatusPut.packRemoteSnapshot` and sends it in two WebSocket paths:

- **`command.stat_response`**: `payload` = `{ "request_id": <inbound id>, "data": <snapshot> }`
- **`device.online`**: `payload` = `<snapshot>` directly (flat root)

The platform wants connect-time uplink to expose the snapshot under **`payload.stat`**, with **`stat` equal to `command.stat_response` `payload.data`** (not the full stat_response `payload` with `request_id`/`data` wrapper).

## Goals / Non-Goals

**Goals:**

- On each transport open, `device.online` `payload` is `{ "stat": <remote snapshot> }`.
- `payload.stat` deep-equals `command.stat_response` `payload.data` for the same build instant.
- Update specs, docs, and unit tests for the new contract.

**Non-Goals:**

- Changing `command.stat_response` or `command.stat_request` behavior.
- Nesting snapshot under `payload.stat.data` (incorrect; `stat` is the snapshot object itself).
- Duplicating snapshot fields at both `payload` root and `payload.stat`.

## Decisions

1. **`payload.stat` is the remote snapshot object** — Same JSON as `command.stat_response` `payload.data`. **Rationale:** Matches user contract; server reads one snapshot shape at `stat` vs `data` depending on message type.

2. **Remove flat snapshot from `device.online` `payload` root** — **BREAKING**; only `payload.stat` carries snapshot fields.

3. **Shared `buildSnapshotDataMap`** — Used by `sendStatResponse` (`payload.data`) and `sendDeviceOnline` (`payload.stat`).

4. **No change to transport-open timing** — `enqueueDeviceOnlineAfterTransportOpen` unchanged.

## Risks / Trade-offs

- **[Risk] Server reads `payload.stat.data`** → **Mitigation:** Document correct path `payload.stat`; coordinate deploy.
- **[Risk] Flat `payload` consumers break** → **Mitigation:** **BREAKING** note in docs and proposal.

## Migration Plan

1. **Server**: Read snapshot from `device.online` `payload.stat` (same fields as `command.stat_response` `payload.data`).
2. **Device app**: Ship wrapper change.
3. **Rollback**: Revert app + server together.

## Open Questions

- None.
