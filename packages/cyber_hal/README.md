# cyber_hal

Portable Dart HAL for LWS appliance HMIs (parallel to CyberUI). Apps import only the modules they need. **No** Rust `hald` / IPC daemon.

## Module map

| Import | Domain | Persist / helpers |
|--------|--------|-------------------|
| `package:cyber_hal/network.dart` | ethernet, wifi, proxy | networkd + wpa (`docs/network-stack.md`) |
| `package:cyber_hal/network/proxy.dart` | system proxy | `/var/lib/network/proxy.conf` + in-HAL env apply |
| `package:cyber_hal/output.dart` | backlight, volume | `/var/lib/hmi/` backlight + volume prefs |
| `package:cyber_hal/input.dart` | keyboard, mouse | `/var/lib/hmi/keyboard.conf`, `mouse.conf` |
| `package:cyber_hal/debug.dart` | ssh, usb | SSH helpers; `/var/lib/hmi/usb-debug` |
| `package:cyber_hal/gpio.dart` | named GPIO lines | board `gpio.json` (sysfs) |
| `package:cyber_hal/modbus.dart` | attribute catalog | board `modbus.json` + serial |
| `package:cyber_hal/bluetooth.dart` | BlueZ | `/var/lib/bluetooth/` |
| `package:cyber_hal/sys_info.dart` | host inventory | procfs/sysfs + `read-serial` |
| `package:cyber_hal/datetime.dart` | wall clock | timedatectl / date / hwclock |
| `package:cyber_hal/stub.dart` | in-memory stubs | P3.2 emulator / host tests |
| `package:cyber_hal/cyber_hal.dart` | core only | `Capabilities`, `BoardProfile`, errors |

Sub-imports work without pulling siblings, e.g. `package:cyber_hal/output/volume.dart`, `package:cyber_hal/debug/usb.dart`.

## Portability (D11b / D22)

**Full new-product contract (all modules):** [`docs/hal-portability.md`](../../docs/hal-portability.md).  
**Network OS + modem bring-up case study:** [`docs/network-stack.md`](../../docs/network-stack.md).

- **Portable core:** D-Bus (networkd, wpa, BlueZ), config-driven gpio/modbus, `/proc`/`/sys` inventory.
- **Board pack:** `BoardBindings(profile)` wires helpers / ifaces / mounts / gpio+modbus assets from `BoardProfile.helpers`. Inject modem / SSH-USB / A2DP only when needed.
- **Recommended ifaces:** `eth0` + `wlan0` (HAL allows others via `net_roles`).
- **Smoke profile:** `boards/portable-smoke.json` proves construction without ynh960 libexec paths.

## Board profiles

| File | Role |
|------|------|
| `boards/ynh960.json` | Capability flags, net roles → iface, helpers, pointers to configs |
| `boards/ynh960/gpio.json` | Named lines (LEDs = lines with roles) |
| `boards/ynh960/modbus.json` | RTU transport + attribute/register catalog |
| `boards/sim.json` | Limited host/emulator profile (no gpio/modbus/network/BT) |
| `boards/portable-smoke.json` | D22 accept: non-default ifaces / unit names; no libexec required |

### Config install path (v1)

**v1 ships board JSON as Flutter package assets only** (`boards/**` via `AssetBundle` / `BoardProfile.loadAsset`). Installing under `/usr/share/cyber_hal/` is deferred until a product needs non-Flutter consumers.

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
  final sysInfo = StubSysInfo();
}
```

## Keyboard layouts (v1)

`LinuxKeyboard.listLayouts` ships **`us` and `ru` only**. Additional XKB layout ids are deferred to a product SKU list (image must keep `xkeyboard-config` for any id that is listed).

## App dependency

```yaml
dependencies:
  cyber_hal:
    path: ../../packages/cyber_hal
```

## Persist cohesion

HAL mid-session writes use existing FHS:

- `/var/lib/hmi/` — backlight, volume, mouse, keyboard, usb-debug
- `/var/lib/network/` — ethernet/proxy (after network wave)
- `/var/lib/wpa_supplicant/` — Wi‑Fi wanted / networks
- `/var/lib/bluetooth/` — BT

Boot re-apply is `BoardBindings.restorePersistedSettings` (HAL-owned). Do not invent a parallel `/var/lib/hal-alt/...` tree or restore shell unit.

## Status

OpenSpec `dart-hal-package`: output, input, debug, datetime, sys_info, **gpio**, **modbus**, **bluetooth**, and **network** (networkd L3 + in-HAL proxy apply) Linux backends live here. App may keep thin `lib/platform/**` façades until Demo cutover. Sim/stub profile supports P3.2 emulator prep.

## Modbus

RTU uses the in-tree Posix (`stty` + libc) transport plus attribute catalog from `boards/*/modbus.json`. A pub.dev `modbus_client` / `modbus_client_serial` dependency was evaluated but not adopted for v1: those packages route through libserialport, which fails `sp_open` with ENOTTY on this board’s kernel 6.1 + Buildroot libserialport 0.1.1. Package identity may be revisited once a suitable aarch64-friendly serial backend is confirmed.

**Device validation on aarch64/flutter-pi still required (task 4.4).**
