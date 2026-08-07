## Context

ynh960 runs OP-TEE seal TA (`secrets_backend: optee`) with vendor-signed TA. Seal KEK is a 32-byte random AES key. Early designs used OP-TEE REE FS only (`/var/lib/tee` on A/B rootfs, then interim `/userdata/tee`). A/B flips and factory userdata wipe destroy REE FS while Vendor Storage ID **22** (cloud Ed25519 sealed blob) survives → orphan ciphertext / regenerated keys → cloud `FOREIGN KEY CONFLICT`.

Vendor BL32 `rk3568_bl32_v2.15` does **not** register user-TA RPMB FS (`TEE_STORAGE_PRIVATE_RPMB` → `STORAGE_NOT_AVAILABLE`). Supply-chain constraints rule out a BL32 rebuild. Spike (2026-08-07) confirmed `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` works and is deterministic on ynh960.

Cloud constraint: the **Ed25519 seed must not change** across KEK persistence migrate. (Separately: if the seed was already rotated earlier while KEK was lost, cloud admin must clear the old server binding — that is not a Secrets storage bug.)

## Goals / Non-Goals

**Goals:**

- HUK-bound wrap of the seal KEK; persist wrapped blob in Vendor Storage so KEK lifetime matches ID 22 (and other VS-hosted sealed secrets).
- Survive A/B rootfs flip **and** factory userdata wipe without regenerating cloud identity.
- Keep HAL `seal`/`unseal` API and `LWS1` blob format unchanged for callers.
- One-shot migrate from REE FS KEK → VS-wrapped KEK without changing unsealed secrets.

**Non-Goals:**

- Vendor BL32 rebuild / enabling `CFG_RPMB_FS` (deferred until a new BL32 is available).
- Storing plaintext KEK in VS or in REE files.
- Replacing software backend (sim/emu stay on HKDF software KEK).
- Changing cloud activate protocol or VS ID 22 semantics.
- Clearing cloud-side activation after an earlier key rotation (ops/admin).

## Decisions

### D1 — Wrapped KEK in VS (landed)

**Choice:** Keep a random seal KEK inside the TA; wrap it with a HUK-derived key; store only the wrap blob in Vendor Storage ID **23**.

**Why:** Matches VS-hosted sealed blob lifetime without RPMB; OP-TEE remains the seal engine; cloud seed unchanged across flash if wrap survives.

**Rejected:** Software KEK for cloud only; copying REE `dirf.db` into VS; plaintext KEK in VS.

### D2 — Wrap key = `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` (landed, spike PASS)

**Choice:** User TA opens system PTA, derives 32-byte TA-unique key, AES-GCM-wraps the seal KEK. AAD `seal-kek-wrap-v1`; blob magic `LWSK` v1 (65 bytes).

**Spike:** Two derives match; CA `derive-probe` deterministic across invocations. See `notes.md`.

**Rejected for now:** Derive-direct as seal KEK (no ID 23) — kept random KEK + wrap so existing REE KEKs migrate without resealing all consumers.

### D3 — VS ID 23 + helpers (landed)

**Choice:** `VENDOR_SEAL_KEK_WRAPPED_ID=23` / `VENDOR_CUSTOM_ID_17`; `read-seal-kek-wrapped` / `write-seal-kek-wrapped`.

### D4 — Load / sync order (landed)

1. `secrets-seal` / `sync-kek`: if VS wrap present → `kek-import-wrap` into REE FS cache.
2. Else `kek-export-wrap` (load-or-create REE KEK) → write VS.
3. REE FS under `/userdata/tee` is **cache only**, not source of truth.

### D5 — Operator path (landed)

**Choice:** `make migrate-seal-kek` (host SSH) + on-device `secrets-seal sync-kek`. Does **not** regenerate cloud Ed25519. Distinct from `make migrate-secrets` (software→OP-TEE reseal of vault/cloud blobs).

### D6 — Wire format (frozen)

```
magic "LWSK" (4) | version u8=1 | nonce 12 | ciphertext 32 | tag 16
```

AAD: `seal-kek-wrap-v1` (15 bytes).

### D7 — tee-supplicant (landed)

**Choice:** Keep `-f /userdata/tee` and `-r <eMMC CID>` via `tee-supplicant-start.sh` for REE cache + future RPMB readiness. Durable KEK SoT remains VS ID 23.

### D8 — RPMB (deferred)

**Choice:** Do not block product on RPMB. Revisit if/when vendor ships BL32 with `CFG_RPMB_FS=y`.

## Risks / Trade-offs

- [TA UUID or wrap AAD change] → Old VS blob unwrap fails → treat as KEK loss; freeze UUID/AAD.
- [VS wiped on some factory flows] → Same as losing ID 22; re-provision + re-activate.
- [Same-device root] → Can still call seal TA / helpers; residual risk unchanged from OP-TEE model.
- [Earlier key rotation before wrap landed] → Server FOREIGN KEY CONFLICT until admin clears old pubkey; local wrap does not restore the discarded seed.

## Migration Plan

1. ~~Spike derive PTA~~ **Done (PASS).**
2. ~~Helpers + ID 23 + TA/CA wrap~~ **Done.**
3. Field: `make build-secrets-seal` + rootfs upgrade, then `make migrate-seal-kek`.
4. Verify: wipe `/userdata/tee` → unseal ID 22 seed unchanged.
5. Rollback: ignore ID 23; fall back to REE FS if userdata intact.

## Open Questions

- ~~Does `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` work on `rk3568_bl32_v2.15`?~~ → **Yes** (`notes.md`).
- ~~`migrate-secrets` vs separate target?~~ → **`make migrate-seal-kek`**.
- When to enable RPMB if a new BL32 arrives? → Separate change; keep ID 23 until then.
