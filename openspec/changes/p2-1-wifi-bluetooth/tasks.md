## 1. Rootfs helpers and DHCP client

- [x] 1.1 Spike on device: confirm wlan0/hci0 after `wifibt-init`, `wpa_supplicant.service` flags, and `dhcpcd` vs `udhcpc`
- [x] 1.2 Enable minimal wlan0 DHCP client in Buildroot without eth0 DHCP-at-boot
- [x] 1.3 Add overlay helpers: `wifi-stack-up/down.sh`, `wlan0-dhcp.sh`, `wlan0-static.sh` (or unified `wlan0-ip.sh`), `bt-stack-up/down.sh`
- [x] 1.4 Ensure wpa conf path under `/var/lib/lws-hmi/` with `ctrl_interface`, `update_config=1`; prefs dirs for IPv4 + HTTP proxy
- [x] 1.5 Confirm boot hooks still defer wifibt/wpa/network/bluetooth; extend `env-verify` for DHCP client if needed

## 2. Dart Wi-Fi platform module

- [x] 2.1 Add `lib/platform/wifi/` models + abstract `WifiController` (radio, scan, connect with `hidden`, forget, IPv4 dhcp/static)
- [x] 2.2 Implement `LinuxWpaWifiController` (`wpa_cli` + helpers; `scan_ssid=1` for hidden)
- [x] 2.3 Host unit tests for status/scan parsing, hidden→`scan_ssid`, IPv4 serialization (no PSK in logs)

## 3. Dart HTTP client + proxy module

- [x] 3.1 Add `lib/platform/http/` abstract controller: proxy get/set + `request` → status/body/error
- [x] 3.2 Implement Linux/Dart backend honoring proxy (HttpClient first; Process `curl` fallback if needed)
- [x] 3.3 Host unit tests for proxy persistence parsing and password redaction

## 4. Dart Bluetooth platform module (discoverable / incoming)

- [x] 4.1 Add `lib/platform/bluetooth/` models + abstract API: adapter, alias/address, discoverable/pairable, incoming peers, disconnect/remove — **no central scan API**
- [x] 4.2 Implement `LinuxBluezBluetoothController` (D-Bus or `bluetoothctl` behind same API)
- [x] 4.3 Host unit tests for address/name parsing of incoming Device1 lists

## 5. Demo UI

- [x] 5.1 Wi-Fi section: toggle, status, scan/connect, **hidden SSID form**, **DHCP/static IPv4**, disconnect/forget
- [x] 5.2 Proxy fields + **HTTP request button** showing status/truncated body/error
- [x] 5.3 Bluetooth section: toggle, name/address, discoverable/pairable, incoming remotes — **no scan-others UI**
- [x] 5.4 Post-frame init only; failures non-fatal

## 6. Docs and acceptance

- [x] 6.1 `app/hmi/README.md` smoke: visible+hidden Wi-Fi, DHCP+static, proxy on/off HTTP probe, phone discovers/pairs to HMI (A2DP Sink speaker)
- [x] 6.2 Update `docs/flutter-pi-hmi-plan.md` §12 (and §1.1 BT wording) to match discoverable role + new Wi-Fi options when smoke passes
- [x] 6.3 Device acceptance: HTTP probe succeeds on associated wlan0; phone sees HMI when discoverable, connects as media remote, music on speaker; `verify-boot` still PASS for deferred units
