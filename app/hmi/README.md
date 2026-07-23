# lws_hmi — product HMI (embedded Linux)

This tree targets **ynh960** via `flutterpi_tool` (`make build-app` → `/opt/hmi`).
It is not a phone app: only the **`linux/`** platform stub is kept (plugin registrant /
FFI helpers). `android/` / `ios/` / `macos/` / `web/` / `windows/` are intentionally absent.

P2.5 can re-add a mobile target later, for example:

```bash
cd app/hmi
flutter create --platforms=android .
```

See [`../README.md`](../README.md) for engine pins and deploy layout.

## P2.1–P2.3 platform I/O (speaker / backlight / Ethernet / Wi‑Fi / BT / USB keyboard·mouse / date-time / persist)

Reusable modules live under `lib/platform/`:

| Module | Linux backend | Notes |
|--------|---------------|-------|
| `audio/` | `change-volume` + `mpg123`/`amixer` | Forces `Playback Path=RING_SPK_HP`; asset → `/var/lib/hmi/audio/`; set volume via shell (persist `/var/lib/hmi/sound.conf` key `volume`) |
| `backlight/` | `change-backlight` | Prefer panel sysfs for get; set via shell (persist `/var/lib/hmi/display.conf` key `backlight`; restore + HMI re-apply) |
| `display/` | launch-only `display-orientation` → flutter-pi `-o` | **Not** a Demo/HAL setting; fixed panel orientation at launch |
| `datetime/` | `timedatectl`/`date` + `hwclock` + `/usr/bin/sync-time` | Manual set / Network sync; prefs `/var/lib/hmi/time-sync-mode` + `timezone`; HTTPS TLS uses `ensureSaneForTls` |
| `ethernet/` | helpers + `ip` / sysfs | RJ45 `eth0`; DHCP/static via **`eth0-network.service`** (outside HMI cgroup); `eth0-wanted` |
| `input/` | `/dev/input/by-id` probe + `MouseSettingsController` | USB HID keyboard/mouse presence; keys/pointer via flutter-pi; mouse prefs via **`apply-mouse-settings`** → `mouse.conf` (flutter-pi mtime poll; no SIGHUP) |
| `wifi/` | helpers + **D-Bus status** (`fi.w1.wpa_supplicant1`); `wpa_cli` for scan/connect | **`wlan-wpa`** requires `wpa -u`; L3 via networkd D-Bus |
| `http/` | Dart `HttpClient` (+ optional `curl`) | Default `SecurityContext`; wall-clock via `DateTimeController`; system proxy via `LinuxProxy` → `/var/lib/network/proxy.conf` + `apply-proxy`; Demo GET probe |
| `bluetooth/` | BlueZ D-Bus (`bluez` pkg) + stack/A2DP helpers | Discoverable peer + central scan/pair; HMI Agent1; `bt-wanted` + A2DP; Demo `syncFromSystem()` |

**P2.3:** Prefs split under **`/userdata/{wpa_supplicant,network,bluetooth,hmi}/`** (symlinked from `/var/lib/*`). Simple HW knobs use verb-noun shell helpers; Flutter calls those helpers rather than writing files directly.

**Device smoke (after flash / push-app):**

1. Play — hear shanghai tan; sweep Volume slider
2. Sweep Brightness — panel dims/brightens
3. Orientation — **no Demo control**; confirm launch `-o` matches board default (video layout flips are App UI later)
4. Ethernet — enable interface → DHCP or Static → link LED / `ping` peer PC (not IPC camera IP yet)
5. Keyboard — **1 mm pin → USB host** and/or **Micro-USB OTG host** (OTG/ID adapter) + HID / Bluetooth → Demo「Keyboard」：type, arrow caret, hold-to-repeat; optional NumLock if present. Standard PC cable on Micro-USB → plug-ssh (not keyboard). Pitfalls: [`docs/ynh960-io-pinmux-ledger.md`](../../docs/ynh960-io-pinmux-ledger.md) §4.1 / §4.1.1
6. Mouse — same host paths / Bluetooth → Demo「Mouse」：visible pointer tracks; natural scroll / scroll speed / pointer speed / primary button / pointer axes (Auto/Normal/Swap); prefs in `/var/lib/hmi/mouse.conf`. Pitfalls: ledger §4.1.2 (`0004`/`0005`/`0009` flutter-pi patches)
7. Wi‑Fi — enable radio → Scan → Connect (or Hidden SSID) → DHCP or Static → `ping` gateway; Send request (default `https://www.baidu.com/`) shows HTTP status/body
8. Proxy — enable proxy, Save, re-run Send request
9. LAN SSH debug — toggle on → note eth0/wlan0 IP → host `make connect <ip>`
10. Date & Time — set mode Manual/Network; Apply local date/time; Sync Now with network up; HTTPS probe after forcing stale RTC
11. Bluetooth — enable adapter; turn on **Pairable** (also enables Discoverable 180s) or Discoverable; phone finds / pairs. Optional: enable **BT speaker (A2DP)** (off by default) → phone **连接成功** + music on speaker. Demo **Volume** also drives BlueALSA soft-volume while BT is streaming. **Scan** → nearby list → **Pair/Connect** a Bluetooth keyboard/mouse; type in Keyboard Demo / move pointer; passkey UI when the keyboard requires a displayed code. Paired/connected list keeps Disconnect/Remove (`input=ok|missing` from Dart sysfs/evdev probe). Disconnect = Untrust + Disconnect (sticky); Connect = Trust + Connect (Policy auto-reconnect after link loss while Trusted). HAL attaches HOGP/evdev when Connected (no periodic heal). Coexistence: phone bond + HID bond + Wi‑Fi up during a bounded scan. `verify-boot` still shows wifibt/wpa/bluetooth deferred at boot
12. (Regression) USB keyboard/mouse still work after BT HID pairing

Helpers: `/usr/libexec/hmi/wifi-stack-*.sh`, `wlan0-dhcp.sh`, `wlan0-static.sh`, `eth0-link.sh`, `eth0-dhcp.sh`, `eth0-static.sh`, `enable-ssh-debug.sh`, `disable-ssh-debug.sh`, `bt-stack-*.sh`, `bt-a2dp-sink-*.sh`, `bt-a2dp-volume.sh`, `bt-pair-agent.sh`, `bt-ensure-agent.sh`, `bt-stop-agent.sh`, `bt-audio-prepare.sh`; units `bluealsa.service` / `bluealsa-aplay.service` (started only when A2DP switch on).

HTTPS needs a sane wall clock (`date -u` year ≥ 2025) more than custom CA loading —
Dart default roots + system bundle on image are enough once RTC is correct. Board RTC
often boots in 2024; after network is up, `/usr/bin/sync-time` (also from `DateTimeController` /
HTTPS probe) syncs via `rdate` / HTTP Date. Demo **Date & Time** supports Manual Apply
and Network Sync Now. Journal `dhcpcd is not running` during connect is benign.
Reusable Wi‑Fi UI (beyond Demo): `lib/ui/wifi/wifi_network_views.dart` + `lib/platform/wifi/wifi_ap_list.dart`.

On first ALSA bring-up, check amp enable and mixer control (`amixer scontrols`) if silent.

### Trace logging

Hot-path `debugPrint` (Modbus TX/RX, backlight steps, audio chatter). Wi‑Fi never logs PSK; proxy password is redacted in traces.

Off by default even in debug — printing every slider tick / Modbus timeout slows debug mode over USB-gadget SSH.

Enable when needed:

```bash
# example: flutterpi_tool / kernel compile with
--dart-define=LWS_HMI_TRACE=true
```
