# hmi-systemd-boot Specification

## Purpose
TBD - created by archiving change p1-linux-flutter-platform. Update Purpose after archive.
## Requirements
### Requirement: Plan A minimal systemd is PID 1

The P1 image SHALL use systemd as PID 1 (init and service manager) and SHALL ship `libsystemd.so` for flutter-pi (`sd_event`); libsystemd availability does not by itself mandate systemd as init, but both are enabled via `lws_hmi_systemd.config`. The image MUST disable systemd-networkd, systemd-resolved, systemd-timesyncd, systemd-logind, and polkit packages per that config.

#### Scenario: systemd is init

- **WHEN** P1 device boots
- **THEN** `ps -p 1` shows systemd as PID 1

#### Scenario: networkd not active

- **WHEN** P1 device reaches multi-user target
- **THEN** `systemd-networkd` is not running

### Requirement: hmi.service auto-starts flutter-pi after local-fs only

The `hmi.service` unit SHALL be enabled in `multi-user.target.wants`, start `/usr/bin/flutter-pi --release -o landscape_left /opt/hmi` with `Nice=-5`, restart on failure, and MUST depend only on `local-fs.target` and `lws-hmi-performance.service` — not on `network-online.target`, `mediamtx.service`, or `systemd-udev-settle.service`.

#### Scenario: hmi enabled at image build

- **WHEN** P1 rootfs is produced
- **THEN** symlink exists at `etc/systemd/system/multi-user.target.wants/hmi.service`

#### Scenario: boot-verify confirms Plan A boot chain

- **WHEN** operator runs `/usr/lib/lws-hmi/boot-verify.sh` on device after flash
- **THEN** output reports PASS for hmi/mainserver/performance/pwrkey enabled and mediamtx/sshd/wpa_supplicant/network not in multi-user wants

#### Scenario: flutter-pi starts automatically

- **WHEN** device boots to multi-user without manual intervention
- **THEN** `flutter-pi` process is running with `/opt/hmi` as bundle path

### Requirement: Boot-supporting services enabled at image build

Post-build hook SHALL enable `hmi.service`, `mainserver.service` (Innohi display daemon), `lws-hmi-performance.service` (CPU/DMC/GPU governors), and `lws-hmi-pwrkey-poweroff.service` in `multi-user.target.wants`. `param-update.service` SHALL be enabled in `sysinit.target.wants` for early display init.

#### Scenario: mainserver enabled

- **WHEN** P1 rootfs is produced
- **THEN** symlink exists at `etc/systemd/system/multi-user.target.wants/mainserver.service`

#### Scenario: performance service runs before hmi

- **WHEN** device boots
- **THEN** `lws-hmi-performance.service` completes (`RemainAfterExit=yes`) before `hmi.service` starts

### Requirement: Non-critical services disabled at image build

Post-build hook SHALL disable `mediamtx.service`, `sshd.service`, `sshd.socket`, `bluetooth.service`, `wifibt-init.service`, `wpa_supplicant.service`, `network.service`, and `log-guardian.service` from all `*.wants` directories. `systemd-network-generator.service` SHALL be masked. `08-lws-hmi-systemd-finalize.sh` SHALL undo SDK post-hook re-enables (e.g. `log-guardian`).

#### Scenario: mediamtx not auto-started

- **WHEN** P1 device boots
- **THEN** `mediamtx` process is not running and unit is not in multi-user wants

#### Scenario: sshd not listening by default

- **WHEN** P1 device boots on LAN
- **THEN** port 22 is not accepting connections until manually enabled

#### Scenario: Wi-Fi/BT deferred at boot

- **WHEN** P1 device reaches multi-user target
- **THEN** `wifibt-init.service`, `wpa_supplicant.service`, and `network.service` are not in multi-user wants

### Requirement: journald uses volatile storage

journald configuration overlay SHALL set volatile storage so logs are not persisted to eMMC by default.

#### Scenario: journald volatile config present

- **WHEN** P1 rootfs is inspected
- **THEN** `journald.conf.d/00-lws-hmi-volatile.conf` exists with Storage=volatile

### Requirement: eMMC noatime via fstab

Post-build hook SHALL patch `/etc/fstab` to add `noatime` mount options on ext4 partitions. `noatime` MUST NOT be passed via kernel `rootflags=noatime` bootargs.

#### Scenario: noatime on root mount

- **WHEN** P1 device boots and `mount` is inspected
- **THEN** root ext4 mount includes `noatime`

### Requirement: Stable board poweroff without Mali DRM oops

The image SHALL provide `lws-hmi-pwrkey-poweroff.service`, `pwrkey-poweroff.sh`, `shutdown.sh`, and a `/usr/bin/systemctl` wrapper that routes `poweroff`/`halt`/`reboot` through SysRq `s/u/o` (sync, remount-ro, poweroff) without stopping `hmi.service` first.

#### Scenario: pwrkey service active

- **WHEN** P1 device boots with gpio-keys power input present
- **THEN** `lws-hmi-pwrkey-poweroff.service` is active

#### Scenario: systemctl wrapper installed

- **WHEN** P1 rootfs is inspected
- **THEN** `/usr/bin/systemctl` symlinks to `/usr/lib/lws-hmi/systemctl-poweroff-wrapper.sh` and `/usr/bin/systemctl.real` exists

### Requirement: Boot KPI to first home frame

From power-on on eMMC storage, the Flutter Hello World home frame SHALL become visible within 10 seconds under Plan A configuration, measured on ynh960 baseline hardware.

#### Scenario: KPI stopwatch test

- **WHEN** tester power-cycles ynh960 with eMMC P1 image and times to first visible Hello World content
- **THEN** elapsed time is ≤ 10 seconds in typical conditions (measured ~8.4 s on ynh960 eMMC, 2026-07)

### Requirement: Device boot verification script

The image SHALL ship `/usr/lib/lws-hmi/boot-verify.sh` that validates Plan A unit enable/disable state, pwrkey poweroff setup, performance governors, flutter-pi running, and critical-chain expectations.

#### Scenario: boot-verify passes on P1 device

- **WHEN** operator runs `/usr/lib/lws-hmi/boot-verify.sh` after flash
- **THEN** script reports `=== boot-verify: ALL PASS ===` and exits 0

