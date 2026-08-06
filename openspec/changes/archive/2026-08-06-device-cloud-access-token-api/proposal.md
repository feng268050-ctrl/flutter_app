## Why

api-server change **`device-access-token-auth`** will require a device `access_token` on existing v1 device HTTP and **`GET /ws/device`** (with a sample-SN allowlist fallback for old firmware). HMI already plans Ed25519 activate + token mint (`device-cloud-ed25519-activate`) but still opens cloud I/O as SN-only. This change wires minted tokens onto those **same v1** cloud interfaces so upgraded units keep working after the server tightens auth.

## What Changes

- **Prerequisite:** Land after **`device-cloud-ed25519-activate`** (local key + activate + token mint) and align with sibling api-server **`device-ed25519-activate`** + **`device-access-token-auth`**.
- After a successful token mint, attach **`Authorization: Bearer <access_token>`** to device cloud calls that the server will gate: WebSocket upgrade, users probe, AI report, storage device mode (presign / STS), and any other in-tree device-facing Worker HTTP that uses SN identity.
- Keep paths on **v1** / **`/ws/device`** — no `/v2` client surface.
- Keep **`POST /v1/devices/:sn/activate`** and **`POST /v1/devices/:sn/token`** without Bearer.
- On **401**, re-mint token (signed) and retry once where safe; do not invent a parallel API version.
- Refresh / cache token for WS reconnects while 云服务 is enabled.

## Capabilities

### New Capabilities

- `device-cloud-access-token-api`: Attach and refresh device Bearer on v1 cloud HTTP/WS after token mint; bootstrap activate/token remain unauthenticated.

### Modified Capabilities

- `device-cloud-http`: Device HTTP clients send Bearer when a token is available.
- `device-cloud-websocket`: `/ws/device` connect includes Bearer when a token is available.
- `device-api-origin-selection`: Document that WS URL path stays `/ws/device`; auth is via upgrade headers, not a new path.

## Impact

- **App cloud stack:** HTTP client + WebSocket factory auth headers; token cache/refresh next to ensure-activated.
- **api-server:** Normative auth owned by `device-access-token-auth` (allowlist is server-side only; HMI that can mint SHOULD always send Bearer).
- **Non-goals:** Implementing Worker routes; maintaining a client-side copy of the sample SN allowlist; changing activate/seal storage (`device-cloud-ed25519-activate`).
