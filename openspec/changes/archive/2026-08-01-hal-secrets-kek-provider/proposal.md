## Why

Encrypted vaults (Wi‑Fi PSK and future secrets) need a shared KEK / seal API. Without it, each feature invents ad-hoc crypto. A thin HAL Secrets layer (not a desktop Keychain) is the reusable foundation for `wifi-credential-secure-storage` and later secrets.

## What Changes

- Add `cyber_hal` **Secrets / KekProvider** abstraction: seal/unseal with AAD; never log key material
- **Two backends**, both first-class:
  - **`optee`** — `/usr/libexec/hmi/secrets-seal` + seal TA (`isHardwareBound = true`)
  - **`software`** — live multi-factor HW fingerprint → HKDF-SHA256 → AES-256-GCM; **no KEK/salt file on disk** (`backendId = software_fallback`, `isHardwareBound = false`)
- **Selection is OEM** `board_profile.json` → `secrets_backend` (`software` | `optee`). No silent cross-fallback when the selected backend fails
- **Current ynh960 product default: `software`** until Innohi/Rockchip provides a BL32-matched `TA_SIGN_KEY` (or signed `.ta`); flip profile to `optee` when ready (no App code change)
- When `secrets_backend` is omitted: sim/emu/portable-smoke → software; other board ids → optee (legacy heuristic)
- Overlay/Buildroot: DT optee node, `optee-client`, `tee-supplicant`, seal CA/TA build path (`make build-secrets-seal`) — stack ready; field OpenSession blocked on vendor TA signing today
- Spike notes on ynh960 OP-TEE/HUK/RPMB; no desktop keyring

## Capabilities

### New Capabilities
- `hal-secrets-kek`: HAL Secrets/KEK API; OEM-selected OP-TEE or device-bound software backend; logging/threat-model constraints

### Modified Capabilities
- `dart-hal`: Board bindings / profile expose Secrets provider via `secrets_backend`

## Impact

- `packages/cyber_hal`: secrets module + `BoardBindings.secrets()`; Process helper to `secrets-seal` for OP-TEE
- Overlay / Buildroot / OEM: OP-TEE client + `tee-supplicant`; ynh960 `secrets_backend: software`
- Consumers: `wifi-credential-secure-storage` and later secrets call abstract API only
- Emulator (`sim` / `sim_virt`): software (profile or heuristic)
- Docs: `docs/hal-secrets-kek.md`; does not by itself claim RED conformity
- Sibling: `wifi-credential-secure-storage` depends on this for KEK
