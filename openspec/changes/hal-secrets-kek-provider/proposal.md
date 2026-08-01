## Why

Encrypted vaults (Wi‑Fi PSK and future secrets) need a shared, **hardware-bound** KEK / seal API. Without it, each feature invents ad-hoc crypto and cannot meet a single production-grade Secure Storage Mechanism story (RED / EN 18031 technical file). A thin HAL Secrets layer (not a desktop Keychain) is the reusable foundation.

## What Changes

- Add `cyber_hal` **Secrets / KekProvider** abstraction: seal/unseal (or wrap/unwrap DEK) with associated data; never log key material
- **Production standard = hardware:** OP-TEE (PKCS#11 TA via `libckteec` and/or small custom TA + HUK-derived secure storage; **RPMB** when available) is the **required** backend on real boards
- **No bring-up / production split:** product and field images use the same hardware path; there is no “interim production” software KEK mode
- **Software KEK only as fallback** when hardware TEE is unavailable (e.g. **emulator / host unit tests** / explicit sim board profile) — queryable backend id; must not be the default on ynh960/961/962 hardware images
- Auto-select: try OP-TEE first; fall back to software only when TEE probe fails (or profile is sim/emulator)
- Overlay/Buildroot enablement for `tee-supplicant` / OP-TEE client on product images
- Spike notes on ynh960 OP-TEE/HUK/RPMB; no desktop keyring

## Capabilities

### New Capabilities
- `hal-secrets-kek`: HAL Secrets/KEK API; hardware-first OP-TEE backend; software fallback only when hardware unavailable; logging/threat-model constraints

### Modified Capabilities
- `dart-hal`: Board bindings / profile expose Secrets provider (hardware default on appliance boards)

## Impact

- `packages/cyber_hal`: secrets module + bindings; FFI or native helper to `libteec` / PKCS#11
- Overlay / Buildroot: OP-TEE client + `tee-supplicant` on product images (not optional “later”)
- Consumers: `wifi-credential-secure-storage` and later secrets call abstract API only
- Emulator (`sim_virt` / QEMU): software fallback allowed
- Docs: hardware-first policy; software fallback scope; does not by itself claim RED conformity
- Sibling: `wifi-credential-secure-storage` depends on this for KEK
