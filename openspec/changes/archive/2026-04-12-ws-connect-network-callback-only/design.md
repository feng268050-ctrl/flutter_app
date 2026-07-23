## Context

Today `DeviceWebSocketConnectionManager.connectOrReconnect` is invoked from:

1. `LaserApplication.initDeviceCloudConnection()` with reason `app_startup` (during hardware/bootstrap thread work).
2. `NetworkCallback.onAvailable` with reason `network_available`.

`connectOrReconnect` is `synchronized` and includes a **same-target + CONNECTING/ONLINE** early return to skip “duplicate” connects. That pattern largely compensates for the dual call sites.

## Goals / Non-Goals

**Goals:**

- Establish **one external policy** for when to *start* or *retry after outage*: **network availability signaling** via `ConnectivityManager.NetworkCallback`.
- Reduce moving parts in `DeviceWebSocketConnectionManager` by removing dedup logic that exists only to reconcile redundant callers.
- Keep existing transport behavior (URL selection, backoff on failure, `connectionGeneration` stale-listener guard, online gating) unless a task proves they must change.

**Non-Goals:**

- Reworking WebSocket URL selection, envelope protocol, heartbeat, or command handling.
- Removing internal `scheduleReconnect("backoff_retry")` / failure-driven reconnect (still required when the socket drops while network remains “available”).
- Changing MQTT bootstrap in `NetworkCallback` (out of scope unless a compile coupling appears).

## Decisions

1. **Single external connect trigger**  
   **Decision**: Remove the `app_startup` `connectOrReconnect` invocation from `LaserApplication` (or delete `initDeviceCloudConnection` if it becomes empty).  
   **Rationale**: `registerNetworkCallback` on a matching active network should deliver `onAvailable`, covering “network already up before app starts” in the common case.  
   **Alternative considered**: Keep startup connect as “belt and suspenders” for rare OEM callback quirks — rejected here per product request to simplify.

2. **Duplicate-connect short-circuit**  
   **Decision**: After removing the startup call, **delete** the `sameTarget && (CONNECTING || ONLINE)` skip block **if** manual review shows the remaining external overlap is only `onAvailable` racing with scheduled `backoff_retry`, and `synchronized` + cancel/replace semantics are sufficient.  
   **Rationale**: User asked to remove “unnecessary” dedup; that block is the main candidate.  
   **Alternative considered**: Keep a minimal skip to avoid canceling an in-flight handshake when two triggers fire in the same millisecond — adopt this only if testing shows visible connect churn or regressions.

3. **Cold start without `onAvailable`**  
   **Decision**: Accept as **out of scope hardening** unless product demands it; document in risks. If QA finds a device that never calls `onAvailable` after registration while offline→online, a follow-up change could add a one-shot `registerNetworkCallback` post-condition probe (not in this change unless tasks expand).

## Risks / Trade-offs

- **[Risk] OEM/network stack never emits `onAvailable` for an already-up network** → WS never connects until a network transition. **Mitigation**: Device lab matrix; if hit, reintroduce a narrow bootstrap probe (not full duplicate `connectOrReconnect` from two places without design).

- **[Risk] Removing skip block increases connect churn** (cancel/replace during CONNECTING). **Mitigation**: Revert to minimal skip or widen tests; watch logs for `device_ws replacing existing connection`.

- **[Risk] Timing**: Features that assumed WS connect begins before `NetworkCallback` registration completes may shift slightly later. **Mitigation**: Grep for ordering assumptions; adjust tests.

## Migration Plan

1. Ship app update; monitor WS online rate and time-to-first-`device.online`.
2. Rollback: restore `app_startup` connect and/or skip block.

## Open Questions

- None for proposal scope; OEM callback matrix is empirical QA.
