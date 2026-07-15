## Why

Developers need adb-connect-style host tooling (`make connect`) **and** a way to turn on LAN/WLAN `sshd` on the board. Host registry alone is useless while OpenSSH only binds USB-SSH (`192.168.55.1`). Product plan previously deferred LAN sshd to P5 (§7.7); P2.1 already validates eth0/wlan0, so on-demand LAN/WLAN SSH should land with the remote-SSH host workflow and a Demo toggle.

## What Changes

- Add **`make connect <ip>`** / **`make disconnect <ip>`** host registry (`MODE=SSH`) and wire `push-app` / `debug-app` / `shell` / `logs` / `reboot` (not `reboot-loader`).
- Add **`IP=`** selection for SSH registry only; **`SERIAL=`** continues to select USB-SSH or SSH by serial.
- On-device: **`enable-ssh-debug.sh` / `disable-ssh-debug.sh`** (and status) start/stop **LAN/WLAN** sshd on demand; **not** enabled at boot; reboot returns to off.
- Split sshd config so USB plug-ssh remains usb0-only by default, while LAN enable listens on eth0/wlan0 addresses only (never `0.0.0.0`) without making boot-time `sshd.service` listen.
- P2 Demo: switch **after HTTP / Proxy** to enable/disable LAN SSH debug.
- Plan docs: move LAN/WLAN on-demand sshd from P5.7 / §7.7 “P5 only” into **P2.1**.

## Capabilities

### New Capabilities

- `host-remote-ssh`: Host registry and transport for remote IP SSH devices.
- `linux-lan-ssh-debug`: On-demand LAN/WLAN OpenSSH debug (scripts, config coexistence with USB plug-ssh, boot defaults remain off).

### Modified Capabilities

- `host-push-hmi`: `make devices`, `push-app`, and `reboot` also target registered SSH devices; selection gains `IP=`.
- `host-debug-hmi`: Debug adapters reuse shared selection including `IP=`.
- `p2-device-demo-ui`: Demo exposes LAN SSH debug toggle after HTTP / Proxy.
- `usb-plug-ssh-debug`: Clarify coexistence when LAN debug is also active (USB path may reuse listening sshd).

## Impact

- Host scripts + Makefile/README (already partially implemented).
- Rootfs overlay: `enable-ssh-debug.sh` / `disable-ssh-debug.sh`, sshd_config.d split, `usb-plug-ssh-start.sh` coexistence, `boot-verify` / `verify-rootfs-overlay` / `apply-overlay` (stop treating enable-ssh as retired).
- Flutter: platform controller + Demo section; `docs/flutter-pi-hmi-plan.md` phase tables.
