## Why

`hal-bluetooth-companion-and-accessories` defines the appliance HAL companion plane (BLE peripheral + device RPC + Wi‑Fi provision hooks) but deliberately leaves the **phone wire contract** and **operator pairing UX** open. Product onboarding needs a versioned, phone-consumable BLE link so LaserCyber Mobile can associate a unit, provision Wi‑Fi, and read device identity/info **before** LAN `:5580` or cloud is available. This change locks that cross-repo protocol and the HMI-side pairing session that makes association safe.

## What Changes

- Lock a **v1 companion BLE wire protocol** (service/characteristic UUIDs, advertisement fields, frame encoding, method catalog, error codes, `api_ver`) shared with `lasercyber-mobile` change `ble-companion-device-link`.
- Implement/document **pairing-mode** behavior on the appliance: timed advertise window, bonding requirement for writes, optional display-code / QR correlation for phone association.
- Ensure companion **device info** and **Wi‑Fi provision** RPC paths match the locked catalog and feed existing HAL (`system.info` / identity + `WifiController` + vault)—no parallel stores.
- Add minimal **HMI pairing-mode UX** (start/stop window, show correlation code or QR payload, status) so operators can complete phone onboarding without SoftAP.
- Keep accessory-host / A2DP work in the prior change; this change only extends the **phone link** product surface.
- **Out of scope:** LaserCyber Mobile UI (sibling repo change); helmet accessories; SoftAP; Classic SPP; making LAN/cloud default-off; cloud bind API changes.

## Capabilities

### New Capabilities

- `companion-ble-wire-protocol`: Normative BLE GATT + RPC wire contract for phone Central ↔ appliance Peripheral (advertise, identity, provision, `system.info`, versioning, security rules).
- `hmi-companion-pairing-mode`: Operator-facing pairing session on the HMI—timed companion advertise, correlation display, session status—backed by the HAL companion plane from the prior change.

### Modified Capabilities

- _(none in main `openspec/specs/` yet)_ — depends on in-flight `hal-bluetooth-companion-and-accessories` (`hal-bluetooth-companion`); protocol + pairing requirements live in the new capabilities above and MUST stay compatible with that HAL surface.

## Impact

- **Depends on:** `openspec/changes/hal-bluetooth-companion-and-accessories` (HAL companion APIs + BlueZ peripheral).
- **Sibling:** `lasercyber-mobile` `openspec/changes/ble-companion-device-link` (phone Central client + onboarding UX).
- **Packages / App:** `packages/cyber_hal` companion handlers aligned to locked method IDs; `app/lws_hmi` pairing-mode UI; shared protocol note under this change (or `docs/`) referenced by both repos.
- **Security:** bonding / open-window policy; no PSK logging; factory-reset clears companion bonds per prior change.
- **OEM:** ynh960 `companion` remains gated until HAL spike + this protocol accept; advertise defaults to pairing-mode, not always-on.
