# Network stack (P3.1 / dart-hal D11)

## Ownership

| Layer | Owner | Notes |
|-------|--------|--------|
| Wi‑Fi L2 (scan/assoc) | **wpa_supplicant D-Bus** (`-u` **required**) | `wlan-wpa.service` → `run-wpa.sh`. Binary must have `BR2_PACKAGE_WPA_SUPPLICANT_DBUS`. No soft-fallback without `-u`. Stock `wpa_supplicant.service` (`-u` only, D-Bus-activated) is **masked** — HMI must not auto-spawn an empty daemon that steals `fi.w1.wpa_supplicant1`. `ctrl_interface=` may still exist for engineering `wpa_cli`. Image / script seed `country=US`; runtime Country preference (Common Settings) upserts `country=` + `iw reg set` via `WifiCountryApply`. |
| eth0 / wlan0 L3 (addr/route) | **systemd-networkd** | Helpers render `/etc/systemd/network/50-hmi-<iface>.network` then `networkctl reconfigure` / D-Bus |
| DNS | **systemd-resolved** | networkd feeds DNS to resolved; `/etc/resolv.conf` → `../run/systemd/resolve/resolv.conf`. LLMNR/mDNS off. **Wall clock (ynh960):** external **PCF8563 on i2c5 @0x51** (`ynh960-rtc.dtsi` → sole `rtc0`; **`CONFIG_RTC_DRV_RK808` unset**). HCTOSYS/SYSTOHC + `rtc-systohc.timer` persist offline time. **Automatic NTP on by default** (`systemd-timesyncd` preset; HAL `sync_mode` → `network`). NTP presets via `10-appliance.conf` + runtime `20-hmi-ntp.conf`. **DNSSEC=allow-downgrade** (validate when upstream supports; curated fallbacks include Cloudflare/Google). **DNSOverTLS=no**. Do **not** hand-write resolv from helpers. |
| Live UI / HAL status | **D-Bus subscribe** | L2: `fi.w1.wpa_supplicant1` PropertiesChanged. L3: `org.freedesktop.network1` PropertiesChanged for link state; addresses via **`Link.Describe` JSON** (current upstream API, systemd 254) with fallback to legacy Link property **`Addresses`** (`a(iiay)`) on older networkd. **Not** Timer + `wpa_cli`/`ip` as primary. |
| System proxy | HAL `LinuxProxy` writes conf + env/profile/systemd drop-ins | `/var/lib/network/proxy.conf`; optional `apply-proxy` override; not networkd |
| Cloud API origin | HAL `CloudApiOriginConfig` + `CloudApiOriginProber` | Tier from `/var/lib/network/cloud.conf`; concurrent first-wins probe; boot pin `/run/network/cloud-origin.pin` (cross-App, cleared on reboot); Apps build Worker HTTP/WS URLs from pin |
| Cloud HTTP / auth / WS | HAL `CloudHttpClient`, `DeviceCloudEd25519*`, `DeviceWsConnectionManager` | Bearer remint + activate/token + socket lifecycle; product WS commands stay in App |

Do **not** co-manage L3 with `dhcpcd`, BusyBox `udhcpc`, or raw `ip addr` on the same iface while networkd owns it. Helpers that need L3 **fail hard** if `networkctl` is missing — rebuild systemd with `BR2_PACKAGE_SYSTEMD_NETWORKD` + `BR2_PACKAGE_SYSTEMD_RESOLVED` (`bash scripts/br-make-packages.sh systemd systemd`).

**Dual default routes:** Prefer Wi‑Fi when both have a default: station metric `100`, ethernet.primary `2000` (board profile MAY override). Wi‑Fi `.network` also sets `Domains=~.` so systemd-resolved prefers wlan DNS over ethernet (RouteMetric alone does not). Interim: `networkd-apply-ipv4.sh`; after D11b: HAL in-package apply. No HTTP connectivity probe.


## Recommended netdev names

HAL supports arbitrary iface names via `BoardProfile.net_roles`, but **new products
SHOULD name**:

- Ethernet primary → **`eth0`**
- Wi‑Fi station → **`wlan0`**

Keep `10-*.link` / udev so the first GMAC and first wireless land on these names.
ynh960 and most docs/prefs examples use `eth0` / `wlan0`.

## Modem bring-up (Wi‑Fi / combo firmware) {#modem-bring-up-wifibt}

`SystemdWifiRadio` assumes a wireless netdev **already exists** (or will appear
after an optional modem port). Many appliance boards (SDIO/USB/UART combo modules
from various vendors) need a **one-shot firmware / module / hciattach** step before
`wlan0` or HCI is visible.

### Product requirement

If `ip link` / `/sys/class/net/*/wireless` is empty until vendor bring-up runs, the
board pack **MUST** inject a modem port:

- Profile: `helpers.wifi_modem` → argv (script or binary)
- HAL: `ProcessWifiModemPort` / custom `WifiModemPort` passed into `SystemdWifiRadio`
- Same pattern for BT: `helpers.bt_modem` when HCI is absent until attach

Default `NoopWifiModemPort` is correct only when the driver creates the netdev at
boot (typical PCIe / built-in MAC).

### Case study: ynh960 `wifibt-bringup.sh`

Path (W2): `oem/boards/ynh960/helpers/wifibt-bringup.sh`  
Rootfs keeps a thin stub at `/usr/libexec/bluetooth/wifibt-bringup.sh` that execs the OEM helper.  
Profile (`oem/boards/ynh960/board_profile.json`):

```json
"wifi_modem": "/oem/boards/ynh960/helpers/wifibt-bringup.sh",
"bt_modem": "/oem/boards/ynh960/helpers/wifibt-bringup.sh"
```

What it does (Innohi AIC8800D80 SDIO + UART combo — **illustrative**, not portable):

1. `rfkill unblock` wifi/bluetooth
2. Link OEM `radio/firmware/` keep-set into `CONFIG_AIC_FW_PATH` (`/vendor/etc/firmware`)
3. Exit early if a wireless netdev already exists
4. Detect SDIO vendor `c8a1` (AIC); **rebind** the SDIO MMC host once so
   `mmc-pwrseq` resets a combo that can stay enumerated but ignore CMD52/53
5. Prefer `rk_wifi_init` (with timeout), else `insmod`
   `aic8800_bsp` → `aic8800_fdrv` → optional `aic8800_btlpm`; on failure rescan once more
6. Wait for wireless iface; `hciattach` on `/dev/ttyS1` (or `wifibt-util`) for `hci0`
7. Non-AIC fallback: Rockchip `wifibt-init`

**Other vendors** (Broadcom, Realtek, MediaTek, …) will ship different binaries;
the **HAL contract is the same**: provide a command that leaves a wireless netdev
(and HCI if needed) ready, then `SystemdWifiRadio` / `SystemdBluezStack` take over
(`ip link`, `systemctl`, D-Bus).

Do **not** fold vendor bring-up into the portable HAL default path.

## Prefs (still under `/var/lib/…`, bound to `/userdata`)

| Path | Role |
|------|------|
| `/var/lib/network/eth0-ipv4` | eth0 `mode=` dhcp\|static + address fields |
| `/var/lib/network/eth0-wanted` | restore starts `eth0-network.service` |
| `/var/lib/wpa_supplicant/wlan0-ipv4` | wlan L3 mode |
| `/var/lib/wpa_supplicant/wifi-wanted` | restore brings Wi‑Fi stack up |
| `/var/lib/hmi/common-settings.json` | App Country / Language / Unit; Country drives wpa `country=` + linked timezone/NTP (default **US**) |
| `/var/lib/network/proxy.conf` | multi-scheme proxy (migrates from `/var/lib/hmi/http-proxy`) |
| `/var/lib/network/cloud.conf` | shared cloud API env tier (`environment_tier=prod\|test`); migrates from legacy `/var/lib/hmi/cloud-settings.json` `environmentTier`. Candidate Worker/hyurl bases + concurrent probe live in HAL (`CloudApiOriginConfig` / `CloudApiOriginProber`) |
| `/run/network/cloud-origin.pin` | boot-scoped pinned Worker origin (`environment_tier` + `pinned_origin`); survives App seat switches; cleared on reboot |
| `/var/lib/hmi/cloud-settings.json` | product HMI cloud/LAN opt-in toggles only (not the shared API tier) |

## Helpers (board / interim)

| Script | Role after D11b |
|--------|-----------------|
| `/usr/libexec/wpa/run-wpa.sh` | Still required on image: `wpa_supplicant -u` for this board’s unit |
| Board `WifiRadio` adapter | MAY call `wifi-stack-up/down` / `wifibt-bringup` — **not** imported as HAL default |
| `/usr/bin/apply-proxy` | Optional override only; HAL default is in-Dart apply (script retired on ynh960 image) |
| `/usr/libexec/network/networkd-apply-ipv4.sh` | Render `.network` + reload/reconfigure (DNS via resolved) | **Interim** — HAL `NetworkdIpv4Apply` is the portable path (D11b) |
| Board `WifiRadio` / `SystemdWifiRadio` (default) | Portable systemd unit + optional modem port; `ScriptWifiRadio` transition only | HAL default radio port |

## HAL (D11b)

Apps import `package:cyber_hal/network.dart` only.

| Concern | Owner |
|---------|--------|
| Status | `NetworkdDbus` + `WpaSupplicantDbus` |
| L3 DHCP/static/link | `NetworkdIpv4Apply` (in-package `.network` + `networkctl`) |
| L2 scan/connect/forget | `WpaSupplicantDbus` commands (not product-default `wpa_cli`) |
| Wi‑Fi PHY bring-up | Default `SystemdWifiRadio`; optional modem inject; `ScriptWifiRadio` transition only |
| Proxy | Conf + in-HAL env apply; optional apply-proxy override |
| Connectivity probe | **None** — dual-default prefers Wi‑Fi via RouteMetric |

Demo ethernet/wifi controllers call the same `NetworkdIpv4Apply` / wpa D-Bus command paths. Live status uses D-Bus; apply MUST NOT hard-depend on iface-named libexec wrappers. Boot restore is HAL `BoardBindings.restorePersistedSettings` / session `syncFromSystem`. Portability contract: [`docs/hal-portability.md`](hal-portability.md).

## Buildroot

- `BR2_PACKAGE_SYSTEMD_NETWORKD=y` + `BR2_PACKAGE_SYSTEMD_RESOLVED=y` (`chips/lws_hmi_systemd.config`) — **rebuild the package** after flipping (`bash scripts/br-make-packages.sh systemd systemd`); `build-rootfs` alone reuses the old systemd
- `BR2_PACKAGE_WPA_SUPPLICANT_DBUS=y` (`chips/lws_hmi_network.config`) — **rebuild** with `bash scripts/br-make-packages.sh wpa wpa_supplicant`
- `BR2_PACKAGE_DHCPCD` unset (`chips/lws_hmi_network.config`) — dhcpcd must not appear in target
- Preset: `enable systemd-networkd.service` and `enable systemd-resolved.service`
- `systemd-network-generator` stays masked; keep `10-gmac.link` for eth0 naming
- Gates: `scripts/verify-rootfs-overlay.sh` and on-device `verify-env` **fail** without `networkctl` / networkd+resolved D-Bus / wpa `-u` / resolv → resolved

## Camera eth0 (P4/P5)

When the product needs a dedicated camera LAN address on eth0, reconfigure **networkd** only (HAL `Ethernet.setStatic` / in-package `.network` apply) — do not bypass with raw `ip addr`.

**RMII / GMAC bring-up (ynh960):** product PHY drives the 50 MHz REF_CLK. DTS must use the full **`clock_in_out = "input"`** path (`gmac1_clkin@50M` parent for `SCLK_GMAC1`) — flipping only the string while leaving SoC `assigned-clock-rates` breaks UDP RTSP (MAC CRC). See [`ynh960-uart5-gmac.dtsi`](../overlay/kernel/rockchip/ynh960-uart5-gmac.dtsi).

**IPC RTSP acceptance / pitfall log** (Mac vs Android vs Linux remux, MMC CRC, scripts for new motherboards): [`ip-camera-rtsp-bitrate-android-vs-linux.md`](ip-camera-rtsp-bitrate-android-vs-linux.md).
