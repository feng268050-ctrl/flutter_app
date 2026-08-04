## Context

`cyber_hal` already ships Linux BlueZ-backed `BluetoothController`: deferred stack bring-up, discoverable/pairable local adapter, opt-in A2DP Sink (phone as media source), and central discovery/pair/connect for Classic HID / BLE HOGP with Linux input. Archived HID work explicitly listed **custom BLE GATT provisioning** as a non-goal.

Product direction for the shared appliance OS: **phone App is the default management hub** over Bluetooth (provision Wi‑Fi, exchange settings/config, light data) even when LAN HTTP `:5580` and cloud are optional/off; the same appliance **hosts accessories** (keyboard/mouse now; helmet and peers later) as central. Same board (e.g. ynh960 + AIC8800 dual-mode) may advertise both planes; products enable what they need.

Stakeholders: HAL/`cyber_hal`, BlueZ/rootfs, future phone App and accessory firmware teams; `lws_hmi` is one consumer, not the definition of the HAL surface.

## Goals / Non-Goals

**Goals:**

- Split Bluetooth into clear HAL planes: **adapter core**, **companion** (phone-facing peripheral + device RPC), **accessory host** (central + typed profiles), retaining **media (A2DP Sink)** as an optional adjacent capability.
- Define abstract Dart APIs and BlueZ Linux backends (or injectable ports) for companion GATT session and accessory-host registry.
- Capability-gate planes so boards without LE peripheral or products that omit companion do not break.
- Coexistence policy: companion + accessory host (+ A2DP) on one adapter with documented apply/session rules.
- Provisioning feeds existing `WifiController` + credential vault.

**Non-Goals:**

- Implementing LaserCyber (or other) mobile App UI / store listing.
- Helmet (or other accessory) firmware and domain sensor protocols beyond a host **profile extension contract**.
- Changing `lws_hmi` defaults for LAN `:5580` / cloud (separate product policy change).
- SoftAP provisioning, Classic SPP as primary phone data path, appliance↔appliance mesh.
- Replacing A2DP Sink or removing HID/HOGP.
- Claiming RED/EN 18031 conformity solely from this change.

## Decisions

### D1 — Two planes over one coarse `bluetooth` capability

Keep `Capability.bluetooth` as the coarse board flag. Add **nested / documented sub-capabilities** (profile JSON or HAL `BluetoothFeatures` alongside bindings), at least:

- `companion` — LE peripheral + device link RPC  
- `accessory_host` — central + profiles (HID v1)  
- `a2dp_sink` — existing opt-in media (already behavioral; make discoverable in feature flags)

Apps check sub-features before constructing plane APIs; missing → structured unsupported, not crash.

**Alternative considered:** Separate top-level `Capability` enum values only. Rejected as noisier for boards that always ship full BT; nested flags mirror how A2DP is already opt-in inside the module.

### D2 — Do not stuff companion GATT into `BluetoothController`

Keep `BluetoothController` (or a slimmed **adapter** facade) for adapter power, identity, discoverable/pairable, device list, pairing agent, scan, and HID-oriented pair/connect used today.

Add:

- `BleCompanionServer` (name illustrative) — start/stop advertise, companion session state, provision + RPC handlers  
- `BtAccessoryHost` — register profiles, list accessories by type, connect/disconnect accessories; **HID profile** wraps current central HID behavior

Composition via `BoardBindings` / session object. Avoid a god-controller.

**Alternative considered:** Expand `BluetoothController` with fifty methods. Rejected for portability and product selective use.

### D3 — Companion transport: BLE GATT peripheral (phone Central)

Phone ecosystems (especially iOS) favor LE GATT for management links. Appliance advertises a documented service UUID set; phone connects as Central.

Logical services (exact UUIDs locked in implementation notes / protocol doc):

- Device info (SN, model, api_ver)  
- Provision (Wi‑Fi credential write + status notify)  
- Device RPC (settings/config request/response + optional event notify)  
- Optional plane-control hooks (enable LAN/cloud) as RPC methods—**stubs OK** until product wires them  

Auth: pairing/bonding + optional operator display code / QR correlation (App policy; HAL exposes challenge hooks).

**Alternative considered:** Classic RFCOMM/SPP. Deferred—poor iOS fit; may remain a future backend behind the same RPC interface.

### D4 — Device RPC is transport-agnostic at the App boundary

Define a small **command/event model** (JSON or CBOR frames with method id, correlation, payload). Companion GATT is the first carrier. Future LAN/cloud can implement the same methods without a second settings API (aligns with optional IP planes later).

v1 method groups: `wifi.provision`, `settings.get/set` (allowlisted keys), `system.info`, optional `planes.lan` / `planes.cloud` stubs.

Settings writes MUST call existing HAL ports (datetime, display, wifi, …)—no duplicate preference trees.

**Alternative considered:** Phone-only binary GATT characteristics per setting. Rejected—does not scale to LAN/cloud parity.

### D5 — Accessory host: HID v1 + profile plugin contract

`BtAccessoryHost` owns central discovery/connect for accessories. **HidAccessoryProfile** implements today’s keyboard/mouse path (BlueZ input / HOGP → evdev).

Future **HelmetAccessoryProfile** (separate change) registers typed streams/commands; this change only requires:

- Profile id + discovery filter (UUID/COD hints)  
- Connect/disconnect lifecycle  
- Opaque or typed event sink interface  

Do not decode helmet sensors in this change.

**Alternative considered:** Wait until helmet exists before abstracting host. Rejected—HID already is an accessory; extracting the host plane now avoids a second rewrite.

### D6 — Coexistence / session policy (not Classic-vs-BLE mode switch)

Radio dual-mode is not mutually exclusive. Product **session policy** may still serialize heavy roles:

- Default appliance: accessory host available; companion advertise on demand or when “phone setup” wanted  
- Apply helpers may temporarily reduce discoverable Classic speaker advertising while companion LE advertise is active if spike shows contention  
- A2DP remains opt-in and independent per existing spec  

Document as `BluetoothSessionPolicy` (board/App injectable), analogous in spirit to USB OTG mode policy—but **roles are capability planes**, not a single Classic|BLE enum.

**Alternative considered:** Hard mutex media XOR companion XOR accessories. Too strict for “phone + keyboard” everyday use; allow policy to tighten per SKU after spike.

### D7 — Linux backend: BlueZ GATT application + existing D-Bus central

- Companion: register GATT application via BlueZ (`GattManager1`), LE advertisement via `LEAdvertisingManager1`; implement characteristics in-process (Dart D-Bus) or a small privileged helper if Dart D-Bus GATT proves insufficient—**prefer in-process**; helper only if spike fails.  
- Accessory central: continue ObjectManager / Device1 / Agent1 paths.  
- Serialize adapter-wide mutations (scan vs advertise vs pair) in one lock owner (adapter core).

### D8 — Security and secrets

- Wi‑Fi PSK only through existing vault / Secrets unseal path after provision.  
- Companion link MUST NOT log PSK or setting secrets at info level.  
- Bonding required before provision/RPC write (or explicit open-pairing window with timeout—product policy).  
- Factory/reset clears companion bonds per Bluetooth remove semantics.

### D9 — Demo / App consumption deferred but contract-testable

Implementation phase ships HAL + unit/stub tests + optional Demo toggles. Full Settings “phone pairing” UX and `lws_hmi` default-off LAN/cloud are follow-ups.

## Risks / Trade-offs

- **[Risk] AIC8800 LE peripheral + GATT server incomplete or unstable** → Gate companion behind board spike (advertise + nRF Connect R/W + provision to `WifiController`); capability flag off if fail.  
- **[Risk] Dual-role (Peripheral to phone + Central to HID/helmet) connection/radio contention** → Session policy + bounded scans; acceptance matrix on ynh960 with Wi‑Fi up.  
- **[Risk] Dart D-Bus GATT server complexity** → Spike early; fallback helper binary under `/usr/libexec/bluetooth/` with HAL port.  
- **[Risk] Protocol churn with phone App** → Version `api_ver` in advertisement/TXT-equivalent GATT; tolerate N-1 reads.  
- **[Risk] Scope creep into helmet domain protocol** → Spec accessory profile contract only; helmet change separate.  
- **[Trade-off] RPC allowlist vs full settings dump** → v1 allowlist keeps attack surface and MTU small; expand deliberately.

## Migration Plan

1. Land APIs + stubs + capability flags (boards default: companion off until spike green; accessory_host on where HID already works).  
2. BlueZ spike on ynh960 → enable `companion` on ynh960 profile.  
3. Refactor HID path behind `BtAccessoryHost` without Demo behavior change.  
4. Optional Demo companion section; phone App integration later.  
5. Rollback: capability off + no advertise; existing A2DP/HID paths remain.

## Open Questions

1. Exact GATT UUID namespace and frame encoding (JSON vs CBOR)—lock during first implementation spike doc.  
2. Is companion advertise **always-on when BT on** or **explicit operator/App “pairing mode”**? (Recommend pairing-mode default for security.)  
3. Should `planes.lan` / `planes.cloud` RPC land as no-op stubs in v1 or wait for product policy change? (Recommend stubs with `unsupported` until wired.)  
4. BlueZ version/plugins: confirm LE advertising + GattManager on current ≥5.87 pin without Experimental footguns on AIC.  
5. Multi-phone bonds: one active companion session vs many bonded phones—product default?
