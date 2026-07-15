## Why

P2.1 now treats Ethernet as **RJ45 / eth0 hardware smoke**, separate from later IPC camera business (`configure-camera-eth0.sh` stays P5.1). Wi‑Fi already has a reusable Dart controller + Demo UI with DHCP/static IPv4; eth0 still has no equivalent Demo path, so operators cannot prove link-up or address the RJ45 port without shell. Pulling Ethernet forward with the same abstraction pattern de-risks PHY/DTS before P5.

## What Changes

- Add reusable Dart **`EthernetController`** (link admin up/down, carrier/status streams, **DHCP vs static IPv4** on eth0) with a Linux implementation via overlay helpers — mirror `WifiController` packaging.
- Add overlay helpers **`eth0-dhcp.sh` / `eth0-static.sh`** (and minimal link helpers if needed); persist eth0 IPv4 preference under `/var/lib/lws-hmi/eth0-ipv4`. Still **no** `dhcpcd.service` / networkd at boot.
- Extend the **P2 / P2.1 Demo home**: **Ethernet section placed above Wi‑Fi**, same DHCP/static controls pattern (no SSID/scan).
- Update plan §12 P2.1 Ethernet checklist wording as this slice lands (device smoke checkbox remains for board validation).
- **Non-goals**: IPC camera segment planner / `configure-camera-eth0.sh`; MediaMTX; product Settings / status bar (P5.2); NetworkManager; touching wlan0 or usb0 addressing; Android backends until P2.5.

## Capabilities

### New Capabilities

- `linux-ethernet`: eth0 link bring-up + DHCP/static IPv4 via abstract Dart API and Linux helpers (no NetworkManager / no boot DHCP).

### Modified Capabilities

- `p2-device-demo-ui`: Demo home gains an Ethernet management section **above** Wi‑Fi, using `EthernetController` with DHCP/static controls.
- `buildroot-lws-hmi-image`: Document eth0-scoped DHCP/static helpers in rootfs overlay (still not boot-enabled DHCP on eth0).
- `hmi-systemd-boot`: Confirm eth0 helpers and addressing never block `hmi.service` / first frame (align with §7.0).

## Impact

- **App**: `app/hmi/lib/platform/ethernet/*`, `ui/demo/ethernet_demo_section.dart`, wire into `p2_demo_page.dart` before `WifiDemoSection`.
- **Overlay**: new scripts under `lws-hmi-fs-overlay/usr/lib/lws-hmi/`; default store file under `/var/lib/lws-hmi/`; update `verify-rootfs-overlay.sh` / `env-verify.sh` lists.
- **Reuse**: dhcpcd / udhcpc already present for wlan0; eth0 helpers invoke them with **`-i eth0` only** and must refuse wlan0/usb0.
- **Docs**: `docs/flutter-pi-hmi-plan.md` §12 P2.1 Ethernet item; optional note in `app/hmi/README.md`.
- **Later P5.1**: camera eth0 script remains a separate path that may reconfigure eth0 for the IPC segment; this change does not implement that coordinator.
