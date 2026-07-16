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
| Classic HID / BLE HOGP pair+connect | **Blocked on HOGP attach** — see below. |

**UHID on running image (2026-07-16 later):** `/dev/uhid` present, `CONFIG_UHID=y` (built-in). UHID is not the blocker.

**QM002 HOGP attach (2026-07-16) — FIXED:** `Disconnect/Connect s "random"` → `ServicesResolved=true`; keyboard `event3=QM002` appears (typing + pointer work). `ConnectProfile` may still return `br-connection-page-timeout` but input-hog can already be up after LE Connect. Rockchip ADDR_TYPE: `random`/`public`=LE, `bredr`=Classic (do not map AddressType=public → Connect public for Classic HID), `auto`=bluetoothd bearer select.

**Pointer axes (BT keyboard+trackpad):** QM002 reports **EV_REL + EV_ABS**; libinput may deliver REL and/or ABS. Fix must cover both (`0009`). Auto: udev `ID_BUS=bluetooth` + kb+pointer. Demo: Auto / Raw / Swap XY → `pointer_axes=` in mouse.conf; flutter-pi polls ns mtime and `LOG_ERROR` on axes change. Field note: board must run rebuilt flutter-pi (prebuilt md5); UI alone cannot fix an old binary. Retired: `0009-pointer-relative-display-axes`, `0009-qm002-pointer-axis-swap`.

**QM002 trackpad gestures (2026-07-17):** HID report **does** include Digitizer Touch Pad (0x0D/0x05) with multi-finger collections, but default **`hid-apple`** only exposes REL mouse + keyboard → libinput `Tap-to-click: n/a`, scroll=`button`. Spikes: **`hid-magicmouse`** enables tap + two-finger scroll but drops libinput **keyboard** capability (typing broken); **`hid-multitouch`** keeps a separate Keyboard node but the Touchpad node fails sanity checks (no MT axes / not a real libinput touchpad). **No safe automatic rebind** today without breaking typing. Need kernel/`hid-apple` digitizer support or hidraw→uinput bridge for both. flutter-pi `0005` still enables tap/2fg **when** libinput reports them (forward-compatible). Product choice: **prefer typing** (stay on hid-apple).

**HID reconnect (BlueZ-first, weak Timer) (2026-07-17):** Dropped the 8s periodic keepalive sweep. Primary path: `Trusted` + BlueZ `[Policy]` `ReconnectUUIDs`/`ReconnectIntervals`. App: on `PropertiesChanged` link loss, wait **15s** for policy, then host `Connect` only if still down; on connect/resolve edge, one-shot HOGP heal if BT evdev missing (backoff one-shot retries). User Disconnect still **Untrust + Disconnect** and blocks auto-reconnect until Connect/Pair.

**HID keepalive field fix (2026-07-17):** After upgrade, keepalive Disconnect-looped zombies (`Connected=yes ServicesResolved=false`) and `_hidEvdevPresent` treated USB mice as HOGP success → no QM002 evdev + bluetoothd flooded `characteristic_get_notifying`. Fix: BT-only evdev match (uniq/uhid), never zombie-Disconnect in reconnect path, exponential backoff. Corrupt bonds may need one Remove → Scan → Pair.

**User Disconnect release (2026-07-17):** Demo Disconnect alone does not free LE keyboards: `Trusted=yes` + BlueZ policy + keyboard inbound ATT re-connects in ~250ms. Fix: HID Disconnect **untrust then Disconnect** (bond kept); block app reconnect until Connect/Pair; Connect path trusts again. Verified: untrust+Disconnect holds; Connect alone restores without Remove.


**Cursor stutter / MoveCursor EFAULT:** Every pointer move called `drmModeMoveCursor`, which fails with EFAULT on ynh960 Rockchip; unthrottled `LOG_ERROR` flooded journal and stuttered USB + BT. `0010-cursor-movecursor-fallback.patch` latches failure once, logs once, and repositions via atomic prefer_cursor composition push.

**Still open for 1.2 / 2.3 / 5.4 / 7.3 / 7.4:** bring a Classic HID keyboard or mouse (and ideally a HOGP device), pair from Demo Scan, confirm `/dev/input` nodes, Demo typing/pointer, phone+A2DP coexistence, and whether AIC initiator SDP `ENOSYS` appears in `journalctl -u bluetooth` during Classic HID connect.

## How OSes pair BLE keyboards vs why Demo hung (2026-07-16)

**iPhone / iPad / Android Settings (typical BLE HOGP keyboard):**

1. User selects the keyboard (or accepts “keyboard wants to pair”).
2. Stack **Connects** (LE ATT / GATT).
3. SMP bonding runs — often **Just Works** or a single **Accept** consent UI (not typing a passkey on the keyboard).
4. HOGP profile comes up → Linux/`hid`/UHID input nodes (on phones: HID host stack).

**Linux desktop (GNOME / `bluetoothctl`):** same idea — default Agent registered, then **connect** (pair as needed), trust.

**What our logs showed:**

```
input-hog … unavailable → disconnected
bt: connect … UnknownMethod: Method "Connect" … doesn't exist
New incoming LE ATT connection
Pairing timed out after connect
```

`Connect` “doesn't exist” here is BlueZ-speak for **the Device1 object is already gone** (same class of error as Bleak `UnknownObject`). We previously **stopped discovery before Pair**; for LE random-address keyboards BlueZ removes the cache entry → stale Dart handle → Connect fails → Pair hangs.

**Mitigation in HMI:** keep discovery on; treat **bluetoothctl info/connect/pair/trust** as authoritative (Dart Device1 cache can be ghost); Demo Accept first then agent auto-confirm; show SelectableText errors.

**AIC initiator SDP:** Prior phone/A2DP work documented `ENOSYS` on HMI-initiated SDP to phones. Outbound HID still requires a physical Classic keyboard/mouse spike before claiming Classic HID acceptance. BLE HOGP may differ; keep transport-neutral UI.

## bluetoothd crash recovery (2026-07-16 field log)

Observed on device during Demo scan:

1. `input-hog` profile `disconnected -> unavailable` for an LE device
2. `bluetoothd` aborted: `malloc(): mismatching next->prev_size (unsorted)` → `status=6/ABRT`
3. Subsequent D-Bus calls failed with `Unit dbus-org.bluez.service not found` (Alias only exists after `systemctl enable`; we keep bluetooth boot-deferred)
4. HMI adapter off/on could not recover because the BlueZ Dart client stayed on a dead session and `unregisterAgent` hit the missing activation unit

Mitigations shipped:

- Overlay alias `etc/systemd/system/dbus-org.bluez.service` → `bluetooth.service`
- `Restart=on-abnormal` on `bluetooth.service`
- `bt-stack-up/down` reset-failed / restart + HMI client reset on adapter toggle / adapterRemoved

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
