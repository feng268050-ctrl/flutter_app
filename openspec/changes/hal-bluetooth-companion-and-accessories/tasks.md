## 1. Spike and capability flags

- [ ] 1.1 On ynh960, spike BlueZ LE advertise + GATT server (in-process D-Bus or note helper need); record results in change `notes.md`
- [ ] 1.2 Spike companion write → `WifiController.connect` once; confirm vault path, no plaintext PSK logs
- [ ] 1.3 Spike dual-role: companion peripheral active while HID/HOGP central scan or bonded keyboard remains usable; capture connection limits
- [ ] 1.4 Define profile JSON shape for Bluetooth sub-features (`companion`, `accessory_host`, `a2dp_sink`) and parsing in `BoardProfile` / bindings
- [ ] 1.5 Keep ynh960 `companion` disabled in OEM profile until spike 1.1–1.3 accept; enable only after notes sign-off

## 2. Abstract HAL APIs

- [ ] 2.1 Add abstract companion API (session start/stop, state streams, provision, device RPC) under `package:cyber_hal` bluetooth module
- [ ] 2.2 Add abstract accessory-host API (profile registry, discovery, connect/disconnect, accessory list streams)
- [ ] 2.3 Add HID accessory profile interface wrapping existing pair/connect/input expectations
- [ ] 2.4 Add stub companion + accessory-host backends for host unit tests
- [ ] 2.5 Document device RPC method allowlist v1 (`wifi.provision`, `settings.get/set`, `system.info`, optional plane stubs) in `notes.md` or protocol stub doc
- [ ] 2.6 Wire `BoardBindings` to construct planes only when sub-features advertised; unsupported otherwise

## 3. Linux companion backend

- [ ] 3.1 Implement LE advertising + GATT application registration against BlueZ (or injectable helper port if spike required it)
- [ ] 3.2 Implement provision characteristic/RPC path calling `WifiController` + status notify
- [ ] 3.3 Implement allowlisted settings RPC delegating to existing HAL ports
- [ ] 3.4 Enforce bonding / open-pairing window timeout policy hooks
- [ ] 3.5 Serialize adapter-wide mutations with existing BlueZ client lock/owner
- [ ] 3.6 Unit tests for RPC allowlist, unsupported methods, and provision error mapping (no device required)

## 4. Linux accessory-host refactor

- [ ] 4.1 Introduce accessory-host façade over current central discovery/pair/connect paths without Demo behavior regression
- [ ] 4.2 Move HID/HOGP ensure/heal behind HID profile registration
- [ ] 4.3 Preserve phone A2DP + HID coexistence scenarios from `linux-bluetooth`
- [ ] 4.4 Add extension-point test registering a second no-op profile alongside HID
- [ ] 4.5 Update Demo Bluetooth section to use accessory-host for scan/pair if cutover is in-scope; otherwise keep thin façade and document migration task follow-up

## 5. Coexistence, docs, and accept

- [ ] 5.1 Implement or document `BluetoothSessionPolicy` defaults (pairing-mode companion advertise vs always-on)
- [ ] 5.2 Update `docs/hal-portability.md` Bluetooth section for companion + accessory-host + sub-features
- [ ] 5.3 Update `packages/cyber_hal/README.md` module map for new APIs
- [ ] 5.4 On-device acceptance checklist: companion provision; HID keyboard; A2DP opt-in; Wi‑Fi up during bounded scan
- [ ] 5.5 Enable `companion` on ynh960 OEM profile only after checklist pass; leave other boards unchanged unless spiked

## 6. Explicit non-goals (do not implement in this change)

- [ ] 6.1 Confirm out of scope in notes: mobile App UI, helmet profile/codecs, SoftAP, LAN/cloud default-off in `lws_hmi`, Classic SPP primary path
