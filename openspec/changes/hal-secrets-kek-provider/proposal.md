## Why

Encrypted vaults (Wi‑Fi PSK and future secrets) need a shared, hardware-bound **KEK / seal API**. Without it, each feature invents ad-hoc crypto, and interim software-only keys cannot graduate to an OP-TEE-backed Secure Storage Mechanism for RED / EN 18031 technical files. A thin HAL Secrets layer (not a desktop Keychain) is the reusable foundation.

## What Changes

- Add `cyber_hal` **Secrets / KekProvider** abstraction: seal/unseal (or wrap/unwrap DEK) with associated data; never log key material
- **Preferred backend:** OP-TEE (PKCS#11 TA via `libckteec` and/or small custom TA + secure storage, HUK-derived; RPMB when available)
- **Interim backend:** software device-bound KEK for bring-up — explicitly labeled non-presumption-grade for RED
- Board profile / feature flag selects backend; consumers (Wi‑Fi credential vault first) depend only on the abstract API
- Overlay/Buildroot enablement path for `tee-supplicant` / OP-TEE client when product images support it
- Spike notes on ynh960 OP-TEE/HUK/RPMB availability; no desktop keyring (gnome-keyring / libsecret)

## Capabilities

### New Capabilities
- `hal-secrets-kek`: HAL Secrets/KEK provider API, OP-TEE vs interim backends, board selection, logging/threat-model constraints for reusable secret sealing

### Modified Capabilities
- `dart-hal`: Board bindings / profile expose Secrets provider for Linux appliance consumers

## Impact

- `packages/cyber_hal`: new secrets module + bindings; FFI or process bridge to `libteec` / PKCS#11 as decided in design
- Overlay / Buildroot: optional OP-TEE client packages and `tee-supplicant` unit when enabled
- Consumers: `wifi-credential-secure-storage` (and later proxy/cloud tokens) call this API for KEK — do not embed TEE details
- Docs: security notes linking interim vs TEE; does not claim RED conformity by itself
- Sibling change: `openspec/changes/wifi-credential-secure-storage` updated to **depend on** this capability for KEK
