## Why

**End users** need a supported **恢复出厂设置** action in the product HMI: clear their networks, App data, media, and UI settings, then reboot to a clean operator defaults — without Loader flash and without losing device provisioning or cloud activation. This is a **user-facing product feature**, not a 产线 / factory-floor workflow (产线 continues to use `set-prop`, `write-identity`, `make flash`, etc.). Today docs mention userdata wipe on “factory reset” but there is no HMI entry or board helper that implements the user wipe contract.

## What Changes

- Define a **user factory-reset wipe contract**: erase operator/runtime userdata; preserve non-user provisioning (`properties.ini`, VS identity, activated cloud ID 22, seal KEK).
- Add a board-side **factory-reset helper** invoked by the UI (stop seats, selective wipe, reboot).
- Ship the action in **product HMI Settings** (required user path) with strong confirmation; optionally mirror in OS Settings when that seat is open.
- Align flash-time operator-prefs cleanup with the same wipe contract (platform hygiene), without treating flash as the user feature.
- **Do not** add a host `make factory-reset` target.
- Document as a user Settings capability in storage / settings-role docs.

## Capabilities

### New Capabilities

- `factory-reset`: User wipe contract, board helper, reboot semantics, **HMI Settings** entry (required), optional OS Settings mirror — erase user/operator userdata while preserving `properties.ini`, product identity, activated cloud Ed25519 (VS ID 22), and seal KEK.

### Modified Capabilities

- `linux-settings-persist`: User factory-reset MUST clear **operator** prefs; MUST preserve `/var/lib/hal/properties.ini`; upgrade / OTA / push-app MUST NOT wipe those trees.
- `vendor-storage-identity`: User factory-reset MUST **preserve** sealed cloud Ed25519 (VS ID 22) and brand / model / SN — no re-activation after reset.
- `hal-secrets-kek`: Seal KEK wrap (VS ID 23) survives user factory-reset; REE `/userdata/tee` MAY be deleted and restored from VS so ID 22 stays unsealable.

## Impact

- **Overlay / board:** `/usr/libexec/board/factory-reset.sh` + `/usr/bin/factory-reset`; selective wipe under `/userdata/hal` (keep `properties.ini`); never touch VS 1/20/21/22/23.
- **Apps (product):** `app/lws_hmi` Settings — Erase All Data / 恢复出厂设置 (required). Optional parity in `app/os_settings`.
- **Does not:** add `make factory-reset`; become a 产线 tool; reflash firmware; clear cloud activation; clear `properties.ini`.
