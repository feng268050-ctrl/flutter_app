## Why

P2.1 already closed speaker / backlight / orientation on ynh960; **Wi‑Fi and Bluetooth** remain unproven on Linux. Product networking (cloud HTTP/WS, status bar, P5.2 Settings) depends on a correct **wpa_supplicant + BlueZ** stack and on **client network features** operators actually use: hidden SSID, static IPv4, HTTP(S) proxy, and a verified outbound request path. Doing this now with **reusable platform abstractions** and a **Demo management UI** de-risks hardware and config surfaces before P5 business migration.

## What Changes

- Add reusable **platform Wi‑Fi** module: radio on/off, scan visible APs, join (including **hidden SSID**), forget, connection status; **wlan0 IPv4** via DHCP or **static** addressing — Linux `wpa_supplicant` + scoped IP helpers, suitable for later P5.2 Settings / status bar.
- Add reusable **platform HTTP client** helpers: **HTTP(S) proxy** get/set (persisted) and an outbound **request probe** (method/URL → status + body snippet) so Demo and later cloud/API code share one path.
- Add reusable **platform Bluetooth** module oriented as a **local adapter that is discoverable and accepts connections from phones/PCs** (not a central that scans/joins other gadgets): adapter on/off, local name/address, discoverable/pairable, list incoming paired/connected remotes, disconnect/remove — BlueZ-backed for later Settings parity.
- Extend the **P2 / P2.1 demo page** with Wi‑Fi management (incl. hidden / static IP / proxy), a **network request** action that shows the result, and Bluetooth **visibility / incoming connection** controls (bring-up UI — **not** product Settings polish / FrostUI).
- Provide **systemd on-demand** helpers so `wifibt-init` / `wpa_supplicant` / wlan0 IP / `bluetooth.service` start only when the HMI enables radio — **boot KPI deferral stays**.
- Update plan §12 P2.1 checklist for Wi‑Fi / BT when device smoke passes; clarify BT as **discoverable peripheral** (plan text that says “scan other devices” is corrected by this change’s intent). IPC eth0 / touch / pinmux stay out of scope.

## Capabilities

### New Capabilities

- `linux-wifi`: Linux Wi‑Fi client (wpa_supplicant + on-demand bring-up); visible + **hidden** join; **DHCP or static IPv4** on wlan0; abstract Dart API for Demo and P5.2.
- `linux-http-client`: Persisted **HTTP(S) proxy** configuration and outbound HTTP(S) request API (status + body) for Demo probe and later product HTTP.
- `linux-bluetooth`: Linux Bluetooth **adapter as discoverable/connectable peer** (BlueZ): visibility, local identity, incoming pairing/connection management — not remote-device scanning.

### Modified Capabilities

- `p2-device-demo-ui`: Home demo gains Wi‑Fi (incl. hidden / static IP / proxy), HTTP request probe + result, and Bluetooth visibility / incoming-connection sections.
- `hmi-systemd-boot`: Clarify on-demand start of deferred wifibt/wpa/bluetooth units via privileged helpers without enabling them at boot; HMI MUST NOT require `network-online` for start.
- `buildroot-lws-hmi-image`: Rootfs includes minimal pieces for wlan0 DHCP (and static `ip` tooling already via iproute2) after P1 stack presence.

## Impact

- **App** (`app/hmi/`): `lib/platform/{wifi,http,bluetooth}/` (names per design); demo UI; unit tests; no secrets in logs.
- **Rootfs / overlay**: stack/IP helpers, wpa conf under `/var/lib/lws-hmi/`, proxy prefs file, BlueZ discoverable policy defaults as needed.
- **Systemd**: units remain **disabled at boot**; App-triggered start only.
- **Docs**: plan §12 + `app/hmi/README.md` smoke (Wi‑Fi connect + HTTP probe; phone discovers HMI BT).
- **Non-goals**: Product Settings / status bar (P5.2); NetworkManager; SoftAP/hostapd product flow; A2DP **Source** / HFP headset/hands-free; HMI-as-central scanning other BT devices; eth0/IPC; MediaMTX; Android backends until P2.5.
- **In-scope BT audio**: Opt-in A2DP **Sink** via BlueZ-ALSA (**default off**; Demo/API switch) so phones can connect as media remotes and play through the onboard speaker (does not block later BLE GATT provisioning).
