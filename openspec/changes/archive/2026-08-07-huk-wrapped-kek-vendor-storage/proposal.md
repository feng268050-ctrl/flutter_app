## Why

OP-TEE seal KEK lived only in REE FS (`/var/lib/tee` or `/userdata/tee`). A/B rootfs flips and factory userdata wipe destroy that store while Vendor Storage still holds sealed cloud Ed25519 (ID 22). Orphan ciphertext cannot be unsealed; regenerating the Ed25519 key breaks cloud activation (server still binds the old pubkey). Vendor BL32 does not expose user-TA RPMB FS, and a BL32 rebuild is not obtainable through the supply chain. We need a HUK-bound KEK persistence path whose lifetime matches VS-hosted secrets **without** changing BL32.

## What Changes

- Persist the OP-TEE **seal KEK** as a **HUK-wrapped** opaque blob in Vendor Storage ID **23**, not as plaintext and not only under REE FS.
- Extend seal TA + CA (`kek-export-wrap` / `kek-import-wrap`); `secrets-seal sync-kek` keeps REE cache aligned with VS.
- Board helpers + ID map for the wrapped-KEK slot.
- `make migrate-seal-kek` for field units (does **not** change cloud Ed25519 seed).
- Docs: VS-wrapped KEK is the product persistence story; REE `/userdata/tee` is cache; RPMB deferred.
- **Not BREAKING** for HAL seal/unseal API shape; opaque blob magics (`LWS1` / `LWSS`) unchanged.

## Capabilities

### New Capabilities

- (none — persistence is an extension of existing Secrets / Vendor Storage capabilities)

### Modified Capabilities

- `hal-secrets-kek`: OP-TEE KEK SHALL be recoverable across A/B and factory userdata wipe via HUK-wrapped material in Vendor Storage; plaintext KEK MUST NOT appear in VS or REE files as durable SoT.
- `vendor-storage-identity`: frozen ID **23** for the HUK-wrapped seal KEK blob; helpers and size caps.

## Impact

- `native/secrets_seal/` (TA wrap/unwrap; CA commands)
- Overlay board helpers + `board/vendor-storage-ids.txt`
- `scripts/migrate-seal-kek.sh`, Makefile, docs/AGENTS
- `tee-supplicant` keeps `/userdata/tee` as cache only
- On-device smoke: wrap → VS → wipe REE FS → unseal same cloud seed (**verified**)
