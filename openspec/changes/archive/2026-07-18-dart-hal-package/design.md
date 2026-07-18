## Context

Today’s HMI already abstracts hardware as Dart `*Controller` + Linux backends under `app/hmi/lib/platform/**`, calling:

- **Process / libexec:** Wi‑Fi, ethernet, backlight, volume, mouse, SSH/USB debug, BT stack helpers, `read-serial` (launch may still read a fixed `display-orientation` for flutter-pi `-o`)
- **BlueZ D-Bus:** Bluetooth primary path
- **sysfs / files:** backlight read, eth bits, LED (product), OTG
- **FFI serial:** Modbus

Today’s `platform/http` mixes **proxy prefs** (should be system-wide) with **HTTP GET probes** (App/UI). Boot restore remains `settings-restore.service` → `restore-settings.sh` + `/var/lib/{wpa_supplicant,network,bluetooth,hmi}`.

A previous design (`rust-hal-and-phase-realign`) proposed a Rust `hald` + IPC. That adds cross-language packaging, a new daemon, and dual stacks without enough payoff for the current team and already-working Dart/shell split. **This design replaces that HAL approach** with a **Dart package HAL**, analogous to CyberUI.

## Goals / Non-Goals

**Goals:**

- One **importable Dart HAL package** (submodule/subpackage), developed beside the product App and CyberUI.
- **Cohesion inside the package:** board differences, Linux backends, persist conventions, observation, optional capabilities.
- **App imports modules on demand** (`hal/network.dart`, `hal/audio.dart`, …)—no mandatory “pull everything.”
- Migrate appliance networking to **systemd-networkd** (L3) + **wpa_supplicant D-Bus** (Wi‑Fi L2); HAL exposes this under **`hal/network`** (ethernet / wifi / proxy).
- Optional modules; constructor/config-driven bindings (sysfs paths, Modbus/GPIO capability JSON).
- Import path style: `package:…/hal/network.dart`, `…/hal/network/wifi.dart`, etc.

**Non-Goals:**

- Rust/`hald` / new IPC daemon for Platform API.
- Absorbing CyberUI or product business pages into HAL.
- **App-level HTTP clients or URL probe UIs** (Demo may use `curl` against system proxy; that UI stays in App).
- **`hal/orientation` / mid-session flutter-pi `-o` switching** (D19) — panel orientation is launch/board-fixed; temporary video layout is App UI.
- **Modbus-/peripheral-derived identity** (firmware of gun, laser SW, etc.) inside sys_info — those stay product Modbus attributes.
- Forcing every SKU to ship every module.
- One image that auto-detects arbitrary motherboards.
- NetworkManager as the L3 stack (systemd-networkd is the choice).

## Decisions

### D1 — Shape: Dart package, not daemon

```
Product App                    CyberUI (separate package)
    │ import
    ▼
┌─────────────────────────────────────────┐
│  packages/cyber_hal/   (Dart HAL)       │
│  public: Managers / Device / Capabilities│
│  internal: Linux backends, profile,      │
│            persist helpers, observers    │
└──────────────────┬──────────────────────┘
                   │ Process / D-Bus / File / FFI
                   ▼
         libexec + sysfs + BlueZ + serial
         + settings-restore (boot)
```

- **No** `hald.service` as API boundary.
- Stability = package discipline (APIs, tests, fakes) + existing OS units—not a new process supervisor for HMI I/O.

### D2 — Package layout (normative intent)

**Package name (decided):** `cyber_hal`.

```
packages/cyber_hal/
  lib/
    cyber_hal.dart            # barrel: export discovery + optional show
    src/
      core/                   # Capabilities, BoardInfo, errors
      profile/                # BoardProfile load (asset or /etc path)
      network/                # barrel + ethernet / wifi / proxy (D18)
        ethernet.dart
        wifi.dart
        proxy.dart
      bluetooth/
      output/                 # D21 — backlight + volume (vs hal/input)
        backlight.dart
        volume.dart
      input/                  # D21 — keyboard + mouse
        keyboard.dart
        mouse.dart
      gpio/                   # config-driven (D13); top-level (not under io/)
      modbus/                 # config-driven (D14); top-level
      time/                   # TimeService / datetime
      sys_info/               # D17 — identity + CPU/mem/storage/thermal/runtime
      debug/                  # D20 — LAN SSH + USB OTG debug
        ssh.dart
        usb.dart
      linux/                  # Linux* backends (implementation)
  boards/
    ynh960.json               # capability flags, net roles, pointers to configs
    ynh960/
      gpio.json               # D13 — named lines (LEDs = lines)
      modbus.json             # D14 — transport + attribute catalog
  test/
    fakes/
    golden/                   # gpio/modbus config fixtures vs Demo maps
```

App `pubspec.yaml`:

```yaml
dependencies:
  cyber_hal:
    path: ../packages/cyber_hal   # or git submodule
```

Import style (package name **is** `cyber_hal` — do **not** nest a redundant `hal/` path segment):

```dart
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/network/wifi.dart';
import 'package:cyber_hal/network/proxy.dart';
// not required: bluetooth, output, …
```

Design shorthand like “network module” maps to Dart imports `package:cyber_hal/network…`, not `package:cyber_hal/hal/network…`.

### D3 — Public naming (keep industry style)

Same catalog spirit as former D12, implemented in Dart:

| Domain | Public types |
|--------|----------------|
| Core | `Capabilities`, `Capability`, `BoardInfo`, `HalError` / `UnsupportedError` |
| Network | Under `hal/network`: `NetworkManager` / devices / roles; **ethernet** + **wifi** APIs; **`ProxySettings`** / `ProxyScheme` (D18) — not a separate top-level `hal/http` |
| Bluetooth | `BluetoothManager`, `BluetoothAdapter`, `BluetoothDevice`, `PairingRequest` |
| Output | Under **`hal/output`**: `Brightness`/`Backlight`, `Volume`/`AudioManager` (D21) — **no** orientation API |
| Time | `TimeService`, `WallClock`, `TimeZone`, `TimeSyncMode` |
| Input | Under **`hal/input`**: `MouseSettings`, `KeyboardPresence`, `KeyboardLayout` (D15/D16/D21) |
| GPIO | `GpioHal` / `GpioLine` — **`hal/gpio`** config (D13); top-level module |
| Modbus | `ModbusHal` — **`hal/modbus`** config (D14); top-level module |
| Sys info | `SysInfo` — identity, CPU, memory, storage, thermal, runtime (D17 expanded) |
| Debug | Under **`hal/debug`** (D20): `SshDebug` / `UsbDebug`; optional `hal/debug/ssh` + `hal/debug/usb` |

Product status LEDs are **gpio config entries** (named lines + roles), not a separate portable `RgbLed` type and not App-hardcoded pins. **URL probe / Dart HttpClient** stay in the product App; **system proxy policy** is `hal/network/proxy`. Low-level `SerialPort` MAY exist only as an internal Modbus dependency, not a required App-facing HAL module.

Legacy `*Controller` names MAY remain as **deprecated typedefs / wrappers** in the package for one migration window, then removed.

### D4 — Optional capabilities + roles

- `Capabilities` from `BoardProfile` (+ runtime probe where cheap).
- Missing module / capability → clear unsupported; App must not assume Wi‑Fi/audio/display.
- Network API uses **`NetRole`**; profile maps to iface (`ethernet.primary`→`eth0` on ynh960). Apps never hard-code `eth0`/`wlan0` in product code.

### D5 — Persist & boot cohesion (inside package)

| Concern | Owner |
|---------|--------|
| Mid-session set + write pref | HAL Linux backend (call existing verb-noun helpers where they already persist, or write the same `/var/lib/...` paths those helpers use) |
| Boot re-apply Wi‑Fi/eth/BT/backlight/volume/proxy | Keep **`restore-settings.sh`** + systemd (outside Flutter lifetime) |
| Panel orientation | **Not HAL** (D19): fixed `flutter-pi -o` from board/image / optional launch pref; not a runtime Manager |
| Package responsibility | Document which prefs each Manager touches; **one schema**, no parallel trees; never invent `/var/lib/hal-alt/...` |

Dart HAL **must not** become the sole writer of a path that boot restore does not understand, unless restore is updated in the same change.

### D6 — What stays in App vs HAL

| In Dart HAL package | In product App |
|---------------------|----------------|
| Network / BT / **output** / **input** / **gpio** / **modbus** / **debug** / **sys_info** / datetime | CyberUI pages, welder business UX, **HTTP/URL probe UI**, **in-app layout/video rotation**, MediaMTX/camera, OTA UI |
| Board + gpio + modbus **config assets** | Which Modbus attribute ids to show (incl. lower-device “device info”) |

### D7 — Observation / stability (package-owned)

- Prefer event sources where already available (BT D-Bus today).
- Improve Wi‑Fi/eth/HID from Timer polls **inside the package** over time (netlink/wpa ctrl/udev)—no separate “event daemon” project.
- Provide **fakes** for host tests and P3.2 emulator (`Stub*` / `Sim*` backends selected by profile or `HAL_BACKEND=stub`).

### D8 — Migration from `app/hmi/lib/platform`

1. Create package; move code with history if possible (`git mv`).
2. App depends on package; re-export or update imports.
3. Rename public surface toward D3 gradually (façade period OK).
4. Add `boards/ynh960` profile + `gpio.json` / `modbus.json`; strip hard-coded tty/iface/pins/registers from App.
5. Replace `GpioLedConfig` / `*RegisterAddress` Dart constants with config-driven `hal/gpio` + `hal/modbus`.

### D9 — Relation to superseded Rust design

| Former (`rust-hal-and-phase-realign`) | This design |
|--------------------------------------|-------------|
| `hald` + protobuf IPC | Dart package in-process |
| Rust backends | Dart `linux/` backends |
| FFI optional lib | Only existing FFI (serial) as needed |
| P3.1 = Rust HAL | **P3.1 = Dart HAL package** |

CyberUI + phase roadmap documentation already updated in-tree remains authoritative for non-HAL items.

### D10 — Emulator (P3.2)

Same package; `BoardProfile` `sim` / `host` selects stub network/BT and optional real serial bridge—**no** separate native HAL binary.

### D11 — Network stack switch: systemd-networkd + wpa D-Bus

**Decision (2026-07-18):** **Replace** script/`ip`/`dhcpcd` L3 ownership with **systemd-networkd**. DNS = **systemd-resolved** (companion to networkd; no helper-written resolv.conf). Wi‑Fi L2 = **wpa_supplicant D-Bus** (`-u` mandatory; no ctrl_iface-only product fallback). Live UI/HAL status = **D-Bus** (wpa `fi.w1.wpa_supplicant1` for L2; `org.freedesktop.network1` for L3) — **not** Timer + `wpa_cli`/`ip` polling as primary. For L3 addresses, HAL SHALL prefer **`Link.Describe` JSON** (documented on current systemd including 254) and fall back to the older Link property **`Addresses`** when present. Exposed to Apps as **`hal/network`** subpackages (D18):

- `hal/network/ethernet` → `org.freedesktop.network1`
- `hal/network/wifi` → wpa D-Bus (L2) + networkd (L3)
- `hal/network/proxy` → system-wide multi-scheme proxy (not networkd)

| Concern | After switch |
|---------|----------------|
| Buildroot | Enable `BR2_PACKAGE_SYSTEMD_NETWORKD` + `BR2_PACKAGE_SYSTEMD_RESOLVED`; `BR2_PACKAGE_WPA_SUPPLICANT_DBUS`; retire “networkd/resolved must stay off” |
| eth0 / wlan0 L3 | networkd only |
| DNS | **systemd-resolved** (networkd feeds DNS; `/etc/resolv.conf` → resolved). Helpers MUST NOT write resolv.conf |
| Dual default route | Prefer **Wi‑Fi**: station metric `100`, ethernet.primary `2000` (board profile MAY override; no HTTP connectivity probe) |
| wlan0 L2 | wpa D-Bus (`run-wpa.sh` **requires** `-u`) |
| Live status | D-Bus subscribe; addresses via `Describe` (+ `Addresses` fallback); forbid primary Timer status loops |
| Persist / restore | Rebuild for networkd + wpa |
| Camera eth0 | Dynamic address via **networkd reconfigure** |
| Legacy L3 scripts | **Delete** after D11b HAL apply; interim networkd-only wrappers OK until cutover. No raw `ip addr`/dhcpcd co-management |

**Non-goal:** NetworkManager. **Non-goal:** HTTP / captive connectivity probe in HAL (product “能上网” = Wi‑Fi role preferred via metrics, not probing).

### D11b — Portable `hal/network` apply (amendment 2026-07-18)

**Problem:** Status is D-Bus, but Demo/`LinuxWifi`/`LinuxEthernet` still default to ynh960 `/usr/libexec/{network,wpa}/eth0-*`, `wlan0-*`, `wifi-stack-*`, and `wpa_cli`. That violates reuse: another product cannot import `cyber_hal` without shipping this board’s script tree.

**Decision:** Tighten D11 so **apply is in-package**, board-specific only via injection.

```
App ──► cyber_hal/network (portable)
            │ STATUS     NetworkdDbus + WpaSupplicantDbus
            │ L2 CMD     wpa D-Bus (Scan / AddNetwork / Select / Disconnect / Remove)
            │ L3 APPLY   write standard .network + networkctl or network1 D-Bus
            │ PROXY      conf file + injectable ApplyProxy (kind C)
            ▼
       Board pack (NOT inside default HAL paths)
            • WifiRadio.start/stop (firmware/SDIO/module — may call a board script)
            • NetRole → iface, RouteMetric map, pref root paths
            • restore-settings / unit names / cgroup policy
```

| Concern | Portable HAL (MUST) | Board pack (MAY) |
|---------|---------------------|------------------|
| Live status | D-Bus only as primary | — |
| L2 scan/connect/forget | wpa D-Bus methods | `wpa_cli` engineering only, not product default |
| L3 DHCP/static/link | Dart writes `/etc/systemd/network/50-hmi-<iface>.network` (or equivalent drop-in) + `networkctl reconfigure` / network1; metric from profile | Optional thin `networkd-apply` binary **without** eth0/wlan0 in the name, if Process is required for privileges — injectable argv |
| Wi‑Fi radio power / PHY | Call injected `WifiRadio` | ynh960: keep `wifi-stack-up` / `wifibt-bringup` behind that interface |
| Pref paths | From `BoardProfile` / constructor inject | Default FHS `/var/lib/{network,wpa_supplicant}/` |
| Demo | **Only** `package:cyber_hal/network` Streams/APIs | Delete parallel script controllers as product path |
| Iface-named scripts | MUST NOT be HAL defaults (`eth0-dhcp.sh`, `wlan0-dhcp.sh`, …) | Delete after cutover; boot restore calls HAL-equivalent or generic apply |

**Interim:** Existing networkd wrappers MAY remain for restore/boot until tasks §6.11–6.15 land; new code MUST target D11b APIs.

### D12 — Backend taxonomy (how each module talks to Linux)

Every HAL module documents exactly one primary kind:

| Kind | Mechanism | Modules |
|------|-----------|---------|
| **A. Device / sysfs / char-dev** | Read/write kernel nodes | `hal/output/backlight`; `hal/gpio`; `hal/modbus` (serial via `modbus_client`); `hal/debug/usb` (OTG sysfs); `hal/input` presence; **`hal/sys_info` inventory** (`/proc`, `/sys` thermal/cpufreq/mem/block) |
| **B. D-Bus** (+ in-package drop-in write for networkd) | Session/system bus clients; network L3 may write `.network` files then reload via D-Bus/`networkctl` | `hal/bluetooth` **device/adapter APIs** (BlueZ); `hal/network/ethernet`; `hal/network/wifi` (L2 **and** L3 apply — **not** iface-named shell wrappers) |
| **C. OS component / helper** | Process to mixer, player, verb-noun helper, or Dart stdlib — **all argv/paths injectable** via `BoardProfile` / constructors | `hal/output/volume` (amixer + optional A2DP helper); playback (`mpg123`); `hal/input` settings/layout prefs; `hal/datetime`; `hal/sys_info` SN/version helpers; `hal/network/proxy` apply; `hal/debug/ssh`; **board ports only:** `WifiRadio`, `BtStack` / HID-heal (not ethernet/wifi L3; not BlueZ property APIs) |

Prefs under `/var/lib/hmi/*` are **not** device files—they store last-applied policy for restore.

### D13 — `hal/gpio` config file

**Purpose:** Declare named lines and optional product semantics (e.g. status LEDs) without hard-coding pins in Dart.

**Format:** JSON or YAML (JSON preferred for Flutter `json_serializable`). Loaded in constructor: `GpioHal.fromConfigFile(path)` or `fromConfig(GpioConfig)`.

**Schema (v0):**

```json
{
  "version": 1,
  "backend": "sysfs_innohi",
  "defaults": {
    "active_low": false,
    "blink_on_ms": 1000,
    "blink_off_ms": 1000
  },
  "lines": [
    {
      "id": "led_red",
      "label": "GPIO_5",
      "path": "/sys/class/gpio_innohi/GPIO_5/value",
      "fallback_linux_gpio": 105,
      "roles": ["indicator", "alarm"]
    },
    {
      "id": "led_yellow",
      "label": "GPIO_4",
      "path": "/sys/class/gpio_innohi/GPIO_4/value",
      "fallback_linux_gpio": 106,
      "roles": ["indicator"]
    },
    {
      "id": "led_green",
      "label": "GPIO_7",
      "path": "/sys/class/gpio_innohi/GPIO_7/value",
      "fallback_linux_gpio": 149,
      "roles": ["indicator"]
    }
  ],
  "capabilities": {
    "set_level": true,
    "blink": true,
    "read_level": true
  }
}
```

**API shape:** `openLine(id)` → `GpioLine` with `set(bool)`, `get()`, `setMode(off|steady|blink)`. Unknown `id` → structured error. ynh960 ships `boards/ynh960/gpio.json`; other vendors ship their own file—**same API**.

### D14 — `hal/modbus` (config + bus scheduler + change watch)

**Decision (2026-07-18, revised after lws-ui analysis):** `hal/modbus` is not only a static attribute catalog. Grounded in lws-ui (`ModbusManagerRtu` + 100 ms status→data poll + 50 ms gate + bitfield alarms + C001 health), the HAL **owns** RTU scheduling, contiguous group reads, polling, last-good on truncate, attribute decode (including **alarm bitfields → human-readable attribute ids**), and **change-only** subscription callbacks. Product Apps MUST NOT run their own Modbus poll timers.

**Boundary (normative):**

| In HAL | In product App |
|--------|----------------|
| Transport, command gate, poll groups, busy discard | H/E/A dialog copy, episode/log policy, non-Modbus alarms (camera…) |
| Attribute catalog (regs + **bit → bool/enum attributes**) | Mapping attribute ids → UI strings / AlarmCodeEnums presentation |
| `watch*` with **per-attribute dirty set** (list of only changed) | Binding dirty attributes to widgets |
| Segment read health events (input to C001) | Optional: window mode override; dialog for C001 |
| `writeGroup` / exclusive session (OTA-class) | OTA UX / process-parameter forms |

**Purpose:** Declare transport + **poll groups** + **attribute catalog**; App talks attributes only (optional raw API for eng/debug).

**Format:** JSON preferred. Constructors: `fromConfig` / `fromConfigFile` / `fromAsset`. Transport uses existing Posix RTU path (or later `modbus_client` if validated); identity of pub.dev package remains open.

#### Schema (v1) — groups + poll + attributes (incl. bits)

```json
{
  "version": 1,
  "transport": {
    "type": "rtu",
    "device": "/dev/ttyS5",
    "baud": 115200,
    "data_bits": 8,
    "parity": "none",
    "stop_bits": 1,
    "unit_id": 1,
    "timeout_ms": 500,
    "command_interval_ms": 50
  },
  "poll": {
    "interval_ms": 100,
    "discard_if_busy": true,
    "health": {
      "window_size": 5,
      "failure_threshold": 3,
      "mode": "slide_window"
    }
  },
  "capabilities": {
    "read_holding": false,
    "read_input": true,
    "write_single": false,
    "write_multiple": true
  },
  "groups": {
    "status": {
      "space": "input",
      "start": "0x0000",
      "count": 23,
      "mode": "continuous",
      "chain": "data"
    },
    "data": {
      "space": "input",
      "start": "0x0060",
      "count": 19,
      "mode": "continuous"
    },
    "info": {
      "space": "input",
      "start": "0x0030",
      "count": 10,
      "mode": "on_demand"
    }
  },
  "attributes": [
    {
      "id": "device.control_card_version",
      "access": "r",
      "group": "status",
      "register": { "space": "input", "address": "0x0002", "count": 1 },
      "decode": { "type": "u16" }
    },
    {
      "id": "alarm.gun_comm",
      "access": "r",
      "group": "status",
      "register": { "space": "input", "address": "0x0009", "count": 1 },
      "decode": { "type": "bit", "bit": 0, "active_high": true },
      "meta": { "alarm_code": "H001", "label": "Gun head communication" }
    },
    {
      "id": "telemetry.gun_motor_temp",
      "access": "r",
      "group": "data",
      "register": { "space": "input", "address": "0x0061", "count": 1 },
      "decode": { "type": "s16", "scale": 0.1, "unit": "C" }
    }
  ]
}
```

Notes:

- **`poll.interval_ms`:** configurable; **default 100** when omitted (lws-ui parity).
- **`transport.command_interval_ms`:** default **50**.
- **Groups** drive contiguous FC reads; attributes bind into a group (HAL MUST NOT issue one frame per attribute for continuous poll).
- **Bit alarms:** `decode.type = bit` → bool attribute + optional `meta.alarm_code` / `label`.
- **Repeat remind (product):** **off by default** (`poll.alarm_remind.enabled` default **false**). When enabled, while an alarm attribute stays **active** (`true`), HAL MAY re-emit watch events with `kind: reminder` on an interval from `meta.remind_interval_ms`, or `poll.alarm_remind.default_interval_ms` (default **30000**) when `alarm_code` is set. `remind_interval_ms: 0` disables per attribute. Rising-edge stays `kind: changed` (Apps SHOULD log INSERT only on changed, not reminder). Dialog copy / resist-ack policy remains in the App (lws-ui episode style).
- Same numeric address MAY exist in **input** vs **holding** (lws-ui process params); `space` is required.
- ynh960 ships full status/data/info maps over time; Demo MAY subscribe a subset of attribute ids.

#### API shape (normative)

```dart
// One-shot (kept)
Future<Object?> readAttribute(String id);
Future<void> writeAttribute(String id, Object? value);
Future<ModbusGroupSnapshot> readGroup(String groupId);
Future<void> writeGroup(String groupId, Map<String, Object?> values);

// Scheduler (HAL-owned)
Future<void> startPolling({Iterable<String>? groupIds}); // default: all continuous groups
Future<void> stopPolling();
Future<T> exclusiveSession<T>(Future<T> Function(ModbusSession io) body); // pause poll (OTA)

// Observation — change-only, attribute granularity
Stream<List<ModbusAttributeChange>> watchAttributes({
  Iterable<String>? ids, // null/omit = all attributes covered by active poll
});
// Each event: ONLY attributes whose decoded value changed since last emit.
// Empty list MUST NOT be emitted.
// First event after subscribe MAY include full current snapshot as "changes"
// (previous = null) so UI can paint without a separate read — or document
// "prime via readAttributes then watch"; prefer first full prime as changes
// with previous=null for App simplicity.

Stream<ModbusHealth> watchHealth(); // per-group success/truncate/timeout; C001 input
```

`ModbusAttributeChange`: `{ id, value, previous }` (`previous` null on first prime).

**Change detection:** compare decoded attribute values (bool/num/string equality after decode/scale). Unchanged attributes MUST NOT appear in the callback list. Multiple attributes MAY change in one poll cycle → **one list callback** containing only those that changed.

**Poll mechanics (from lws-ui):**

1. Timer tick every `poll.interval_ms` (default 100).
2. If exclusive session, command in flight, or cycle in flight → **discard** tick when `discard_if_busy` (default true).
3. For each continuous group in chain order (e.g. status then data): one contiguous read; wait `command_interval_ms` between commands.
4. On truncate/failure: keep last-good attribute values for that group; record health failure.
5. Decode all attributes in the group; diff vs previous; emit `watchAttributes` with dirty list only.

**Non-goals for HAL:** Warn dialog policies, rising-edge log INSERT into product DB, camera alarms, owning AlarmCodeEnums UI strings (optional `meta.alarm_code` is a hint only).

### D15 — Physical keyboard layout: XKB pref + HMI restart (v1)

**Decision (2026-07-18, revised):** USB/BT HID layout switching (e.g. US → Russian) is **XKB inside flutter-pi** (`libxkbcommon` + `xkeyboard-config`), not a Dart character remap and not CyberIME.

**Why:** HID only delivers scancodes; characters come from XKB. The image already depends on this path (`/etc/default/keyboard`, `/usr/share/X11/xkb`). Soft-keyboard layouts stay in **CyberIME** (P3.0)—separate from physical HID.

**v1 apply (simple):** write preference → **restart flutter-pi / `hmi.service`** so XKB is re-read at keyboard init. **No** new flutter-pi hot-reload patch required for v1.

**UX (acceptable):** the screen may flash briefly on restart. Product App / Demo SHALL **restore navigation to the previous route/page** after relaunch (e.g. persist last route and open it on startup) so operators are not dumped on home. Most appliances rarely change layout and often have no keyboard attached—this is fine vs mid-session XKB reload complexity.

(Unlike fixed panel orientation, layout switching remains a supported Settings/Demo action.)

| File | Role |
|------|------|
| `/etc/default/keyboard` | Factory / image default; also what flutter-pi reads today at start |
| `/var/lib/hmi/keyboard.conf` | Optional runtime pref (same keys as below); `hmi-launch` / restore MAY sync into `/etc/default/keyboard` before start |

Example (or keep Debian-style `XKBLAYOUT=` in `/etc/default/keyboard`):

```text
layout=ru
variant=
options=
model=pc105
```

Dual layout with physical toggle (optional):

```text
layout=us,ru
options=grp:alt_shift_toggle
```

**Apply path (v1):**

1. `hal/input/keyboard.setLayout(...)` writes pref (and/or `/etc/default/keyboard`).
2. Restart flutter-pi / `hmi.service` so XKB rebuilds at init.
3. App restores the **previous page/route** after restart (HAL may only signal “restart required”; route restore is App responsibility, or a tiny shared helper in the App shell).
4. Boot: launch already picks up `/etc/default/keyboard` — no mid-session machinery.

**HAL API:** presence (by-id) + `getLayout` / `setLayout` / `listLayouts()`; `setLayout` documents that apply restarts flutter-pi and that the **App** should restore the prior route after relaunch.

**Non-goals / forbidden (v1):**

- Dart remapping of HID scancodes
- `SIGHUP` to flutter-pi (unsafe with current service)
- Folding CyberIME soft layouts into this pref

**Follow-on (optional, not blocking):** mouse.conf-style mtime hot-reload inside flutter-pi so layout changes without HMI restart — same class of patch as `0005-mouse-settings-prefs`, defer until product asks.

**Image deps:** keep `BR2_PACKAGE_XKEYBOARD_CONFIG` so `ru` (etc.) exist under `/usr/share/X11/xkb`.

### D16 — `hal/mouse`: formalize existing pref contract

**Decision (2026-07-18):** `hal/mouse` **adopts the P2.1 mouse pipeline as-is**. No new preference schema, no new flutter-pi protocol, no Dart-side pointer synthesis. HAL work is package move + stable public API over the existing contract.

**Pipeline (normative):**

```text
App / Demo
  → MouseSettings get/set (HAL)
  → apply-mouse-settings (stdin → atomic write)
  → /var/lib/hmi/mouse.conf
  → flutter-pi mtime poll (0005 / 0009 axes) → libinput + cursor
```

**Preference file** `/var/lib/hmi/mouse.conf` (key=value; unknown keys ignored):

| Key | Values | Role |
|-----|--------|------|
| `natural_scroll` | `0`/`1` (or true/false) | Natural scrolling |
| `scroll_speed` | 0–100 | Wheel scale |
| `pointer_speed` | 0–100 | Maps to libinput accel ∈ [-1, 1] |
| `pointer_size` | 0–100 | Cursor visual size (flutter-pi icon density) |
| `primary_button` | `left` / `right` | Flutter primary click |
| `pointer_axes` | `auto` / `normal` / `swap` | REL/ABS axis handling; `auto` swaps for BT keyboard+pointer combo devices |

**HAL split:**

| Concern | Backend kind | Mechanism |
|---------|--------------|-----------|
| Presence | A | Read `/dev/input/by-id` (by-path USB mouse fallback); later udev Stream OK |
| Settings | C | Read conf; write via `apply-mouse-settings` (injectable path + command for tests) |

**Public API:** `MouseSettings` value object + get/set; presence status (and optional watch). Constructor MAY inject `preferencePath` and apply helper argv.

**Non-goals / forbidden:**

- Synthesizing pointer events in Dart
- Parallel pref tree (e.g. `/var/lib/hal/...`)
- Applying settings via `SIGHUP` or `systemctl restart hmi`
- Owning BT pair/HOGP inside mouse (stays `hal/bluetooth`); mouse only consumes enumerated pointer devices + `pointer_axes`

**Migration:** `git mv` `MouseSettings` / `LinuxMouseSettingsController` / mouse probe from `app/hmi/lib/platform/input/` into the HAL package; Demo re-imports. flutter-pi mouse patches stay; D16 does **not** require a new pi patch.

### D17 — `hal/sys_info` (host inventory + telemetry; not Modbus)

**Decision (2026-07-18, expanded):** Provide **`hal/sys_info`** for **host/board** identity, capacity, and common runtime telemetry readable from Linux on the SoC. **Remove** planned `hal/http` and `hal/device_info` modules.

Motherboards (incl. RK356x) typically expose this via **procfs/sysfs** (+ a few helpers). HAL abstracts it so product Apps do not scrape `/proc` themselves.

**In scope — grouped snapshot (v1):**

| Group | Fields (portable) | Typical Linux source |
|-------|-------------------|----------------------|
| **Identity** | Board SN; DT/board model; kernel release; optional image/`os-release` / build id; Flutter app version/build | `read-serial`; `/proc/device-tree/model`; `uname -r`; `/etc/os-release` or image stamp; App inject or `/opt/hmi/version` |
| **CPU** | Logical core count (online/present); model/compatible string; per-core or summary **current** and **max** frequency (kHz/MHz) | `/proc/cpuinfo`; `/sys/devices/system/cpu/…/cpufreq/` |
| **Memory** | Total RAM; available (or free+buffers/cache per MemAvailable) | `/proc/meminfo` |
| **Storage** | Flash/block capacity for primary root and userdata (bytes); optional free space | `/sys/block/mmcblk*/size`, `statvfs` / `df` on `/` and `/userdata` (paths from board profile) |
| **Thermal** | Named thermal zones: type/label + temperature (°C or m°C as documented) | `/sys/class/thermal/thermal_zone*` |
| **Runtime** | Uptime; load average (1/5/15) | `/proc/uptime`; `/proc/loadavg` |

**Optional / capability-gated (v1 MAY stub unsupported):**

| Field | Notes |
|-------|--------|
| NPU / accelerator present | Probe known sysfs/nodes when board profile advertises `rknpu` (etc.) — capability flag, not a hard fail |
| GPU freq/temp | Only if sysfs exists; omit silently when absent |
| A/B slot letter | Read from existing ab helpers / misc — useful on About screen; optional |

**Out of scope:**

- HTTP/URL probe UI → App
- Modbus/lower-device firmware, gun SN, temperatures from welder → **`hal/modbus`**
- System proxy → **`hal/network/proxy`**
- Live network addresses / Wi‑Fi SSID → **`hal/network`** (sys_info MUST NOT become a second network API)
- Continuous high-rate profiling (perf, top) — not a HAL goal

**API shape:**

- `SysInfo.snapshot()` → structured object with the groups above; missing fields → null/unavailable (Demo may show `-`)
- `SysInfo.watch({interval})` → primed then change-only updates when thermal / CPU freq / available RAM / load change (default interval 1s; discard-if-busy)
- Backend kind: primarily **A** (procfs/sysfs) + **C** for `read-serial` / version stamp injection

**Rationale:** About / engineering screens need host inventory on every product; Modbus “device information” stays product-specific. Keep one `hal/sys_info` rather than splitting `hal/cpu` / `hal/thermal` until a product needs independent lifecycle.

### D18 — `hal/network` (ethernet + wifi + proxy)

**Decision (2026-07-18):** Collapse top-level `hal/ethernet` / `hal/wifi` into one **`hal/network`** module with **subpackages**:

| Subpackage | Role | Backend |
|------------|------|---------|
| `hal/network/ethernet` | Link, DHCP/static, addresses, routes for ethernet roles | networkd D-Bus + in-package `.network` apply (D11/D11b) |
| `hal/network/wifi` | Scan, associate, then L3 on wifi iface | wpa D-Bus commands + networkd apply (D11/D11b); board `WifiRadio` for PHY |
| `hal/network/proxy` | **System-wide** outbound proxy policy | OS env + injectable apply helper (kind C) |

Import: `package:cyber_hal/network.dart` barrel; Apps MAY import only `package:cyber_hal/network/wifi.dart` or `package:cyber_hal/network/proxy.dart`.

#### Proxy: multi-scheme + visible to CLI (env)

**Problem with today’s `/var/lib/hmi/http-proxy`:** HTTP(S)-only, consumed mainly by Dart `HttpClient`. Setting it does **not** make shell CLIs that honor `http_proxy` / `https_proxy` / `all_proxy` use the proxy.

**Normative contract:**

1. **Canonical persist:** `/var/lib/network/proxy.conf` (network FHS; migrate off `/var/lib/hmi/http-proxy`). Credentials allowed; never log passwords.
2. **Apply helper:** `/usr/libexec/network/apply-proxy` (or `/usr/bin/apply-proxy`) invoked by HAL on set/clear and by `settings-restore` on boot.
3. **Schemes / slots (not HTTP-only):** at least:

| Slot / env | Typical URI schemes |
|------------|---------------------|
| `http_proxy` / `HTTP_PROXY` | `http://`, `https://` (proxy-to-proxy HTTP) |
| `https_proxy` / `HTTPS_PROXY` | same |
| `ftp_proxy` / `FTP_PROXY` | `http://`, `ftp://` |
| `all_proxy` / `ALL_PROXY` | catch-all; often `socks5://`, `socks5h://`, `socks4://`, `socks4a://` |
| `no_proxy` / `NO_PROXY` | comma host/suffix/IP list |

HAL API MAY expose a structured `ProxySettings` (enabled, per-slot URI or host/port/user/pass/`ProxyScheme`, `noProxy` list) and MUST serialize to conventional proxy env URLs. Supported **`ProxyScheme`** values SHALL include at least: `http`, `https`, `socks4`, `socks4a`, `socks5`, `socks5h` (DNS via proxy), and `ftp` where applicable.

4. **Where apply writes (so CLI tools work):**

| Target | Purpose |
|--------|---------|
| `/var/lib/network/proxy.env` | `KEY=value` lines (lower + UPPER) for `EnvironmentFile=` |
| `/etc/profile.d/zz-network-proxy.sh` | `export` for interactive/login shells (SSH / host shell) |
| `/etc/environment` (managed block or full file discipline) | PAM / non-systemd consumers |
| systemd `DefaultEnvironment=` drop-in under `/etc/systemd/system.conf.d/` **or** per-unit `EnvironmentFile=` for `hmi.service` and other product units | services started by systemd |

5. **Acceptance:** After `setProxy` / apply + new shell (or sourced env). The product image **MAY omit curl/wget**; gate on env visibility:

```bash
env | grep -i proxy                    # shows expected vars when enabled
# or: cat /var/lib/network/proxy.env /etc/profile.d/zz-network-proxy.sh
# optional if curl is present (host or debug image):
# curl -I https://example.com
```

When disabled/cleared, apply **removes** exports and empties env files so tools do not keep a stale proxy.

6. **App vs HAL:** Demo “Send request” SHOULD prefer a process that inherits the applied env when a suitable CLI exists. A Dart `HttpClient` that only reads the conf file is **insufficient** as the sole acceptance path. App MAY still configure its own client from `ProxySettings` for in-process UI, but MUST NOT be the only apply path.

7. **Restore:** `restore-settings` reapplies proxy via the same helper so reboot restores CLI-env-visible policy.

**Non-goals:** Transparent mandatory proxy via iptables/REDSOCKS as v1; PAC file engine as v1 (MAY add later as optional URL field); requiring `curl`/`wget` in the appliance rootfs.

### D19 — No `hal/orientation` (fixed panel; App owns layout flips)

**Decision (2026-07-18):** Do **not** ship a portable HAL orientation Manager. Demo MUST NOT expose Portrait/Landscape system settings.

**Rationale:** Appliance HMIs normally run a **fixed** panel orientation for the product chrome. Changing flutter-pi `-o` requires restarting HMI and is not a useful Settings surface. Cases like “play video in landscape while the shell is portrait” are **Flutter widget / route layout** in the product App—not OS display-orientation policy.

**What remains outside HAL (optional OS/board):**

- Image or board default: `hmi-launch.sh` may still pass a fixed `-o` from `/var/lib/hmi/display-orientation` or a compile-time default.
- Operators/engineering MAY change that file offline; it is **not** a HAL public API and **not** a Demo control.

**Migration:** Remove Demo orientation UI; do not move `LinuxFlutterPiOrientation` into the HAL package as a public module. Legacy Dart/helpers MAY linger for launch until cleaned up, but MUST NOT be advertised as HAL.

### D20 — `hal/debug` (LAN SSH + USB OTG)

**Decision (2026-07-18):** Merge the former top-level `hal/ssh_debug` and `hal/usb_debug` into one optional package **`hal/debug`**.

| Surface | Role | Backend |
|---------|------|---------|
| `hal/debug` (barrel) | Engineering debug toggles used by Demo «Debug» group | — |
| `hal/debug/ssh` (or `SshDebug`) | On-demand LAN/WLAN SSH (`enable-ssh-debug` / `disable-ssh-debug`; typically not persisted) | C — helpers |
| `hal/debug/usb` (or `UsbDebug`) | Micro-USB plug-ssh vs host (`usb-otg-mode` / `/var/lib/hmi/usb-debug`) | **A preferred** (OTG sysfs) with optional injectable helper; MUST NOT bury RK-only PHY paths as non-overridable Dart constants |

Apps MAY `import …/hal/debug.dart` for both, or import only `hal/debug/ssh` / `hal/debug/usb`. Product SKUs without USB OTG or without LAN SSH MAY omit the unused sub-API via capabilities.

**Non-goals:** Absorbing `make shell` / host `scripts/device-logs.sh` into HAL; those remain host/operator tools.

### D21 — Domain grouping: output + input (gpio/modbus stay separate)

**Decision (2026-07-18, revised):**

| Package | Subpackages | Why |
|---------|-------------|-----|
| **`hal/output`** | `backlight`, `volume` | Human-facing **output levels** (brightness + loudness); pairs with `hal/input`. Prefer this name over `media` (not A/V playback). |
| **`hal/input`** | `keyboard`, `mouse` | HID presence + prefs |

**Not grouped:** **`hal/gpio`** and **`hal/modbus`** remain **separate top-level** modules. Umbrella names (`io`, `field`, `machine`) were rejected as too broad or product-specific; both stay config-driven (D13/D14) without a forced parent package.

Import examples: `package:cyber_hal/output/volume.dart`, `package:cyber_hal/input/keyboard.dart`, `package:cyber_hal/gpio.dart`, `package:cyber_hal/modbus.dart`.

### D22 — Cross-module portability (amendment 2026-07-18)

**Problem (audit):** Network was the loudest script-shaped HAL, but other modules share the same reuse failure mode: `BoardProfile` is unused by Linux backends; absolute `/usr/libexec/...` defaults (some **non-injectable**); iface-named helper names; Demo is already on HAL for these modules (good) but defaults still assume ynh960.

**Severity (excl. network):**

| Rank | Module | Issue |
|------|--------|--------|
| 1 | `hal/bluetooth` | Defaults require `/usr/libexec/bluetooth/bt-stack-*`, A2DP, agent, alias; **`bt-hid-heal.sh` / `/run/bt-hid` not injectable** |
| 2 | `hal/datetime` | Default helper `/usr/libexec/wpa/wlan0-time-sync.sh` (iface-named smell) |
| 3 | `hal/output/volume` | A2DP path `/usr/libexec/bluetooth/bt-a2dp-volume.sh` hard-coded |
| 4 | `hal/debug/usb` | Dart is helper-only; shell embeds RK356x USB2 PHY sysfs — design A not met in Dart |
| 5 | ssh / backlight / mouse / keyboard restart | Injectable but defaults = this appliance |
| 6 | gpio / modbus / sys_info inventory | Config/`/proc` OK; wire profile for assets/mounts; ynh960 defaults only for Demo |

**Decision:**

1. **`BoardProfile` is live wiring** — Linux backends for network, bluetooth, datetime, debug, output, input, sys_info SHALL accept profile and/or constructor injectors for helper argv, pref roots, unit names, and board ports. Profile-only-in-tests is insufficient.
2. **`hal/bluetooth` portable core = BlueZ D-Bus** (adapter/device/pair/connect). Stack bring-up, A2DP sink unit orchestration, agent ensure, HID heal → injected **`BtStack`** (or split ports). ynh960 MAY implement ports by calling existing `bt-*` scripts; HAL MUST NOT leave heal paths as private `static const` only.
3. **Kind C helpers:** every Process default MUST be overridable; prefer verb-noun names **without** iface prefixes (`sync-time` not `wlan0-time-sync.sh` as the HAL default).
4. **`hal/debug/usb`:** prefer reading/writing documented OTG sysfs from Dart (kind A) with injectable node path from profile; helper remains optional fallback for complex role flips.
5. **gpio / modbus:** keep config-driven; App/Demo SHOULD load assets via profile pointers (`gpioConfigAsset` / `modbusConfigAsset`), not only hard-coded `kYnh960*` constants.
6. **Non-goal:** rewrite every shell helper into Dart in one pass — injection + board ports first; delete dead non-injectable constants.

### Module catalog (summary)

| Module | Subpackage | Backend | Binding |
|--------|------------|---------|---------|
| **hal/network** | ethernet | B | networkd; board roles |
| | wifi | B | wpa D-Bus + networkd |
| | proxy | C | multi-scheme; curl-visible apply (D18) |
| **hal/bluetooth** | — | B + board C ports | BlueZ D-Bus core; stack/A2DP/heal via injectable `BtStack` (D22) |
| **hal/output** | backlight | A (+ optional C set) | sysfs + pref; helper injectable |
| | volume | C | amixer + pref; A2DP helper **injectable** (D22) |
| **hal/input** | keyboard | A+C | by-id + XKB pref; **v1 apply = restart hmi** (D15) |
| | mouse | A+C | by-id + `mouse.conf` (D16) |
| **hal/gpio** | — | A | `gpio.json` via profile asset pointer (D13/D22) |
| **hal/modbus** | — | A | `modbus.json` via profile; HAL poll/watch (D14/D22) |
| **hal/sys_info** | — | A+C | identity, CPU, RAM, flash, thermal, uptime; mounts from profile (D17/D22) |
| **hal/debug** | ssh | C | injectable enable helper |
| | usb | A (+ optional C) | OTG sysfs path from profile (D20/D22) |
| **hal/datetime** | — | C | timedatectl / date / hwclock; sync helper without iface-named default (D22) |

**Not HAL modules:** `hal/http`; `hal/orientation` (D19); `hal/media` / `hal/io` (superseded naming); flat `hal/backlight`/`volume`/`keyboard`/`mouse` as long-term primary paths (use `output`/`input`); separate `ssh_debug`/`usb_debug` (use `hal/debug`); former `device_info`.

### Interim implementation order

**Principle:** ship easy lifts first; leave **networkd + `hal/network`** (largest churn) for last.

1. Package scaffold (`packages/cyber_hal/`, ynh960 profile + gpio/modbus JSON stubs). ✅
2. Lift low-churn modules: `hal/output`, `hal/input`, `hal/debug`, `hal/datetime`, `hal/sys_info` (+ Demo cutover). ✅
3. Config-driven `hal/gpio` + one-shot `hal/modbus` attribute catalog. ✅
4. **Modbus dynamic layer (D14 revised):** poll groups, bit→attribute maps, `watchAttributes` change-only, health — tasks 4.4–4.8.
5. `hal/bluetooth` move + battery keepalive. ✅
6. **Last:** OS networkd/wpa cutover + `apply-proxy` + `hal/network` {ethernet, wifi, proxy}.
7. **D11b** portable network apply + **D22** cross-module injection / `BtStack` / profile wiring.
8. Camera eth0 → networkd reconfigure when P4/P5 needs it (after network wave).
9. Optional follow-on: keyboard layout hot-reload without HMI restart (flutter-pi patch).

## Risks / Trade-offs

- [Flutter owns mid-session I/O] → OK for single-UI appliance; boot restore outside HMI cgroup.
- [networkd migration cost] → Accepted (D11); OS cutover first, then **D11b portable apply**.
- [Script-shaped HAL] → Status D-Bus but apply via ynh960 libexec blocks reuse — **D11b** (network) + **D22** (bluetooth/helpers/profile).
- [Bluetooth bt-* tree] → Accepted until D22 `BtStack` injection; BlueZ D-Bus core stays portable.
- [Modbus poll load on Linux] → Default 100 ms + 50 ms gate matches lws-ui; interval is configurable if board budget requires slower.
- [Config file drift vs lws-ui registers/bits] → Version field + golden tests; expand ynh960 `modbus.json` to status/data bit maps.
- [flutter-pi keyboard hot-reload] → **Not required for v1** (D15 uses HMI restart); optional follow-on only.
- [Dual network stacks during interim] → Until D11b Demo cutover, App may still call legacy controllers; do not add new script call sites.

## Migration Plan

1. Finalize this OpenSpec (taxonomy + config schemas + D15–D21 + **D14 poll/watch**). ✅ (D14 revised 2026-07-18)
2. Scaffold HAL package; lift easy modules. ✅
3. gpio + one-shot modbus + bluetooth. ✅
4. **Complete modbus scheduler + watch + full ynh960 attribute/bit catalog** (tasks 4.4–4.8).
5. Network OS milestone (networkd + resolved + wpa D-Bus + apply-proxy). ✅ / in progress (6.2b gate)
6. **D11b portable apply** (tasks 6.11–6.17): L3 in HAL, wpa D-Bus commands, inject WifiRadio, Demo cutover, delete iface-named wrappers.
7. **D22 cross-module portability** (tasks 8.1–8.7): BoardProfile wiring, `BtStack`, injectable heal/A2DP/time/usb paths.
8. Optional: keyboard XKB hot-reload; P3.2 stubs.

## Open Questions

1. Board/gpio/modbus configs: Flutter assets only vs also `/usr/share/cyber_hal/`? **Decided (task 7.3):** v1 = Flutter package assets only (`boards/**` via AssetBundle). `/usr/share/cyber_hal/` deferred until a non-Flutter consumer needs it.
2. Exact pub.dev (or fork) identity of `modbus_client`? (Posix RTU remains acceptable.)
3. ~~`systemd-resolved` with networkd for v1, or keep file-based resolv?~~ **Decided (2026-07-18):** enable **`systemd-resolved`** with networkd. Drop hand-written resolv sync from `networkd-apply-ipv4.sh`.
4. D15: which layout ids beyond `us` / `ru`? **Decided (task 7.4):** v1 = `us` / `ru` only.
5. First `watchAttributes` emission: full prime as changes with `previous=null`? **Prefer yes** (D14).
6. E-stop “clear false comm bits” normalize in HAL vs App? (lws-ui does it in convert — decide when implementing bit maps.)
7. ~~Connectivity HTTP probe in HAL?~~ **Decided:** no probe; dual-default prefers Wi‑Fi via RouteMetric (D11).
8. L3 apply privileges: pure Dart write to `/etc/systemd/network` vs injectable helper binary? **Prefer Dart + `networkctl`/`busctl` first;** if permission model blocks, one generic injectable apply binary (no `eth0`/`wlan0` in the name).
9. Bluetooth: single `BtStack` port vs split stack/A2DP/heal ports? **Prefer one `BtStack` façade** with optional null A2DP/heal for headless SKUs.
