## Context

The Android app already builds a **remote snapshot** via `DeviceStatusPut.packRemoteSnapshot(Context)` and sends it inside `command.stat_response` as `payload.data`. Today, **online** is incorrectly tied to an inbound **`connected`** frame in code, but that message is **not** otherwise used to drive product logic beyond gating—so the plan is to **delete `connected` as a lifecycle prerequisite** and align specs and implementation with **transport-open** readiness.

Product expectation: the **user’s companion app** should see current device telemetry/parameters as soon as the device’s WebSocket is up; **`device.online`** must fire **immediately** after connect/reconnect, with **no** dependency on any inbound application message.

## Goals / Non-Goals

**Goals:**

- Define **online** = WebSocket **transport successfully opened** on the active `/ws/device` session (ready to send frames).
- On each **transport open** (including reconnect), **immediately** attempt to push `device.online` with the current remote snapshot as the full `payload` object (same semantics as `command.stat_response`’s `payload.data`).
- **Remove** normative and implementation reliance on inbound **`connected`**; remove **`connected`** from the unified-envelope spec as a required server message type.
- Keep one snapshot serialization path shared with `command.stat_response`.

**Non-Goals:**

- Redesigning heartbeat, `command.stat_request`, or MQTT.
- Preserving backward compatibility where the device must still wait for `connected` (explicit **BREAKING** coordinated rollout).

## Decisions

1. **Message type and payload shape** — Unchanged: outbound `device.online`, `payload` = remote snapshot JSON object.

2. **Lifecycle trigger** — **`device.online`** and **online state** are tied to **WebSocket `onOpen`** (OkHttp listener equivalent), **not** inbound `connected`. **Rationale:** meets “immediate, no prerequisite message”; matches user direction that `connected` was effectively unused for real product behavior.

3. **Inbound `connected` after rollout** — If legacy servers still send `connected`, the device **MAY** log-and-ignore or drop without affecting state (optional compatibility shims); normative contract no longer includes `connected`.

4. **Async snapshot build** — Keep building `packRemoteSnapshot` on a **background executor** and send when ready, but **enqueue immediately** from the transport-open path so work starts with zero wait for server text. **Rationale:** avoid blocking `onOpen`; snapshot may be heavy.

5. **Backoff reset** — Reset reconnect attempt counter on **transport open** (replacing “after `connected`”).

6. **Alternatives considered** — Keeping `connected` only for correlation (`connection_id`): rejected for this change because the user requested removal of `connected` dependency and contract surface.

## Risks / Trade-offs

- **[Risk] Server still gates its own logic on `connected`** — Mitigation: coordinated deploy; document **BREAKING**; server stops sending `connected` or treats device as live on first `device.online` / TCP session.
- **[Risk] Auth not complete at `onOpen`** — Mitigation: today’s auth is largely on the HTTP upgrade; if product discovers races, revisit (e.g. first successful send ack)—out of scope unless observed.
- **[Risk] Larger frame at open** — Same as before; unchanged mitigation.

## Migration Plan

1. Deploy **server** changes: treat device session as active on transport open + first `device.online`; **stop sending** `connected` per new envelope spec (or phase out).
2. Ship **device** app: transport-open online + immediate `device.online`; remove `connected`-based online transition.
3. Rollback: revert device and/or re-enable server `connected` only if both sides agree on legacy mode.

## Open Questions

- Whether any **server-side** feature depended on **`connection_id`** only present in `connected`—if yes, move that identifier to another channel (e.g. first server→device frame or URL) in a follow-up change.
