# HAL product contract (portability)

Source of truth for **what a new product must prepare** to use `package:cyber_hal`.
Smoke notes for OpenSpec `dart-hal-package` (6.17 / 8.7) and zero-script defaults.

Related: [`network-stack.md`](network-stack.md) (OS network ownership + modem bring-up),
[`packages/cyber_hal/README.md`](../packages/cyber_hal/README.md) (module map).

---

## Principles

1. **Linux appliance only** — `cyber_hal` targets Buildroot / eLinux. It does **not**
   ship Android backends; P5.0 APK work uses App-side Android / `YNHAPI` adapters.
   `Linux*` names mark Linux implementations vs abstract APIs / `Stub*`.
2. **Portable core in HAL** — D-Bus / sysfs / `systemctl` / `ip` / `amixer` / file prefs.
   Constructor defaults **MUST NOT** hard-code `/usr/libexec/...`.
3. **Board pack** — `BoardProfile` + `BoardBindings(profile)` declare ifaces, metrics,
   config assets, and **only** board-specific helpers.
4. **Missing portable semantic → explicit failure** — e.g. SSH/USB without inject →
   `HalUnsupportedException`, not a silent ynh960 script path.
5. **Persist + restore are HAL-owned** — `BoardBindings.restorePersistedSettings`
   (+ session `syncFromSystem`). Kind C ops scripts (`change-backlight`,
   `apply-proxy`, `restore-settings.service`, …) are **retired**.

---

## Recommended interface names

HAL resolves ifaces from `BoardProfile.net_roles` and supports arbitrary names
(see `boards/portable-smoke.json`: `enp1s0` / `wlp2s0`).

**Recommendation for new boards:**

| Role | Recommended netdev | Profile key |
|------|--------------------|-------------|
| Primary Ethernet | **`eth0`** | `net_roles["ethernet.primary"]` |
| Wi‑Fi station | **`wlan0`** | `net_roles["wifi.station"]` |

Use udev/`systemd.link` (or driver) so the first Ethernet and first wireless land
on these names. Pref paths and docs in this repo assume `eth0` / `wlan0`; other
names work if the profile and `route_metrics` match.

---

## Per-module contract

Legend: **OS** = required on image; **Profile** = declare in `BoardProfile`;
**Helper** = optional `helpers.*` inject; **Asset** = Flutter JSON owned by the
**product App** (or pack), not by motherboard name inside `cyber_hal`.

### `hal/network` — ethernet / wifi / proxy

| Need | Detail |
|------|--------|
| **OS** | `systemd-networkd` + `systemd-resolved`; `networkctl` present |
| **OS** | `wpa_supplicant` built with D-Bus (`-u`); unit that runs `-u -i <iface>` (default name **`wlan-wpa.service`**, override `helpers.wifi_wlan_unit`) |
| **OS** | Mask/stop empty stock `wpa_supplicant.service` so it does not steal `fi.w1.wpa_supplicant1` |
| **OS** | `ip` on PATH |
| **Profile** | `net_roles` → ifaces; optional `route_metrics` (board defaults). **Product** chooses the internet uplink via [PrimaryNetworkController] (`getPrimaryRole` / `setPrimaryRole`) → `/var/lib/network/primary.conf`; same board may use Wi‑Fi or Ethernet as primary. |
| **Helper** | `wifi_modem` — **required when wireless netdev is not present at boot** (SDIO/USB/UART combo firmware). See [`network-stack.md`](network-stack.md) § Modem bring-up |
| **Helper** | `wifi_wlan_unit` — only if unit name ≠ `wlan-wpa.service` |
| **Helper** | `apply_proxy` — optional override; default is in-HAL env/profile/systemd drop-in apply |
| **Legacy** | Both `wifi_stack_up` + `wifi_stack_down` → `ScriptWifiRadio` (transition only) |

Proxy prefs: `/var/lib/network/proxy.conf`. No NetworkManager.

### `hal/bluetooth`

| Need | Detail |
|------|--------|
| **OS** | **Upstream** BlueZ (`bluetooth.service` / `bluetoothd`); system D-Bus policy for `org.bluez` |
| **OS** | `Device1.Connect` / `Disconnect` / `CancelPairing` use **empty** D-Bus signatures (stock BlueZ) |
| **OS** | HCI adapter visible after modem/firmware (if any) |
| **Helper** | `bt_modem` — same class as Wi‑Fi modem when combo UART/SDIO must be attached before HCI exists |
| **Helper** | `bt_bluetooth_unit` — if unit ≠ `bluetooth.service` |
| **Helper** | `bt_a2dp_up` / `bt_a2dp_down` / `bt_a2dp_volume` — only if product offers A2DP sink |
| **In-HAL** | Connect = Trust + Connect so BlueZ `[Policy]` may auto-reconnect after **link loss**. User Disconnect = Untrust + Disconnect (sticky until next Connect). Paired+Connected with Trusted=no is healed by auto-Trust (skipped while sticky). HAL attaches HOGP/evdev when Connected; sticky LE (Connected but no ServicesResolved / no evdev) uses Untrust→Disconnect→Trust→Connect refresh. `inputReady` requires Connected **and** ServicesResolved **and** matching evdev (stale uhid alone is not ok). ~15s keepalive tick rechecks HID health and auto-ensures Connected-but-not-ready (45s cooldown) — Reconnect in Demo is fallback only; no image `bt-hid-heal`. **Retired:** image `bt-hid-heal.service` / `bt_hid_heal` / `/run/bt-hid` authority |
| **Legacy** | Both `bt_stack_up` + `bt_stack_down` → `ScriptBtStack` |

Product write path is BlueZ D-Bus only (**no** runtime `bluetoothctl` / `busctl` shell). Optional board diagnostic: `bt-hid-check.sh` (not a HAL helper).

**SDK note:** Rockchip’s `0001-bluez-modified-only-for-rockchip.patch` (Connect/`ADDR_TYPE` string args) is **disabled by** `scripts/apply-overlay.sh` → `sync_bluez5_utils_stock` so images build portable upstream BlueZ (overlay pin ≥ **5.87**). Do not re-enable that fork for HAL portability.

### `hal/output` — backlight / volume / orientation

| Need | Detail |
|------|--------|
| **OS (backlight)** | `/sys/class/backlight/<name>/brightness` (+ `max_brightness`) |
| **Profile** | `helpers.backlight_preferred_names` — comma list of preferred basenames (default tries `backlight`, `backlight1`, `backlight2`) |
| **OS (volume)** | ALSA `amixer`; controls that accept percent (`sset … N%`) |
| **Profile** | `helpers.alsa_volume_controls` — preferred mixer control names (board codec order) |
| **Profile** | `helpers.alsa_playback_path_control` + `alsa_playback_path_value` — **optional** enum route (e.g. Rockchip `Playback Path` / `RING_SPK_HP`). Omit on boards that have no such control; HAL skips routing when unset |
| **Helper** | `change_backlight` / `change_volume` — **optional**; default is sysfs / amixer + `/var/lib/hal/` prefs |
| **Prefs** | `/var/lib/hal/display.conf` — `backlight`, `auto_sleep`, `orientation` (`landscape` \| `portrait`), `wallpaper` / `wallpaper_id` (active image under `/var/lib/hal/wallpaper.*`; presets in `/usr/share/hal/wallpapers/`), **`ui_scale`** (operator UI scale multiplier; **`1.0` = physical 1:1 / no rematch**; non-integer OK e.g. `0.85`–`2.0`; **OS Settings** writes; both seats apply via `matchEmbedderDensity`; OEM screen pack seeds `default_ui_scale` on first boot when the key is absent — e.g. ynh960 ~`1.13`, QEMU `sim-virt` ~`1.28`; factory reset clears operator `display.conf` and re-seeds on next `hmi-launch`); `/var/lib/hal/sound.conf` — `volume`, `button_feedback` (**absolute path** to click sample next to conf; product App `installAndSelect`s catalog bytes) |
| **Orientation** | Portable `Orientation` API; Linux calls `change-orientation` then `restart-flutter-seat.sh` (active HMI or OS Settings). Mapping stays in `hmi-launch.sh` (Weston transform). |
| **Helper** | `bt_a2dp_volume` — optional A2DP soft-volume when BlueALSA sink is used |

### `hal/input` — keyboard / mouse

| Need | Detail |
|------|--------|
| **OS (keyboard)** | HID keyboard nodes; `xkeyboard-config` for layouts listed by HAL (`us`, `ru` in v1); `restart-flutter-seat.sh` when layout apply restarts UI |
| **OS (mouse)** | `apply-mouse-settings` → `mouse.conf`; Weston ini change restarts active Flutter seat via `restart-flutter-seat.sh` |
| **OS (wallpaper)** | `apply-wallpaper` persists; HAL `setPreset(apply: true)` calls `restart-flutter-seat.sh` |
| **OS (mouse)** | USB HID mouse (presence probe); prefs in `/var/lib/hal/mouse.conf` |
| **Helper** | `apply_mouse_settings` — **required**: helper rewrites runtime `weston.ini` via `weston-hmi-config.sh` (`cursor-size`, `[libinput]` accel / natural-scroll / left-handed; **desktop-shell** + splash background unchanged) and restarts `hmi` when needed. Do **not** map `scroll_speed` / `pointer_axes` (Weston ignores them). |
| **Weston splash bridge** | After Weston takes DRM master the kernel `drm_logo` is gone; `desktop-shell` paints `/usr/share/hmi/boot-splash.png` (**logical landscape** 1280×800 upright for `transform=rotate-270`; from `make build-boot-logo`, **not** a copy of portrait `logo.bmp`) until `flutter-wayland-client` covers it. kiosk-shell cannot show a background image. |

### `hal/datetime`

| Need | Detail |
|------|--------|
| **OS** | `date` and/or `timedatectl`; `hwclock` for RTC write; preferably `rdate` and/or `wget` for network ladder |
| **Prefs** | `/var/lib/hal/datetime.conf` — `sync_mode` (`manual` \| `network`, default `network`), `timezone` (IANA), `ntp_server` (primary hostname, default `pool.ntp.org`), `auto_timezone` (`0` \| `1`, default off), `use_24h` (`0` \| `1`, default on) |
| **NTP drop-in** | Runtime `/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf` (`NTP=` + `FallbackNTP=` from curated presets); image seed `10-appliance.conf` |
| **Auto TZ** | Optional IP geolocation (`syncTimezoneFromNetwork`: ip-api.com HTTP → ipapi.co HTTPS); no GPS |
| **Helper** | `sync_time` — **optional** override binary; default ladder is in-HAL |

### `hal/sys_info`

| Need | Detail |
|------|--------|
| **OS** | Standard `/proc`, `/sys` (thermal, cpufreq, mounts); optional `/var/lib/hal/properties.ini` for factory tunables. Snapshot: `serialNumber` (product SN), `chipId` (chip serial). |
| **Profile** | `storage_mounts` — mount points to report |
| **Helper / inject** | Product SN: `ProductInfo.sn` prefers Vendor Storage SN, else chip ID. Chip ID (HAL only, not `make devices`): `ProductInfo.chipId` / `DeviceSnReader.readChipId()` → `/usr/bin/read-serial --chip-id`. Host device selection uses **SN** only. Inject `ProductInfo` or custom `DeviceSnReader` via `BoardBindings.sysInfo` / `productInfo()` when needed. |

### `hal/gpio`

| Need | Detail |
|------|--------|
| **Asset** | Product `gpio.<board_id>.json` (named lines + chips); declare in `configs.gpio` (App asset, e.g. `assets/hal/gpio.ynh960.json`) |
| **OS** | Kernel GPIO / LED sysfs matching the JSON |

### `hal/modbus`

| Need | Detail |
|------|--------|
| **Asset** | Product `modbus.json` (RTU transport path/baud + attribute catalog); `configs.modbus` (App asset, e.g. `assets/hal/modbus.json`) |
| **OS** | Serial device node (e.g. `/dev/ttyS…` / USB ACM) usable by Posix `stty` transport |

### `hal/network` — LAN SSH (`SshDebug`)

| Profile helper | Role | Argv contract |
|----------------|------|---------------|
| `ssh_debug` | LAN/WLAN sshd policy | `status` / `enable` / `disable` |

### `hal/usb_otg` — OTG modes

| Profile helper | Role | Argv contract |
|----------------|------|---------------|
| `usb_otg_mode` | Mode apply | `debug` / `mtp` / `host` / `status` / `apply` (`attached` no-op) |

Session preference: `/var/lib/hal/usb-otg.conf` (`mode=`). Board policy: `/etc/usb-otg.ini` (`debug_only`, `auto_host_support`).
Product materials: see OpenSpec `hal-usb-otg` + [`docs/usb-otg-mtp.md`](usb-otg-mtp.md).

New products that expose OTG / LAN SSH **must** ship helpers and declare these keys
(or omit the capability / catch `HalUnsupportedException`).

---

## `BoardProfile.helpers` key reference

| Key | Module | Required? |
|-----|--------|-----------|
| `wifi_modem` | network | When Wi‑Fi netdev needs firmware/module bring-up |
| `wifi_wlan_unit` | network | If ≠ `wlan-wpa.service` |
| `bt_modem` | bluetooth | When HCI needs firmware/UART attach |
| `bt_bluetooth_unit` | bluetooth | If ≠ `bluetooth.service` |
| `bt_a2dp_*` | bluetooth | Product-dependent A2DP sink helpers |
| `ssh_debug` | network | LAN SSH debug |
| `usb_otg_mode` | usb_otg | OTG three-mode apply |
| `otg_mode_sysfs` | legacy | Optional PHY path (prefer helper) |
| `backlight_preferred_names` / `alsa_volume_controls` | output | Strongly recommended per codec/panel |
| `alsa_playback_path_control` / `alsa_playback_path_value` | output | Optional codec route enum (ynh960: `Playback Path` / `RING_SPK_HP`) |
| `change_*` / `apply_mouse_settings` / `apply_proxy` / `sync_time` | various | Optional overrides only |
| `wifi_stack_*` / `bt_stack_*` | legacy | Transition `Script*` adapters only |

---

## New product checklist (minimum)

1. **Iface names:** prefer **`eth0`** + **`wlan0`** via link/udev; set `net_roles` + `route_metrics`.
2. **networkd + resolved + wpa `-u`** unit; optional **`wifi_modem`** if netdev is not hot at boot ([case study](network-stack.md#modem-bring-up-wifibt)).
3. **BlueZ** if BT; optional **`bt_modem`** for combo chips.
4. **Backlight sysfs** + **ALSA** controls; list preferred mixer names in profile. Add `alsa_playback_path_*` only if the codec needs an enum route (Rockchip-style).
5. **Product `gpio.json` / `modbus.json`** App assets if those capabilities are advertised (not under `packages/cyber_hal/boards/<board>/`).
6. **SSH/USB** helpers + profile keys **only if** Debug is a product feature.
7. Call **`BoardBindings.restorePersistedSettings`** once after App/HAL start (Demo does this).
8. Prove empty-script construction with a second profile like `packages/cyber_hal/boards/portable-smoke.json`.

---

## Smoke / accept

```dart
final profile = BoardProfile.fromJsonString(
  File('boards/portable-smoke.json').readAsStringSync(),
);
final b = BoardBindings(profile);
expect(b.wifiRadio(), isA<SystemdWifiRadio>());
expect(b.btStack(), isA<SystemdBluezStack>());
expect(b.dateTime().helperPath, '');
```

Test: `packages/cyber_hal/test/board_bindings_portability_test.dart`.

## Demo wiring

On device, `main.dart` prefers `/run/hmi/board_profile.json` (from `oem-compose`)
or `/oem/boards/<id>/board_profile.json`, then merges App gpio/modbus assets
(`assets/hal/gpio.ynh960.json`, `assets/hal/modbus.json`). On Linux device a missing
OEM/compose profile **fails hard** (no App asset fallback). Host/desktop may
still `loadAsset` `assets/hal/board_profile.json` for UI work without `/oem`.

OEM owns board×screen SKU only (no properties.ini seed); tunables via
`/var/lib/hal/properties.ini` (bind to `/mnt/provision/properties.ini` on device)
+ `make set-prop`. Identity: Rockchip Vendor Storage; non-Rockchip / emulator
`provision/identity.env`. See
[`docs/platform-os-oem-sdk-plan.md`](platform-os-oem-sdk-plan.md) §3.5.
