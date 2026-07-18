## Why

> **SUPERSEDED** — first folded into [`rust-hal-and-phase-realign`](../2026-07-18-rust-hal-and-phase-realign/); HAL Platform API is now [`dart-hal-package`](../../dart-hal-package/). See [`SUPERSEDED.md`](./SUPERSEDED.md). Do not implement this change standalone.

P2 Demo already exposes Ethernet, Wi‑Fi, Bluetooth, LAN SSH, USB keyboard, date/time, audio, backlight, and more—but several Linux backends still discover state by **Timer + `Process.run` polling**. That requirement remains valid; observation improvements land with the **Dart HAL** package over time, not this standalone change.

## What Changes

- Establish a cross-cutting rule: **anything Demo shows as live OS state SHALL be event-driven (or equivalent fd/subscribe), not primary Process polling.**
- Upgrade Linux backends for all Demo capabilities where an OS event channel exists (see scope matrix in design).
- Keep public Dart controller abstractions; swap Linux observation paths.
- Document explicit **non-goals** (Modbus telemetry, LED modes as HMI-owned, orientation apply via restart, HTTP probe as request/response).
- P2.3 restore / UI-first boot ordering unchanged.

## Capabilities

### New Capabilities

- `linux-lan-ssh-debug`: Event-driven LAN SSH debug enablement state (systemd unit / helper status via subscription, not status Process poll as primary).
- `linux-usb-hid-keyboard`: USB HID keyboard presence via udev (or equivalent), Stream-based, not Timer directory poll as primary.
- `linux-datetime`: Wall-clock prefs remain files; system timezone / NTP-related changes observable via `timedate1` (or documented equivalent) when available; Demo clock tick may remain UI timer.

### Modified Capabilities

- `linux-wifi`: wpa_supplicant control-interface events as primary status path.
- `linux-ethernet`: netlink / `RTM_*` (or equivalent) for admin/carrier/IPv4 as primary status path.
- `linux-bluetooth`: BlueZ **D-Bus** PropertiesChanged / ObjectManager as primary; retire `bluetoothctl` Timer poll as primary.
- `linux-backlight`: Observability of sysfs brightness changes when modified outside the controller (e.g. inotify), so UI sliders can track.
- `linux-media-audio`: Observability of mixer volume when changed outside the controller (ALSA notify / equivalent), where feasible.
- `p2-device-demo-ui`: All listed live sections MUST reflect external OS changes through controller Streams without operator re-entry.

## Impact

- **App:** `lib/platform/{wifi,ethernet,bluetooth,ssh,input,datetime,backlight,audio}/` Linux implementations; shared patterns for isolate/async I/O.
- **Rootfs:** D-Bus policy already needed for BlueZ; udev available; wpa ctrl socket; no NetworkManager.
- **Boot KPI:** Observation must not block first paint; P2.3 restore stays After=hmi.
- **Tests:** Event parsers + fakes per backend; device smokes for shell/udev-driven UI updates.
