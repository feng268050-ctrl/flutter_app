# HAL Secrets / KEK — security notes
#
# Change: openspec/changes/hal-secrets-kek-provider
# Sibling consumer: wifi-credential-secure-storage (abstract KekProvider only)

## Policy

- **Both backends exist:** OP-TEE seal (`backendId = optee`, `isHardwareBound =
  true`) and device-bound software KEK (`backendId = software_fallback`,
  `isHardwareBound = false`).
- **Selection is OEM `board_profile.json` → `secrets_backend`:**
  - `"software"` — live HW fingerprint → HKDF-SHA256 → AES-256-GCM
  - `"optee"` — `/usr/libexec/hmi/secrets-seal` + seal TA
- **Current product default (ynh960 OEM + App asset):** `"software"` until
  Innohi provides a matching TA signing key; switch to `"optee"` by editing the
  board profile only (no App code change).
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

- Production goal when vendor `TA_SIGN_KEY` (or signed `.ta`) is available.
- Product images already carry DT optee node, `tee-supplicant`, and seal CA/TA
  build path (`make build-secrets-seal`). Field units reject TAs signed with
  upstream `default_ta.pem` until the vendor key matches BL32.

## What this is / is not

- This is a **shared HAL Secrets seal API** for Wi‑Fi PSK vault and future secrets.
- This does **not** by itself claim **RED / EN 18031** conformity or complete a
  Notified Body dossier. Technical file work remains outside this repo change.

## Residual risks

| Risk | Mitigation / note |
|------|-------------------|
| Software KEK on product | Explicit `secrets_backend`; multi-factor bind; no secret-on-disk |
| MAC-only spoof | Still need chip (+ preferably eMMC CID); not a TPM |
| DT/`tee-supplicant` missing | Overlay enables optee DT + client + `tee-supplicant.service` |
| Seal TA / CA | `make build-secrets-seal`; field units need vendor `TA_SIGN_KEY` |
| Logging | Implementations MUST NOT log key material or unsealed plaintext at info level |

## Operator / App guidance

- Product App Wi‑Fi UI should not import Secrets; Wi‑Fi HAL internals call
  `BoardBindings.secrets()`.
- Do not store PSKs in plaintext conf once vault lands (sibling change).
- To enable OP-TEE later: set `"secrets_backend": "optee"` in
  `oem/boards/<id>/board_profile.json`, rebuild OEM / upgrade, and provision a
  BL32-matched seal TA.
