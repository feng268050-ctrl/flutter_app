# Notes: add-bluetooth-hid-and-demo-management

## Rebase vs `platform-event-driven-ui` (task 1.1)

- `platform-event-driven-ui` requires BlueZ **D-Bus** ObjectManager/PropertiesChanged as the primary observation path and forbids Timer+`bluetoothctl` status polls, but still marks central scan out of scope.
- This change **keeps** the D-Bus primary path and **removes** the central-scan prohibition (see delta specs).
- Implementation choice: Canonical `bluez` Dart package (`BlueZClient`) on the system bus — same direction as platform-event-driven-ui D3 (`dbus` / BlueZ client), so archive order does not restore CLI polling.
- Shell helpers remain for deferred `bt-stack-up/down` and A2DP Sink only.

## Hardware spike (task 1.2) — ynh960 2026-07-16

Board: USB-SSH `192.168.55.1`, adapter `B4:04:29:B0:5A:FA` (`lws-hmi`).

| Check | Result |
|-------|--------|
| Kernel `CONFIG_BT_HIDP` | `y` |
| Kernel `CONFIG_UHID` | `y` |
| Kernel `CONFIG_HID` / `HID_GENERIC` / `USB_HID` / `INPUT_EVDEV` | `y` |
| `bluetoothd --noplugin=` | `battery` only (input/HOG not disabled) |
| `bluetoothd` symbols | `org.bluez.Input1`, `input_device_*`, `bluez-hog-device`, UUID `00001124` present |
| Adapter roles | `central` + `peripheral` |
| `ReverseServiceDiscovery` | `false` (unchanged; phone A2DP path) |
| Bounded discovery | Works via `bluetoothctl scan on` (~6s); many nearby LE devices appear |
| Classic HID / BLE HOGP pair+connect | **Not exercised** — no known HID keyboard/mouse on the bench this session |

**Still open for 1.2 / 2.3 / 5.4 / 7.3 / 7.4:** bring a Classic HID keyboard or mouse (and ideally a HOGP device), pair from Demo Scan, confirm `/dev/input` nodes, Demo typing/pointer, phone+A2DP coexistence, and whether AIC initiator SDP `ENOSYS` appears in `journalctl -u bluetooth` during Classic HID connect.

**AIC initiator SDP:** Prior phone/A2DP work documented `ENOSYS` on HMI-initiated SDP to phones. Outbound HID still requires a physical Classic keyboard/mouse spike before claiming Classic HID acceptance. BLE HOGP may differ; keep transport-neutral UI.

## Acceptance device matrix (task 1.3)

| Class | Transport | Status |
|-------|-----------|--------|
| Keyboard | Classic HID | Pending on-device pair/connect + Demo text-field type |
| Mouse | Classic HID | Pending on-device pair/connect + pointer/click/scroll |
| Keyboard | BLE HOGP | Pending when a HOGP keyboard is available |
| Mouse | BLE HOGP | Pending when a HOGP mouse is available |
| Phone incoming + A2DP | BR/EDR Sink | Regression required after Agent1 ownership change |
| Scan + Wi-Fi up | Combo AIC | Bounded scan only; do not disable wlan |

Until Classic/BLE HID rows pass, do not treat HID as product-complete; scan/pair UI may still ship for discovery and bonding attempts with structured errors.
