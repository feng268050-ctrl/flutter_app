# cyber_hal

Portable Dart HAL for LWS appliance HMIs (parallel to CyberUI). Apps import only the modules they need. **No** Rust `hald` / IPC daemon.

## Module map

| Import | Domain | Persist / helpers |
|--------|--------|-------------------|
| `package:cyber_hal/network.dart` | ethernet, wifi, proxy, **ssh_debug** | networkd + wpa (`docs/network-stack.md`); LAN SSH helpers |
| `package:cyber_hal/network/proxy.dart` | system proxy | `/var/lib/network/proxy.conf` + in-HAL env apply |
| `package:cyber_hal/usb_otg.dart` | OTG modes debug/mtp/host | `/var/lib/hal/usb-otg.conf`; `/etc/usb-otg.ini` |
| `package:cyber_hal/output.dart` | display + sound barrels | see sub-imports |
| `package:cyber_hal/input.dart` | keyboard, mouse (USB/serial cameras later) | `/var/lib/hal/keyboard.conf`, `mouse.conf` |
| `package:cyber_hal/ip_camera.dart` | IP network camera (host-injected; multi-instance; RTSP→file recording) | path/MediaMTX are **product** concerns — not this module |
| `package:cyber_hal/gpio.dart` | named GPIO lines | board `gpio.json` (sysfs) |
| `package:cyber_hal/modbus.dart` | attribute catalog | board `modbus.json` + serial |
| `package:cyber_hal/bluetooth.dart` | BlueZ | `/var/lib/bluetooth/` |
| `package:cyber_hal/sys_info.dart` | host inventory + `ProductInfo` + `DisplayStack` | procfs/sysfs + `/var/lib/hal/product.ini` + `/etc/display-stack` |
| `package:cyber_hal/datetime.dart` | wall clock | `/var/lib/hal/datetime.conf` (`sync_mode`, `timezone`) |
| `package:cyber_hal/stub.dart` | in-memory stubs | P3.2 emulator / host tests |
| `package:cyber_hal/cyber_hal.dart` | core only | `Capabilities`, `BoardProfile`, errors |

Sub-imports work without pulling siblings, e.g. `package:cyber_hal/output/display/backlight.dart`, `package:cyber_hal/network/ssh_debug.dart`, `package:cyber_hal/usb_otg.dart`.

| Import | Domain | Persist / helpers |
|--------|--------|-------------------|
| `package:cyber_hal/output/display.dart` | backlight, auto-sleep, orientation | `/var/lib/hal/display.conf` (`backlight`, `auto_sleep`, `orientation`) |
| `package:cyber_hal/output/sound.dart` | volume, button-feedback (+ media audio) | `/var/lib/hal/sound.conf` |

## Portability (D11b / D22)

**Full new-product contract (all modules):** [`docs/hal-portability.md`](../../docs/hal-portability.md).  
**Network OS + modem bring-up case study:** [`docs/network-stack.md`](../../docs/network-stack.md).

**Scope:** Buildroot / flutter-pi **Linux** appliance (+ `Stub*` for host/sim). `Linux*` types are Linux backends of the abstract APIs — **not** a foreshadowing of `Android*` in this package. P5.0 Android APK compatibility is **App-layer** (Android platform APIs / `YNHAPI`); Android already has its own HAL.

- **Portable core:** D-Bus (networkd, wpa, BlueZ), config-driven gpio/modbus, `/proc`/`/sys` inventory.
- **Board pack:** `BoardBindings(profile)` wires helpers / ifaces / mounts / gpio+modbus assets from `BoardProfile.helpers`. Inject modem / SSH-USB / A2DP only when needed.
- **Recommended ifaces:** `eth0` + `wlan0` (HAL allows others via `net_roles`).
- **Smoke profile:** `boards/portable-smoke.json` proves construction without ynh960 libexec paths.

## Board profiles

| File | Role |
|------|------|
| `boards/sim.json` | Limited host/emulator profile (no gpio/modbus/network/BT) |
| `boards/portable-smoke.json` | D22 accept: non-default ifaces / unit names; no libexec required |

**Product** board profile + `gpio.json` + `modbus.json` live in the **App** (this repo: `app/hmi/assets/hal/`), not under `boards/<board_id>/` in this package. The same motherboard may ship different catalogs in other products. `BoardProfile.configs.gpio` / `configs.modbus` point at Flutter asset URIs (`assets/hal/…`); `assets/…` and `packages/…` resolve as-is.

### Config install path (v1)

**Example / smoke profiles** ship as Flutter package assets (`boards/sim.json`, `boards/portable-smoke.json`). **Product** gpio/modbus/profile JSON ship as **App** assets. Installing under `/usr/share/cyber_hal/` is deferred until a product needs non-Flutter consumers.

## Stub / sim backends (P3.2)

For host tests and the emulator:

1. Load `boards/sim.json` (or any profile with `board_id: sim`).
2. Select stubs with `resolveHalBackend(boardId: …)` — also honors `HAL_BACKEND=stub` (or `sim`).
3. Construct `StubBacklight` / `StubVolume` / `StubSysInfo` from `package:cyber_hal/stub.dart`.

```dart
final profile = await BoardProfile.loadAsset('packages/cyber_hal/boards/sim.json');
if (resolveHalBackend(boardId: profile.info.boardId) == HalBackendKind.stub) {
  final backlight = StubBacklight();
  final volume = StubVolume();
  final autoSleep = StubAutoSleep();
  final buttonFeedback = StubButtonFeedback();
  final orientation = StubOrientation();
  final sysInfo = StubSysInfo();
}
```

## Keyboard layouts (v1)

`LinuxKeyboard.listLayouts` ships product **`us` / `de` / `fr` / `jp`** (JIS uses model `jp106`) plus Demo-only **`ru`**. Soft CyberIME layouts are separate; physical text stays on XKB (no Dart scancode remap). `setLayout(..., restart: false)` persists without restart; `restartToApply()` restarts HMI for XKB.

## App dependency

```yaml
dependencies:
  cyber_hal:
    path: ../../packages/cyber_hal
```

## Persist cohesion

HAL mid-session writes use existing FHS:

- `/var/lib/hal/` — mouse, keyboard, usb-debug, product.ini; **output prefs** as `/var/lib/hal/display.conf` (`backlight`, `auto_sleep`, `orientation`) and `/var/lib/hal/sound.conf`; **datetime** as `/var/lib/hal/datetime.conf`
- `/etc/display-stack` — image embedder stamp (`DisplayStackProbe`; legacy `/etc/hmi/display-stack` fallback)
- `/var/lib/hmi/` — **App-owned** only (misc/advanced JSON, alarm SQLite, debug/push staging)
- `/var/lib/network/` — ethernet/proxy (after network wave)
- `/var/lib/wpa_supplicant/` — Wi‑Fi wanted / networks
- `/var/lib/bluetooth/` — BT

Boot re-apply is `BoardBindings.restorePersistedSettings` (HAL-owned).

## Status

OpenSpec `dart-hal-package`: output, input, debug, datetime, sys_info, **gpio**, **modbus**, **bluetooth**, and **network** (networkd L3 + in-HAL proxy apply) Linux backends live here. App may keep thin `lib/platform/**` façades until Demo cutover. Sim/stub profile supports P3.2 emulator prep.

## Modbus

RTU uses the in-tree Posix (`stty` + libc) transport plus an attribute catalog from the **product App’s** `modbus.json` (profile `configs.modbus`). A pub.dev `modbus_client` / `modbus_client_serial` dependency was evaluated but not adopted for v1: those packages route through libserialport, which fails `sp_open` with ENOTTY on this board’s kernel 6.1 + Buildroot libserialport 0.1.1. Package identity may be revisited once a suitable aarch64-friendly serial backend is confirmed.

**Device validation on aarch64/flutter-pi still required (task 4.4).**
