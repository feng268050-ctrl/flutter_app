# cyber_hal

Portable Dart HAL for LWS appliance HMIs (parallel to CyberUI). Apps import only the modules they need. **No** Rust `hald` / IPC daemon.

## Module map

| Import | Domain | Persist / helpers |
|--------|--------|-------------------|
| `package:cyber_hal/network.dart` | ethernet, wifi, proxy, **ssh_debug** | networkd + wpa (`docs/network-stack.md`); LAN SSH helpers |
| `package:cyber_hal/network/proxy.dart` | system proxy | `/var/lib/network/proxy.conf` + in-HAL env apply |
| `package:cyber_hal/network/cloud_environment.dart` | cloud API env tier | `/var/lib/network/cloud.conf` (`environment_tier`) |
| `package:cyber_hal/network/cloud_origin.dart` | multi-origin catalog + concurrent probe / pin | defaults LaserCyber Workers+hyurl; boot pin `/run/network/cloud-origin.pin`; honors system proxy |
| `package:cyber_hal/network/cloud_headers.dart` | Worker HTTP/WS headers | `App-Version`, `Device-Type: Linux`, Bearer |
| `package:cyber_hal/network/cloud_http_client.dart` | Bearer HTTP + 401 remint | uses HAL `Proxy`; App injects `appVersion` + token resolvers |
| `package:cyber_hal/network/device_cloud_auth.dart` | activate + Ed25519 access_token | on top of `CloudEd25519Identity` |
| `package:cyber_hal/network/device_ws_*.dart` | WS envelope + connection lifecycle | product command dispatch stays in App |
| `package:cyber_hal/usb_otg.dart` | OTG modes debug/mtp/host | `/var/lib/hal/usb-otg.conf`; `/etc/usb-otg.ini` |
| `package:cyber_hal/output.dart` | display + sound barrels | see sub-imports |
| `package:cyber_hal/input.dart` | keyboard, mouse (USB/serial cameras later) | `/var/lib/hal/keyboard.conf`, `mouse.conf` |
| `package:cyber_hal/ip_camera.dart` | IP network camera (host-injected; multi-instance; RTSP→file recording) | path/MediaMTX are **product** concerns — not this module |
| `package:cyber_hal/gpio.dart` | Status LED / buzzer / button / encoder (config-driven) | App `gpio.json` — **sysfs** and/or **gpiod** per binding |
| `package:cyber_hal/modbus.dart` | attribute catalog | board `modbus.json` + serial |
| `package:cyber_hal/bluetooth.dart` | BlueZ | `/var/lib/bluetooth/` |
| `package:cyber_hal/sys_info.dart` | host inventory + `ProductInfo` | procfs/sysfs + Vendor Storage identity (`brand`/`model`/`sn`/`chipId`) + opaque `/var/lib/hal/properties.ini` bag via `get(key)` |
| `package:cyber_hal/secrets.dart` | KEK seal/unseal; cloud Ed25519 identity (VS ID 22) | OP-TEE / software KEK; sealed blob helpers |
| `package:cyber_hal/datetime.dart` | wall clock | `/var/lib/hal/datetime.conf` (`sync_mode`, `timezone`) |
| `package:cyber_hal/stub.dart` | in-memory stubs | P3.2 emulator / host tests |
| `package:cyber_hal/cyber_hal.dart` | core only | `Capabilities`, `BoardProfile`, errors |

Sub-imports work without pulling siblings, e.g. `package:cyber_hal/output/display/backlight.dart`, `package:cyber_hal/network/ssh_debug.dart`, `package:cyber_hal/usb_otg.dart`.

| Import | Domain | Persist / helpers |
|--------|--------|-------------------|
| `package:cyber_hal/output/display.dart` | backlight, auto-sleep, orientation, wallpaper | `/var/lib/hal/display.conf` (`backlight`, `auto_sleep`, `orientation`, `wallpaper`, `wallpaper_id`); presets `/usr/share/hal/wallpapers/` |
| `package:cyber_hal/output/sound.dart` | volume, button-feedback (+ media audio) | `/var/lib/hal/sound.conf` (`volume`, `button_feedback` = installed sample path) |
| `package:cyber_hal/output/load_profile.dart` | load / thermal profile (`performance` / `balanced`) | `/var/lib/hal/power.conf` (`mode`) |

## Portability (D11b / D22)

**Full new-product contract (all modules):** [`docs/hal-portability.md`](../../docs/hal-portability.md).  
**Network OS + modem bring-up case study:** [`docs/network-stack.md`](../../docs/network-stack.md).

**Scope:** Buildroot / eLinux **Linux** appliance (+ `Stub*` for host/sim). `Linux*` types are Linux backends of the abstract APIs — **not** a foreshadowing of `Android*` in this package. P5.0 Android APK compatibility is **App-layer** (Android platform APIs / `YNHAPI`); Android already has its own HAL.

- **Portable core:** D-Bus (networkd, wpa, BlueZ), config-driven gpio/modbus, `/proc`/`/sys` inventory.
- **Board pack:** `BoardBindings(profile)` wires helpers / ifaces / mounts / gpio+modbus assets from `BoardProfile.helpers`. Inject modem / SSH-USB / A2DP only when needed.
- **Recommended ifaces:** `eth0` + `wlan0` (HAL allows others via `net_roles`).
- **Smoke profile:** `boards/portable-smoke.json` proves construction without ynh960 libexec paths.

## Board profiles

| File | Role |
|------|------|
| `boards/sim.json` | Limited host/emulator profile (no gpio/modbus/network/BT) |
| `boards/portable-smoke.json` | D22 accept: non-default ifaces / unit names; no libexec required |

**Product** board profile + `gpio.json` + `modbus.json` live in the **App** (this repo: `app/lws_hmi/assets/hal/`), not under `boards/<board_id>/` in this package. The same motherboard may ship different catalogs in other products. `BoardProfile.configs.gpio` / `configs.modbus` point at Flutter asset URIs (`assets/hal/…`); `assets/…` and `packages/…` resolve as-is.

### Config install path (v1)

**Example / smoke profiles** ship as Flutter package assets (`boards/sim.json`, `boards/portable-smoke.json`). **Product** gpio/modbus/profile JSON ship as **App** assets. Installing under `/usr/share/cyber_hal/` is deferred until a product needs non-Flutter consumers.

## Stub backends (host tests)

P3.2 QEMU guests use **Linux** backends with OEM `board_id=sim`. Stub backends are
for host unit tests / emergency only:

1. Set `HAL_BACKEND=stub` (board id alone does **not** select stubs).
2. Construct `StubBacklight` / `StubVolume` / `StubSysInfo` from `package:cyber_hal/stub.dart`.

```dart
final profile = await BoardProfile.loadAsset('packages/cyber_hal/boards/sim.json');
// Guest / device: resolveHalBackend() == linux even when boardId is sim.
if (resolveHalBackend(env: 'stub') == HalBackendKind.stub) {
  final backlight = StubBacklight();
  final volume = StubVolume();
  final autoSleep = StubAutoSleep();
  final buttonFeedback = StubButtonFeedback();
  final orientation = StubOrientation();
  final sysInfo = StubSysInfo();
}
```

## GPIO

`package:cyber_hal/gpio.dart` loads App-owned `gpio.json` (via `BoardProfile.configs.gpio`). **Pins and paths are never hard-coded in HAL** — boards enable fewer/more devices by editing config.

**Devices:** `StatusLedBank`, `GpioBuzzer`, `GpioButton` (long-press), `RotaryEncoder` (debounce).

**Line schemes** (per binding, optional document default `backend`):

| Scheme | Addressing |
|--------|------------|
| `sysfs_innohi` / `sysfs` / `sysfs_file` | `path` and/or `label` (any `/sys/class/…` tree) |
| `gpiod` | `chip` + `offset` via `flutter_gpiod` (`/dev/gpiochip*`) |
| `stub` | in-memory (host tests; `forceStub: true`) |

ynh960 product catalog example (RGB + BELL) and pad table: [`docs/ynh960-io-pinmux-ledger.md`](../../docs/ynh960-io-pinmux-ledger.md). Sysfs remains supported alongside gpiod (lines hogged by Innohi `own-gpio` typically stay on sysfs).

**gpiod access:** HMI must open `/dev/gpiochip*` (often root or `gpio` group). Prefer sysfs for hogged Innohi lines; use gpiod when the line is free and edges are needed.

**Field smoke (manual):** after `make build-app` / `upgrade-app`, verify RGB Steady/Blink/Off and optional `panel_buzzer` beep on hardware; confirm `BELL` sysfs node name if beep fails.

## Keyboard layouts (v1)

`LinuxKeyboard.listLayouts` ships product **`us` / `de` / `fr`** plus Demo-only **`ru`**. Legacy `jp` / `jp106` may still appear in conf reads but is not listed. Soft CyberIME layouts are separate; physical text stays on XKB (no Dart scancode remap). `setLayout(..., restart: false)` persists without restart; `restartToApply()` restarts HMI for XKB.

## App dependency

```yaml
dependencies:
  cyber_hal:
    path: ../../packages/cyber_hal
```

## Persist cohesion

HAL mid-session writes use existing FHS:

- `/var/lib/hal/` — mouse, keyboard, usb-debug, properties.ini; **output prefs** as `/var/lib/hal/display.conf` (`backlight`, `auto_sleep`, `orientation`) and `/var/lib/hal/sound.conf`; **load profile** as `/var/lib/hal/power.conf`; **datetime** as `/var/lib/hal/datetime.conf`
- `/var/lib/network/` — ethernet/proxy/primary/cloud env (after network wave)
- `/var/lib/hmi/` — **App-owned** only (misc/advanced JSON, product cloud opt-in toggles, alarm SQLite, debug/push staging)
- `/var/lib/wpa_supplicant/` — Wi‑Fi wanted / networks
- `/var/lib/bluetooth/` — BT

Boot re-apply is `BoardBindings.restorePersistedSettings` (HAL-owned).

## Status

OpenSpec `dart-hal-package`: output, input, debug, datetime, sys_info, **gpio**, **modbus**, **bluetooth**, and **network** (networkd L3 + in-HAL proxy apply) Linux backends live here. App may keep thin `lib/platform/**` façades until Demo cutover. Package `boards/sim.json` matches the P3.2 guest OEM contract (Linux-in-guest; stubs only via `HAL_BACKEND=stub`).

## Modbus

RTU uses the in-tree Posix (`stty` + libc) transport plus an attribute catalog from the **product App’s** `modbus.json` (profile `configs.modbus`). A pub.dev `modbus_client` / `modbus_client_serial` dependency was evaluated but not adopted for v1: those packages route through libserialport, which fails `sp_open` with ENOTTY on this board’s kernel 6.1 + Buildroot libserialport 0.1.1. Package identity may be revisited once a suitable aarch64-friendly serial backend is confirmed.

**Device validation on aarch64/eLinux still required (task 4.4).**
