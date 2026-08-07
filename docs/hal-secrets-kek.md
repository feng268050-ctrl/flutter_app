# HAL Secrets / KEK — security notes
#
# Change: openspec/changes/hal-secrets-kek-provider
# Follow-up: openspec/changes/huk-wrapped-kek-vendor-storage
# Sibling consumer: wifi-credential-secure-storage (abstract KekProvider only)

## Policy

- **Both backends exist:** OP-TEE seal (`backendId = optee`, `isHardwareBound =
  true`) and device-bound software KEK (`backendId = software_fallback`,
  `isHardwareBound = false`).
- **Selection is OEM `board_profile.json` → `secrets_backend`:**
  - `"software"` — live HW fingerprint → HKDF-SHA256 → AES-256-GCM
  - `"optee"` — `/usr/libexec/board/secrets-seal` + seal TA
- **Current product default (ynh960 OEM + App asset):** `"optee"` (requires
  `keys/oem/vendor_ta.pem`-signed seal TA). Sim/emulator stay on `"software"`.
- When `secrets_backend` is omitted: sim/emu/portable-smoke → software; other
  board ids → optee (legacy heuristic).

## Software KEK (device-bound, nothing secret on disk)

HAL **derives** the KEK at runtime — **no KEK file and no salt file**.

Fingerprint factors (labeled, ordered IKM; blob format **v3**):

| Factor | Source |
|--------|--------|
| Chip / SoC id (required) | `read-serial --chip-id` |
| eth0 MAC | `/sys/class/net/eth0/address` |
| wlan0 MAC | `/sys/class/net/wlan0/address` |
| eMMC/SD CID | `/sys/block/mmcblk*/device/cid` |
| DT serial | `/proc/device-tree/serial-number` (if distinct from chip) |

Seal requires **chip id + at least one other distinct factor**. HKDF uses a
**public** domain-separation salt/info string (`lws-hmi-software-kek-v3`); that
string is not a secret.

**Protects against:** copying sealed blobs alone to another machine / board
(different chip / MAC / CID).
**Does not protect against:** root on the same device (can re-read the same
sysfs/DT values), MAC spoofing on a clone if other factors also match, or
whole-disk+same-SoC identity clones.

## OP-TEE

- Production goal when `keys/oem/vendor_ta.pem` (or `TA_SIGN_KEY=` override /
  pre-signed `.ta`) is available.
- Product images already carry DT optee node, `tee-supplicant`, and seal CA/TA
  build path (`make build-secrets-seal`). Field units reject TAs signed with
  upstream `default_ta.pem` until the vendor key matches BL32.

### KEK storage (lifetime must match sealed blobs)

Sealed blobs that outlive a wipe are useless if the OP-TEE KEK does not.

| Store | Survives A/B | Survives factory userdata wipe | Status on ynh960 |
|-------|--------------|--------------------------------|------------------|
| REE FS on A/B `/var/lib/tee` | no | n/a | **Do not use as SoT** |
| REE FS on `/userdata/tee` | yes | no | **Cache only** |
| HUK-wrapped KEK in Vendor Storage ID **23** | yes | yes | **Source of truth** |
| eMMC RPMB (`TEE_STORAGE_PRIVATE_RPMB`) | yes | yes | Blocked on current BL32 |

**Product path (no BL32 rebuild):** seal TA keeps a random 32-byte AES KEK in
REE FS for fast use; wrap that KEK with a key from
`PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` (HUK + TA UUID); store only the wrap blob
(`LWSK` v1) in Vendor Storage ID **23** via
`read-seal-kek-wrapped` / `write-seal-kek-wrapped`.
`secrets-seal sync-kek` / `make migrate-seal-kek` import/export that blob.
Plaintext KEK MUST NOT appear in VS.

**Spike (2026-08-07):** `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` works on
`rk3568_bl32_v2.15` (see `openspec/changes/huk-wrapped-kek-vendor-storage/notes.md`).
RPMB still returns `STORAGE_NOT_AVAILABLE` for user TAs — not required for this path.

**Cloud Ed25519:** VS ID 22 holds sealed seed. After KEK migrate, the seed MUST
remain identical (`make migrate-seal-kek` does not regenerate keys).

## What this is / is not

- This is a **shared HAL Secrets seal API** for Wi‑Fi PSK vault and future secrets.
- **Cloud Ed25519** (`CloudEd25519Identity`): seals the device cloud private-key
  seed with AAD `cloud-ed25519-v1\\0<product SN>` and stores the opaque blob in
  Vendor Storage ID **22** via board helpers (`read-cloud-ed25519-sealed` /
  `write-cloud-ed25519-sealed`). Emulator / boards without `/dev/vendor_storage`
  fail closed (helpers exit non-zero; App skips activate — no fake prod key).
- This does **not** by itself claim **RED / EN 18031** conformity or complete a
  Notified Body dossier. Technical file work remains outside this repo change.

## Residual risks

| Risk | Mitigation / note |
|------|-------------------|
| Software KEK on product | Explicit `secrets_backend`; multi-factor bind; no secret-on-disk |
| MAC-only spoof | Still need chip (+ preferably eMMC CID); not a TPM |
| DT/`tee-supplicant` missing | Overlay enables optee DT + client + `tee-supplicant.service` |
| Seal TA / CA | `make build-secrets-seal` (default `keys/oem/vendor_ta.pem`) |
| KEK vs blob lifetime | VS ID 23 HUK wrap; REE `/userdata/tee` is cache |
| Same-device root | Can still invoke seal TA / helpers |
| Logging | Implementations MUST NOT log key material or unsealed plaintext at info level |

## Operator / App guidance

- Product App Wi‑Fi UI should not import Secrets; Wi‑Fi HAL internals call
  `BoardBindings.secrets()`.
- Do not store PSKs in plaintext conf — Wi‑Fi vault owns at-rest secrets
  ([`docs/wifi-credential-vault.md`](wifi-credential-vault.md)).
- ynh960 ships `"secrets_backend": "optee"`; keep `keys/oem/vendor_ta.pem` and a
  BL32-matched seal TA in the image. Sim/emulator stay on `software`. To force
  software on a product board, set `"secrets_backend": "software"` in that OEM
  profile and rebuild OEM / upgrade.
- After flipping an in-field unit from software → optee, run
  `make migrate-secrets` (re-seals Wi‑Fi vault + Vendor Storage cloud Ed25519).
  `SCOPE=wifi` / `SCOPE=cloud` limit the pass. Already-OP-TEE blobs are skipped.
- After OP-TEE is in use, run `make migrate-seal-kek` once so ID 23 holds the
  wrap (required before relying on factory flash survival).
