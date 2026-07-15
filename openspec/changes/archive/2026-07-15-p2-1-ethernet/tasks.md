## 1. Overlay helpers and verify

- [x] 1.1 Add `eth0-dhcp.sh` and `eth0-static.sh` under `lws-hmi-fs-overlay/usr/lib/lws-hmi/` (eth0-only; refuse wlan0/usb0; separate dhcpcd pidfile)
- [x] 1.2 Optionally add thin `eth0-link.sh up|down` if the Linux controller should not call `ip` directly
- [x] 1.3 Update `scripts/verify-rootfs-overlay.sh` and `env-verify.sh` (overlay + scripts copies) for new helpers / `eth0-ipv4` expectation
- [x] 1.4 Confirm `dhcpcd.service` / `network.service` remain disabled at boot (no defconfig change unless a missing tool is found)

## 2. Dart platform abstraction

- [x] 2.1 Add `lib/platform/ethernet/` models (`EthIpv4Config` + store for `/var/lib/lws-hmi/eth0-ipv4`, link phase / details)
- [x] 2.2 Add abstract `EthernetController` (enable, streams, get/set IPv4, linkDetails, dispose)
- [x] 2.3 Implement `LinuxEthernetController` calling eth0 helpers + `ip`/sysfs for carrier/MAC/speed
- [x] 2.4 Unit-test parsers / store serialization (mirror wifi ipv4 store tests if present)

## 3. Demo UI

- [x] 3.1 Add `EthernetDemoSection` (toggle, status, DHCP/static form + Apply) patterned on `WifiDemoSection` IPv4 block
- [x] 3.2 Wire section into `p2_demo_page.dart` **above** `WifiDemoSection`; construct after first frame with other network controllers
- [x] 3.3 Short subtitle that this is RJ45 bring-up (IPC camera addressing remains P5.1)

## 4. Docs and acceptance

- [x] 4.1 Update `docs/flutter-pi-hmi-plan.md` §12 P2.1 Ethernet checklist (Demo + board smoke)
- [x] 4.2 Note helpers in `app/hmi/README.md` if Wi‑Fi helpers are listed there
- [x] 4.3 `flutter analyze` / relevant tests under `app/hmi/`
- [x] 4.4 Device smoke: RJ45 link → DHCP or static → ping peer PC (operator)
