## Why

The portable HAL today models Bluetooth mainly as a **discoverable A2DP Sink** plus a **HID/HOGP central** for keyboards and mice. The product roadmap needs the appliance (welder HMI and similar) to treat the **phone as the default management hub** over Bluetooth—Wi‑Fi provisioning, settings/config exchange, and light data—while **still hosting Bluetooth accessories** on the same adapter (HID now; smart helmet and other accessories later). Those roles must be first-class, capability-gated HAL surfaces for the shared embedded OS, not one-off App scripts. Hardware (dual-mode combo such as AIC8800 on ynh960) already supports the needed radio roles; the gap is HAL abstraction and BlueZ-backed contracts.

## What Changes

- Introduce a **companion (phone-facing) plane** in `cyber_hal`: BLE peripheral session for provisioning and a transport-agnostic **device link / RPC** surface for configuration and light data exchange with a bonded phone App.
- Generalize the existing central path into an explicit **accessory host** plane: keep Classic HID / BLE HOGP as the first accessory profile; define extension points so future accessories (e.g. helmet) register typed profiles without overloading `BluetoothController` with product protocol details.
- Advertise **optional Bluetooth sub-capabilities** on `BoardProfile` (or equivalent nested flags) so boards/products enable companion and/or accessory-host independently of coarse `Capability.bluetooth`.
- Define **coexistence / session policy** on one adapter: companion + accessory-host (+ existing opt-in A2DP) may run together subject to board apply policy; document spike gates for dual-role and connection limits.
- Wire companion provisioning to existing **`WifiController.connect`** and credential vault (no parallel PSK store).
- **Out of scope for this change (proposal only sets HAL contracts):** LaserCyber mobile App UI; helmet firmware; making LAN `:5580` / cloud default-off in `lws_hmi`; SoftAP; Classic SPP as primary phone data path; mesh between appliances.

## Capabilities

### New Capabilities

- `hal-bluetooth-companion`: Phone-facing BLE companion session—advertise/pair, Wi‑Fi provision commands, settings/config RPC over the companion link, session lifecycle and auth hooks.
- `hal-bluetooth-accessory-host`: Appliance-as-central accessory hosting—unified accessory registry, HID/HOGP as v1 profile, extension contract for future accessory types (helmet, etc.), coexistence with companion.

### Modified Capabilities

- `linux-bluetooth`: Extend Linux BlueZ requirements for GATT peripheral (companion), dual-role coexistence with central accessory host and opt-in A2DP; retire the historical “GATT provisioning is non-goal” framing for this path.
- `dart-hal`: Public `hal/bluetooth` module layout, bindings, and capability advertisement for companion + accessory-host ports; keep Apps on abstract types only.

## Impact

- **Packages:** `packages/cyber_hal` Bluetooth module APIs, `BoardBindings` / `BoardProfile`, stubs for host tests; optional Demo/Settings hooks later (implementation phase).
- **Linux stack:** BlueZ `GattManager1` / `LEAdvertisingManager1` (and related) for companion peripheral; existing Adapter/Device/Agent paths for accessory central; possible Buildroot/BlueZ plugin enablement.
- **Network:** Companion provision calls into existing Wi‑Fi + Secrets vault paths (`linux-wifi`, `wifi-credential-secure-storage` / Secrets).
- **Apps:** `lws_hmi` (and future HMIs) may opt into companion UI and accessory management; this change does not require shipping phone UX or turning off LAN/cloud.
- **OEM profiles:** ynh960 (and peers) declare which Bluetooth sub-capabilities the board supports; products choose which to enable at runtime.
