## 1. Foundations

- [ ] 1.1 Spike: Dart/FFI vs tiny event-helper binaries for netlink, wpa ctrl, D-Bus, udev on current flutter-pi / Flutter pin; record choice in notes.md
- [ ] 1.2 Shared guidelines helper (offline UI isolate, debounce emits, reconnect backoff) used by all monitors

## 2. P0 — Network & radio (must)

- [ ] 2.1 Ethernet: netlink monitor → `LinuxEthernetController` Streams; remove Timer+`ip` primary status poll
- [ ] 2.2 Wi‑Fi: wpa ctrl ATTACH/events → `LinuxWpaWifiController` Streams; remove Timer+`wpa_cli`/`ip` primary status poll
- [ ] 2.3 Bluetooth: BlueZ D-Bus client → `LinuxBluezBluetoothController` Streams; remove Timer+`bluetoothctl` primary status poll
- [ ] 2.4 Unit tests: canned netlink/wpa/D-Bus fixtures → phase/admin/peer mapping
- [ ] 2.5 Device smoke: `ip link` / `wpa_cli` / `bluetoothctl` / phone disconnect update Demo

## 3. P0 — SSH & keyboard (must)

- [ ] 3.1 LAN SSH: systemd D-Bus watch on `ssh-debug-lan.service`; add enabled Stream to `SshDebugController`; Demo listens
- [ ] 3.2 USB keyboard: udev monitor replaces Timer presence poll; Demo listens to Stream
- [ ] 3.3 Device smoke: `systemctl stop ssh-debug-lan.service`; plug/unplug HID keyboard

## 4. P1 — Datetime / backlight / volume

- [ ] 4.1 DateTime: timedate1 subscription + prefs file watch; keep UI clock tick as presentation timer only
- [ ] 4.2 Backlight: inotify on sysfs brightness → optional Stream; Demo slider tracks external writes
- [ ] 4.3 Volume: ALSA mixer notify when available; document if board cannot notify (still no Timer+amixer poll)
- [ ] 4.4 Optional: inotify on `http-proxy` prefs for Studio/out-of-band edits

## 5. Demo / docs / close-out

- [ ] 5.1 Strip Demo-local status Timers for in-scope sections; Stream-only wiring
- [ ] 5.2 Update `app/hmi/README.md` external-change smoke matrix (eth/wifi/bt/ssh/keyboard + P1 items)
- [ ] 5.3 Confirm first-frame / P2.3 After=hmi restore unchanged (no observation on critical path)
- [ ] 5.4 Explicitly leave Modbus/LED/orientation/HTTP-probe out of event migration in notes
