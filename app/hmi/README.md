# lws_hmi — flutter-pi HMI (embedded Linux)

This tree targets **ynh960 / flutter-pi** via `flutterpi_tool` (`make build-app`).
It is not a phone app: only the **`linux/`** platform stub is kept (plugin registrant /
FFI helpers). `android/` / `ios/` / `macos/` / `web/` / `windows/` are intentionally absent.

P2.5 can re-add a mobile target later, for example:

```bash
cd app/hmi
flutter create --platforms=android .
```

See [`../README.md`](../README.md) for engine pins and deploy layout.

## P2.1–P2.3 platform I/O (speaker / backlight / orientation / Ethernet / Wi‑Fi / BT / USB keyboard·mouse / date-time / persist)

Reusable modules live under `lib/platform/`:

| Module | Linux backend | Notes |
|--------|---------------|-------|
| `audio/` | `change-volume` + `mpg123`/`amixer` | Forces `Playback Path=RING_SPK_HP`; asset → `/var/lib/lws-hmi/audio/`; set volume via shell (persist `media-volume`) |
| `backlight/` | `change-backlight` | Prefer panel sysfs for get; set via shell (persist `backlight-brightness`; restore + HMI re-apply) |
| `display/` | `change-orientation` + `systemctl restart hmi` | Persist `display-orientation` via shell → flutter-pi `-o` |
| `datetime/` | `timedatectl`/`date` + `hwclock` + `wlan0-time-sync.sh` | Manual set / Network sync; prefs `/var/lib/lws-hmi/time-sync-mode` + `timezone`; HTTPS TLS uses `ensureSaneForTls` |
| `ethernet/` | helpers + `ip` / sysfs | RJ45 `eth0`; DHCP/static via **`lws-hmi-eth0.service`** (outside HMI cgroup); `eth0-wanted` |
| `input/` | `/dev/input/by-id` probe + `MouseSettingsController` | USB HID keyboard/mouse presence; keys/pointer via flutter-pi; mouse prefs via **`apply-mouse-settings`** → `mouse.conf` (flutter-pi mtime poll; no SIGHUP) |
| `wifi/` | helpers + `wpa_cli` | **`lws-hmi-wpa` / `lws-hmi-wlan0-dhcp`** units; `wifi-wanted`; Hidden SSID; DHCP/static on **wlan0** |
| `http/` | Dart `HttpClient` (+ optional `curl`) | Default `SecurityContext`; wall-clock via `DateTimeController`; proxy prefs `/var/lib/lws-hmi/http-proxy`; Demo GET probe |
| `bluetooth/` | BlueZ D-Bus (`bluez` pkg) + stack/A2DP helpers | Discoverable peer + central scan/pair; HMI Agent1; `bt-wanted` + A2DP; Demo `syncFromSystem()` |

**P2.3:** Prefs under **`/userdata/lws-hmi/`** (`/var/lib/lws-hmi` symlink). Simple HW knobs (backlight / volume / orientation / mouse) are **written by verb-noun shell helpers** (`change-backlight`, `change-volume`, `change-orientation`, `apply-mouse-settings`); Flutter calls those helpers rather than writing the files itself. Reboot / `push-app` / future **`make upgrade` keep** them; **`make flash` must reset** them (factory). See [`docs/storage-layout.md`](../../docs/storage-layout.md) §Prefs. Boot restore runs **`After=hmi`** (UI first); Demo `syncFromSystem()` shows **starting/connecting** while stacks come up (same as manual enable).

**Device smoke (after flash / push-app):**

1. Play — hear shanghai tan; sweep Volume slider
2. Sweep Brightness — panel dims/brightens
3. Portrait / Landscape — HMI restarts; `ps`/`tr` confirms `-o portrait_up` or `landscape_left`
4. Ethernet — enable interface → DHCP or Static → link LED / `ping` peer PC (not IPC camera IP yet)
5. Keyboard — **1 mm pin → USB host** and/or **Micro-USB OTG host** (OTG/ID adapter) + HID / Bluetooth → Demo「Keyboard」：type, arrow caret, hold-to-repeat; optional NumLock if present. Standard PC cable on Micro-USB → plug-ssh (not keyboard). Pitfalls: [`docs/ynh960-io-pinmux-ledger.md`](../../docs/ynh960-io-pinmux-ledger.md) §4.1 / §4.1.1
6. Mouse — same host paths / Bluetooth → Demo「Mouse」：visible pointer tracks; natural scroll / scroll speed / pointer speed / primary button / pointer axes (Auto/Normal/Swap); prefs in `/var/lib/lws-hmi/mouse.conf`. Pitfalls: ledger §4.1.2 (`0004`/`0005`/`0009` flutter-pi patches)
7. Wi‑Fi — enable radio → Scan → Connect (or Hidden SSID) → DHCP or Static → `ping` gateway; Send request (default `https://www.baidu.com/`) shows HTTP status/body
8. Proxy — enable proxy, Save, re-run Send request
9. LAN SSH debug — toggle on → note eth0/wlan0 IP → host `make connect <ip>`
10. Date & Time — set mode Manual/Network; Apply local date/time; Sync Now with network up; HTTPS probe after forcing stale RTC
11. Bluetooth — enable adapter; turn on **Pairable** (also enables Discoverable 180s) or Discoverable; phone finds / pairs. Optional: enable **BT speaker (A2DP)** (off by default) → phone **连接成功** + music on speaker. Demo **Volume** also drives BlueALSA soft-volume while BT is streaming. **Scan** → nearby list → **Pair/Connect** a Bluetooth keyboard/mouse; type in Keyboard Demo / move pointer; passkey UI when the keyboard requires a displayed code. Paired/connected list keeps Disconnect/Remove. Coexistence: phone bond + HID bond + Wi‑Fi up during a bounded scan. `verify-boot` still shows wifibt/wpa/bluetooth deferred at boot
12. (Regression) USB keyboard/mouse still work after BT HID pairing

Helpers: `/usr/lib/lws-hmi/wifi-stack-*.sh`, `wlan0-dhcp.sh`, `wlan0-static.sh`, `eth0-link.sh`, `eth0-dhcp.sh`, `eth0-static.sh`, `enable-ssh-debug.sh`, `disable-ssh-debug.sh`, `bt-stack-*.sh`, `bt-a2dp-sink-*.sh`, `bt-a2dp-volume.sh`, `bt-pair-agent.sh`, `bt-ensure-agent.sh`, `bt-stop-agent.sh`, `bt-audio-prepare.sh`; units `bluealsa.service` / `bluealsa-aplay.service` (started only when A2DP switch on).

HTTPS needs a sane wall clock (`date -u` year ≥ 2025) more than custom CA loading —
Dart default roots + system bundle on image are enough once RTC is correct. Board RTC
often boots in 2024; after Wi‑Fi, `wlan0-time-sync.sh` (also from `DateTimeController` /
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
