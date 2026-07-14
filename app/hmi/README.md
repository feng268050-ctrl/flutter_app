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

## P2.1 platform I/O (speaker / backlight / orientation / Wi‑Fi / BT)

Reusable modules live under `lib/platform/`:

| Module | Linux backend | Notes |
|--------|---------------|-------|
| `audio/` | `mpg123`/`aplay` + `amixer` | Forces `Playback Path=RING_SPK_HP`; asset → `/var/lib/lws-hmi/audio/` |
| `backlight/` | Prefer `/sys/class/backlight/backlight` | Skip broken `led-*-pwm` clones |
| `display/` | preference file + `systemctl restart hmi` | `/var/lib/lws-hmi/display-orientation` → flutter-pi `-o` |
| `wifi/` | helpers + `wpa_cli` | Hidden SSID; DHCP/static on **wlan0**; `WifiApList` / `WifiConnectedPanel` / `linkDetails()` for Settings reuse |
| `http/` | Dart `HttpClient` (+ optional `curl`) | Default `SecurityContext`; wall-clock sync before HTTPS; proxy prefs `/var/lib/lws-hmi/http-proxy`; Demo GET probe |
| `bluetooth/` | helpers + `bluetoothctl` | **Discoverable peer**; opt-in A2DP Sink (bluealsa, **default off**); Pairable turns Discoverable on (180s); persistent `bt-pair-agent` |

**Device smoke (after flash / push-app):**

1. Play — hear shanghai tan; sweep Volume slider
2. Sweep Brightness — panel dims/brightens
3. Portrait / Landscape — HMI restarts; `ps`/`tr` confirms `-o portrait_up` or `landscape_left`
4. Wi‑Fi — enable radio → Scan → Connect (or Hidden SSID) → DHCP or Static → `ping` gateway; Send request (default `https://www.baidu.com/`) shows HTTP status/body
5. Proxy — enable proxy, Save, re-run Send request
6. Bluetooth — enable adapter; turn on **Pairable** (also enables Discoverable 180s) or Discoverable; phone finds / pairs. Optional: enable **BT speaker (A2DP)** (off by default) → phone **连接成功** + music on speaker. Demo **Volume** also drives BlueALSA soft-volume while BT is streaming. Incoming peers lists remote; `verify-boot` still shows wifibt/wpa/bluetooth deferred at boot

Helpers: `/usr/lib/lws-hmi/wifi-stack-*.sh`, `wlan0-dhcp.sh`, `wlan0-static.sh`, `bt-stack-*.sh`, `bt-a2dp-sink-*.sh`, `bt-a2dp-volume.sh`, `bt-pair-agent.sh`, `bt-audio-prepare.sh`; units `bluealsa.service` / `bluealsa-aplay.service` (started only when A2DP switch on).

HTTPS needs a sane wall clock (`date -u` year ≥ 2025) more than custom CA loading —
Dart default roots + system bundle on image are enough once RTC is correct. Board RTC
often boots in 2024; after Wi‑Fi, `wlan0-time-sync.sh` (also from the HTTPS probe path)
syncs via `rdate` / HTTP Date. Journal `dhcpcd is not running` during connect is benign.
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
