## Context

P1 installed **wpa_supplicant** + **BlueZ / rkwifibt** but **boot-deferred** them for Plan A KPI. P2.1 audio/backlight/orientation landed reusable `lib/platform/*` modules.

This slice covers Wi‑Fi + Bluetooth bring-up with **product-relevant client options** (hidden SSID, static IPv4, HTTP proxy, outbound HTTP probe) and corrects Bluetooth product role:

> **Bluetooth on this HMI is so phones/PCs can discover and connect to the device** — not so the HMI browses or joins other Bluetooth gadgets.

Earlier draft of this change wrongly modeled central/scanner flows; that is explicitly out of scope.

Constraints:

- No NetworkManager / systemd-networkd / resolved.
- `lws_hmi_network.config` currently disables `dhcpcd` — restore **wlan0-scoped** DHCP; static IPv4 is an alternate path on **wlan0 only** (eth0 remains §7.1 camera script — do not hijack eth0).
- First paint MUST NOT await RF / DHCP / HTTP (§7.0).

## Goals / Non-Goals

**Goals:**

- Distro-grade client stack: on-demand **rkwifibt → wpa_supplicant → DHCP|static on wlan0**; on-demand **bluetoothd** with **Discoverable/Pairable**.
- Abstract Dart APIs for Wi‑Fi, HTTP(+proxy), Bluetooth peripheral/visibility — Demo and P5.2 share contracts.
- Demo: manage Wi‑Fi (visible + hidden, DHCP + static, proxy), **fire an HTTP(S) request and show result**, manage BT visibility and show incoming peers.
- Preserve boot deferral.

**Non-Goals:**

- Product Settings polish / FrostUI / status bar (P5.2).
- NetworkManager / iwd / connman.
- SoftAP / captive portal.
- A2DP **Source** / HFP product path; **BT central scan / connect-to-accessory** UX.
- (A2DP **Sink** / BlueZ-ALSA speaker role is in scope as **opt-in / default off**.)
- eth0 static/DHCP policy changes; IPC camera.
- Android backends until P2.5.

## Decisions

### D1 — Package layout

```text
lib/platform/wifi/
  wifi_models.dart
  wifi_controller.dart              # abstract
  linux_wpa_wifi_controller.dart

lib/platform/http/
  http_proxy_config.dart            # host/port/user/enabled
  http_client_controller.dart       # abstract: proxy + request
  linux_http_client_controller.dart

lib/platform/bluetooth/
  bluetooth_models.dart
  bluetooth_controller.dart         # abstract — peripheral/visibility
  linux_bluez_bluetooth_controller.dart
```

### D2 — Boot-deferred; helpers on demand

Same as before: helpers `wifi-stack-up/down.sh`, `wlan0-dhcp.sh`, `wlan0-static.sh` (or unified `wlan0-ip.sh`), `bt-stack-up/down.sh`. Units stay out of multi-user wants. `hmi.service` never waits on `network-online`.

### D3 — Wi‑Fi: wpa_supplicant ctrl + hidden SSID

**Visible join:** scan → `add_network` / `set_network` / `enable_network` / `select_network`.

**Hidden join:** Demo (and API) MUST allow connect with **manually entered SSID** + PSK, with wpa `scan_ssid=1` (and appropriate key_mgmt). Scanning alone MUST NOT be required for hidden networks.

**Abstract Wi‑Fi API (normative):**

- Radio + connection streams (as before)
- `scan()` → visible APs
- `connect({required String ssid, String? psk, bool hidden = false, bool save = true})`
- `disconnect()` / `forget(ssid)` / `savedNetworks()`
- IPv4: see D4

### D4 — wlan0 IPv4: DHCP **or** static

**Choice:** After association (or when radio is up with L2 ready):

| Mode | Behavior |
|------|----------|
| `dhcp` | `wlan0-dhcp.sh` — client on **wlan0 only** |
| `static` | Apply `address` / `prefixLength` / optional `gateway` / optional `dns` via `ip addr` + route + resolv snippet **for wlan0 only** |

Persist IPv4 mode + static fields under `/var/lib/wpa_supplicant/wlan0-ipv4` (or equivalent) so Demo/P5.2 share one file. Changing mode MUST NOT touch eth0.

**API:**

- `Future<void> setIpv4Config(WlanIpv4Config config)`
- `Future<WlanIpv4Config> getIpv4Config()`
- Connection stream includes current IPv4 when known

**Why:** Customer sites often need static tablets; DHCP remains default for bring-up realism.

### D5 — HTTP(S) proxy + request probe

**Choice:** Separate small `HttpClientController`:

- Persist proxy: `enabled`, `host`, `port`, optional user/password under `/var/lib/hmi/http-proxy` (never log password).
- Outbound requests use Dart `HttpClient` (or equivalent) honoring proxy when enabled; clear non-proxy path when disabled.
- `Future<HttpProbeResult> request({required String method, required Uri url, ...})` → statusCode, reasonPhrase, truncated body, error message, elapsed.

Demo: fields for proxy + URL (default e.g. `https://www.baidu.com/` or a stable probe URL documented in README) + **Request** button + result panel.

**Why:** Validates Wi‑Fi + DNS + proxy end-to-end before P5 cloud; same abstraction later for product HTTP.

**Alternatives:** Only `curl` via Process — acceptable fallback behind the same API if Dart TLS/proxy on flutter-pi is insufficient; prefer in-process HttpClient first.

### D6 — Bluetooth: discoverable peripheral, not central scanner

**Product role (normative):** HMI adapter is **discoverable / pairable** so **phones and PCs find and connect to it**. Demo proves RF + BlueZ accept path.

**In scope:**

- Adapter power on/off (on-demand bluetoothd)
- Local adapter name + BD_ADDR display
- Set **Discoverable** / **Pairable** (with optional discoverable timeout)
- Stream/list of **remote devices that are bonded or connected to us** (incoming peers)
- Disconnect / remove a remote that connected or paired to us
- Optional: set local alias (friendly name)

**Out of scope for this change:**

- UI to **scan** for nearby third-party devices
- UI to **initiate** connection/pairing **to** headphones, speakers, other HIDs as a central
- A2DP **Source** / HFP hands-free product path (Sink via bluealsa is in scope)

**BlueZ implementation:** Prefer D-Bus `org.bluez.Adapter1` (`Powered`, `Discoverable`, `Pairable`, `Alias`) + `ObjectManager` for Device1 objects where `Connected`/`Paired` reflect remotes attached to us. CLI (`bluetoothctl power/discoverable/pairable/show/devices`) allowed as interim behind the same API.

**Note vs old plan wording:** `docs/flutter-pi-hmi-plan.md` §1.1 historically said `bluetoothctl scan` for smoke; this design **replaces that intent** with discoverable + phone-side discovery smoke. Update §12 checklist language when landing.

### D7 — Demo UI sections (post-frame)

1. **Wi‑Fi** — radio; status (SSID/IPv4); scan list; connect visible; **Add hidden network** (SSID + PSK); DHCP vs **Static** fields; disconnect/forget.
2. **Proxy** — enable + host/port/(optional auth); save.
3. **HTTP probe** — URL + Go → show status / truncated body / error (proves stack + proxy).
4. **Bluetooth** — adapter toggle; show name/address; Discoverable/Pairable toggles; list **incoming** paired/connected remotes; disconnect/remove. **No “Scan for devices” as central.**

### D8 — Security / logging

- Never log PSK or proxy password at info; trace may log SSID / host / BD_ADDR.
- HTTP probe truncates body (e.g. ≤2 KiB) in UI.

### D9 — KPI

Default Demo: radios **off** until toggled. HTTP probe only on user action. Optional “Wi‑Fi wanted” auto-reconnect deferred to P5.2 unless bring-up needs it.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Hidden SSID assoc flaky per driver | `scan_ssid=1` + document driver quirks from device spike |
| Static IP misconfig blackholes tablet | Validate fields; Demo shows apply errors; easy switch back to DHCP |
| Proxy breaks probe without clear error | Surface `HttpProbeResult.error`; test with proxy on/off |
| Flutter-pi Dart TLS issues | Fallback Process `curl -x` behind same controller |
| Misbuilt BT as central again | Specs/scenarios forbid scan-other-devices Demo; review against D6 |
| eth0 accidentally static/DHCP | Helpers hard-code `-i wlan0` / refuse eth0 |

## Migration Plan

1. Overlay helpers + DHCP package + prefs paths → rootfs as needed.
2. Dart modules + unit tests (parsers, hidden flag → `scan_ssid`, IPv4 serialization, proxy redact).
3. Demo sections + HTTP probe.
4. Device smoke: visible + hidden join; DHCP + static; proxy on/off HTTP; phone discovers HMI BT and pairs/connects.
5. Update plan §12; note BT role correction.

Rollback: revert App modules/UI; leave packages/helpers unused; boot policy unchanged.

## Open Questions

1. ynh960 Wi‑Fi/BT chip + firmware paths — confirm on first spike.
2. `dhcpcd` vs `udhcpc` — pick in spike.
3. Default HTTP probe URL and whether cleartext `http://` must be allowed for LAN probes.
4. Classic vs BLE discoverability for phone apps (Android companion) — confirm with product; BlueZ can enable both adapter Discoverable and a later GATT app (GATT service registration may be P5 if companion protocol needs it; P2.1 at minimum adapter Discoverable + pairable).
