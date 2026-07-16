## 1. Foundations and feasibility

- [x] 1.1 Rebase this change against `platform-event-driven-ui` Bluetooth D-Bus work (or its archived delta) so `linux-bluetooth` keeps ObjectManager/PropertiesChanged as the primary observation path
- [ ] 1.2 On ynh960, spike one Classic HID keyboard/mouse and one BLE HOGP device with BlueZ; capture `bluetoothd`/kernel logs and record whether initiator SDP (`ENOSYS`) blocks Classic HID
- [x] 1.3 Document the acceptance device matrix (Classic vs BLE, keyboard vs mouse) and any unavoidable transport limitation in `notes.md`

## 2. Kernel / Buildroot / BlueZ HID support

- [x] 2.1 Audit final kernel config for `CONFIG_BT_HIDP`, `CONFIG_UHID`, generic HID/input/evdev; add overlay fragments only where missing
- [x] 2.2 Confirm BlueZ input/HOG plugins are present and not disabled by `bluetoothd --noplugin=...`; keep `ReverseServiceDiscovery=false` and existing A2DP defaults
- [x] 2.3 After connect on hardware, verify `/dev/input/event*` (or by-id) appears for the HID peripheral without changing USB HID behavior

## 3. Dart Bluetooth API and models

- [x] 3.1 Extend `BluetoothController` with scan state, `startScan`/`stopScan`, `pairAndConnect`, and a unified device stream/snapshot (retire direction-only `incomingDevices` as the sole list)
- [x] 3.2 Extend models for address, name, paired/trusted/connected, best-effort type/UUIDs, RSSI when available, discovered flag, and structured operation failures
- [x] 3.3 Add pairing-challenge models/stream (confirm, display passkey, request PIN/passkey, authorize, cancel) plus accept/reject APIs
- [x] 3.4 Update mocks and existing Bluetooth unit tests to the unified API

## 4. Linux BlueZ D-Bus implementation

- [x] 4.1 Implement bounded `Adapter1.StartDiscovery`/`StopDiscovery` (default ~15s), cancelable, deduplicated device map keyed by object path/address
- [x] 4.2 Implement `Device1.Pair`/`Connect`/`Disconnect` and `Adapter1.RemoveDevice` with serialized adapter mutations and non-fatal structured errors
- [x] 4.3 Preserve adapter enable/disable, discoverable/pairable, incoming bond management, and opt-in A2DP Sink helpers on the same controller
- [x] 4.4 Stop discovery before pairing when required by BlueZ/controller; reconcile state after bluetoothd restart

## 5. Pairing agent coordination

- [x] 5.1 Provide one deterministic `Agent1` owner for incoming phone/PC and outbound HID while HMI is running (in-process D-Bus or small broker helper if Agent1 export is blocked under flutter-pi)
- [x] 5.2 Adjust `bt-pair-agent.sh` / `bt-ensure-agent.sh` so they do not compete for default agent; define deterministic fallback after HMI exit or bluetoothd restart
- [x] 5.3 Surface keyboard DisplayPasskey/DisplayPinCode to the controller; allow JustWorks auto-confirm only under existing product policy during explicit outbound ops or when Pairable is enabled
- [x] 5.4 Reject stale/unmatched agent requests; verify phone incoming pairing and A2DP Sink still work after agent changes

## 6. Demo Bluetooth section

- [x] 6.1 Add Scan/Stop with progress and bounded-timeout feedback without blocking first-frame paint
- [x] 6.2 Show deduplicated nearby-device rows (type/RSSI/state when known) plus Pair/Connect actions
- [x] 6.3 Show pairing instructions/passkey UI for keyboard flows; keep Disconnect/Remove on bonded/connected remotes
- [x] 6.4 Retain adapter, discoverable, pairable, A2DP Sink, and bonded-peer controls; keep failures local to the section

## 7. Tests and device acceptance

- [x] 7.1 Host unit tests: discovery/device mapping fixtures, scan timeout → inactive, pair/connect failure mapping, agent challenge correlation
- [x] 7.2 Widget/smoke tests for Bluetooth Demo scan list and passkey presentation (non-fatal error path)
- [ ] 7.3 Device matrix: Bluetooth keyboard types into Demo text field; Bluetooth mouse pointer/click/scroll; reconnect after BT toggle or reboot
- [x] 7.4 Coexistence: phone incoming pair/A2DP + HID bonds; bounded scan with Wi-Fi connected; USB keyboard/mouse unchanged
- [x] 7.5 Update `app/hmi/README.md` Bluetooth smoke steps for scan/connect HID and coexistence checks
