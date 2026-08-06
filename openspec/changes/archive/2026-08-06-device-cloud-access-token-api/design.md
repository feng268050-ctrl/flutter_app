## Context

HMI cloud stack already pins a Worker origin and calls:

- `GET /ws/device?sn=`
- `GET /v1/devices/:sn/users`
- `POST /v1/devices/:sn/ai-report`
- `POST /v1/storage/r2/sts` (device mode) + object upload
- (and related device HTTP as implemented)

`device-cloud-ed25519-activate` will mint `access_token`. api-server `device-access-token-auth` will require that token on those surfaces for non-allowlisted SNs. This change only updates the **client** to send Bearer on the **existing v1** URLs.

## Goals / Non-Goals

**Goals:**

- Obtain/cache device `access_token` via activate change’s token mint before gated cloud I/O.
- Attach `Authorization: Bearer` on device WS upgrade and device Worker HTTP.
- Stay on `/ws/device` and `/v1/...` paths.
- Retry once on auth failure by re-minting token.

**Non-Goals:**

- Client-side sample SN allowlist (server owns fallback for old firmware).
- `/v2` paths.
- Re-implementing Ed25519 seal/activate (owned by `device-cloud-ed25519-activate`).
- Changing WS application envelope/commands.

## Decisions

### D0 — Ordering

1. `device-cloud-ed25519-activate` ensure-activated + token mint available.
2. api-server activate + `device-access-token-auth` deployed (or contract frozen).
3. This change wires Bearer on cloud clients.

### D1 — Always send Bearer when token can be minted

**Choice:** If 云服务 is on and the device can mint (sealed key / activated), the HMI **SHALL** send Bearer on gated calls—even if the SN is on the server allowlist.

**Why:** Matches server rule “token present → verify”; avoids half-upgraded clients relying on SN-only forever.

**Rejected:** Client allowlist mirroring server samples.

### D2 — Token cache + refresh

- Cache `access_token` in memory (and optionally short-lived secure prefs if product already does); do not log the token.
- Treat the token as **opaque** aside from standard JWT **`exp`** (do not require client logic on `typ` / `sn`).
- Server contract (api-server `device-ed25519-activate`): claims `{ typ: "device", sn, sub: sn, exp }`; TTL = user default **`expireMinutes = 30000`**.
- Refresh when missing, near `exp` (proactive skew: e.g. refresh when remaining lifetime < 5% or < 1 hour, whichever is simpler to implement), or after **401** on a gated call.
- Re-mint uses `POST /v1/devices/:sn/token` with Ed25519 signature (no Bearer on mint).
- After refresh, retry the failed HTTP once; for WS, close and reconnect with new header.

### D3 — Where to attach

| Call | Auth |
|------|------|
| `POST .../activate`, `POST .../token` | No Bearer |
| `GET /ws/device` | Bearer on upgrade request |
| `GET /v1/devices/:sn/users` | Bearer |
| `POST /v1/devices/:sn/ai-report` | Bearer |
| `POST /v1/storage/r2/sts` (device) | Bearer |
| Presign device mode if used | Bearer |
| Other device-SN Worker HTTP added later | Same helper |

Shared helper: `deviceCloudAuthHeaders()` / interceptor on the cloud HTTP stack + WS factory.

### D4 — Path stability

WS URL construction in `device-api-origin-selection` stays `/ws/device?sn=...`. Auth is header-only.

### D5 — Error classification

- **401** after mint+retry → treat as auth failure (surface/log; do not spin forever).
- Existing **`INVALID_SN`** / registration UX classification remains for true SN problems; distinguish token-required failures from INVALID_SN when `errorCode` differs (per api-server codes once published).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Server ships auth before HMI Bearer | Sample allowlist covers current field units; new builds must ship together |
| Token TTL shorter than WS session | Refresh-on-401 + reconnect; proactive refresh if TTL known |
| Race: WS connect before first mint | Gate connect on ensure-activated + mint success when 云服务 on |

## Migration Plan

1. Land activate (both repos) + server `device-access-token-auth`.
2. Ship this HMI change so new firmware always sends Bearer.
3. Old sample builds keep working via server allowlist until OTA.

## Open Questions

- Whether WS libraries used on Linux need a specific header API for Bearer (spike in tasks if unclear).
