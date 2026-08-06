## Context

Factory flow already registers devices via api-server admin APIs (`POST /v1/admin/devices`) so the SN exists in `device` with `is_activated = 0`. Vendor Storage holds per-unit `brand` / `model` / `sn` and survives `make flash` when vendor payloads are omitted. HAL Secrets can seal arbitrary plaintext with AAD (OP-TEE or software KEK). Cloud services on the HMI are operator-gated (云服务). Device WebSocket today admits by registered SN only.

Sibling change lives in `../api-server` OpenSpec (device activate + Ed25519 token mint). Wire contracts must stay aligned.

## Goals / Non-Goals

**Goals:**

- First-online Ed25519 keypair generation when no sealed cloud private key exists in Vendor Storage.
- Seal private key with Secrets; AAD binds purpose + product SN; store sealed blob in Vendor Storage under a frozen custom ID.
- Call activate once with SN + public key; locally refuse regenerate after sealed blob exists.
- Sign access-token mint requests with the private key; receive token over TLS (no device-pubkey encryption of the token).
- Survive factory flash / rootfs upgrade without re-activation when the sealed blob remains.

**Non-Goals:**

- Factory-side public-key provisioning or HSM-injected device keys.
- Replacing SN-only `GET /ws/device` admission in this change (follow-up MAY require device JWT).
- Encrypting tokens or payloads with Ed25519 (impossible / wrong tool).
- Emulator full Vendor Storage parity (fail closed or documented stub; no fake activate against prod).
- Admin “reset activation” UX on device (server-side after-sales only).

## Decisions

### D1 — Algorithm: Ed25519 only

- **Choice:** One Ed25519 keypair for device identity signatures.
- **Why:** Fits “sign to prove device”; small keys; sealed blob trivially fits Vendor Storage.
- **Alternatives:** RSA (sign+encrypt with one key — rejected); dual Ed25519+X25519 (deferred until a real need for device-pubkey encryption/ECDH).

### D2 — Storage: Secrets seal → Vendor Storage (not userdata)

- **Choice:** Sealed private key blob in Vendor Storage custom ID **22** (`VENDOR_CUSTOM_ID_16`); plaintext never on disk.
- **AAD:** stable UTF-8 string including purpose `cloud-ed25519-v1` and the product SN used at seal time.
- **Why:** Flash-surviving shell + device-bound seal (chip/TEE), matching Wi‑Fi vault pattern but with VS durability.
- **Alternatives:** userdata only (weaker across factory flash); OP-TEE secure storage alone (harder to inspect/migrate; still need flash story).

### D3 — Lifecycle order (crash-safe)

1. Require non-empty Vendor Storage product SN (else abort; do not invent SN).
2. If sealed blob present → load/unseal → skip generate/activate (may still mint token).
3. Else generate keypair → **seal + write VS first** → POST activate with same public key.
4. On activate success → done. On activate failure → keep sealed key; retry activate with **same** pubkey (never rotate on retry).
5. If server returns “already activated” with matching key → treat as success. If already activated with **different** key → fail closed (after-sales).

### D4 — Wire formats (align with api-server)

- Public key: **base64** (standard) of the raw **32-byte** Ed25519 public key.
- Activate: `POST /v1/devices/:sn/activate` body `{ "public_key": "<base64>" }` (snake_case; ApiResult). No user JWT; device-facing.
- Token mint (same capability): device signs a canonical message (SN + timestamp/nonce per server spec); server verifies with stored pubkey and returns `access_token` over TLS.
- Issued JWT (server-signed with platform `JWT_SECRET`; HMI treats as opaque Bearer): claims `{ typ: "device", sn, sub: sn, exp }`; TTL matches user default (`expireMinutes = 30000`). Client MAY read **`exp`** for proactive refresh; MUST NOT decrypt with the device key.

### D5 — Gating

- Run ensure-activated only when 云服务 is enabled, a suitable network exists, and an API origin is pinned.
- Do not block local HMI features on cloud activation failure (surface/log; retry with backoff).

### D6 — Cross-repo

- Normative HTTP shapes owned by api-server OpenSpec change `device-ed25519-activate`.
- This repo’s tasks include a contract checklist against that change’s specs before App wiring.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Activate succeeds, local VS write already done but App crashes before marking UX “done” | Retry activate with same key; server idempotent for same pubkey |
| VS write fails after generate | Do not call activate until VS write succeeds |
| Software KEK: root on same device can unseal | Accepted residual (same as Wi‑Fi vault); prefer OP-TEE when vendor TA key available |
| Lost sealed key / wiped VS after server activated | Cannot self-heal; needs server-side reset — document |
| SN FORCE rewrite vs sealed AAD | Refuse cloud key use / require explicit after-sales path; do not auto-reseal under new SN |
| Emulator without VS | Skip activate; clear error if forced |

## Migration Plan

1. Land api-server activate + pubkey column + token mint.
2. Land HMI VS ID + seal helpers + ensure-activated in cloud runtime.
3. Existing field devices: remain `is_activated=0` until first online with new firmware.
4. Rollback: disable ensure-activated client path; server can leave unused pubkey columns.

## Open Questions

- ~~Exact token-mint signed-message canonicalization details → finalize in api-server design; HMI mirrors.~~ **Frozen** (api-server `device-ed25519-activate` main spec, 2026-08-05 archive):
  - Activate: `POST /v1/devices/:sn/activate` body `{ "public_key": "<base64 32 raw bytes>" }`; unknown SN → `404`; bad key length → `400`; same key retry → `200`; different key → `409` `DEVICE_ALREADY_ACTIVATED`.
  - Token: `POST /v1/devices/:sn/token` body `{ "ts", "nonce", "signature" }` over UTF-8 `ed25519-token-v1\n<sn>\n<ts>\n<nonce>`; skew ≤ 300s; `data.access_token` is platform HS512 JWT (`typ: "device"`, `sn`/`sub`, `exp`; TTL `expireMinutes = 30000`).
