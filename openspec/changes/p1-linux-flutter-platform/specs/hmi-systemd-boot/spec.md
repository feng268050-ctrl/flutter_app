## ADDED Requirements

### Requirement: Plan A minimal systemd is PID 1

The P1 image SHALL use systemd as PID 1 (init and service manager) and SHALL ship `libsystemd.so` for flutter-pi (`sd_event`); libsystemd availability does not by itself mandate systemd as init, but both are enabled via `lws_hmi_systemd.config`. The image MUST disable systemd-networkd, systemd-resolved, systemd-timesyncd, systemd-logind, and polkit packages per that config.

#### Scenario: systemd is init

- **WHEN** P1 device boots
- **THEN** `ps -p 1` shows systemd as PID 1

#### Scenario: networkd not active

- **WHEN** P1 device reaches multi-user target
- **THEN** `systemd-networkd` is not running

### Requirement: hmi.service auto-starts flutter-pi after local-fs only

The `hmi.service` unit SHALL be enabled in `multi-user.target.wants`, start `/usr/bin/flutter-pi --release /opt/hmi`, restart on failure, and MUST depend only on `local-fs.target` — not on `network-online.target`, `mediamtx.service`, or `systemd-udev-settle.service`.

#### Scenario: hmi enabled at image build

- **WHEN** P1 rootfs is produced
- **THEN** symlink exists at `etc/systemd/system/multi-user.target.wants/hmi.service`

#### Scenario: critical chain excludes network

- **WHEN** operator runs `systemd-analyze critical-chain hmi.service` on device
- **THEN** output does not include mediamtx, network-online, or udev-settle units

#### Scenario: flutter-pi starts automatically

- **WHEN** device boots to multi-user without manual intervention
- **THEN** `flutter-pi` process is running with `/opt/hmi` as bundle path

### Requirement: Non-critical services disabled at image build

Post-build hook SHALL enable only `hmi.service` and SHALL disable `mediamtx.service`, `sshd.service`, and `bluetooth.service` from `multi-user.target.wants` if those unit files exist.

#### Scenario: mediamtx not auto-started

- **WHEN** P1 device boots
- **THEN** `mediamtx` process is not running and unit is not in multi-user wants

#### Scenario: sshd not listening by default

- **WHEN** P1 device boots on LAN
- **THEN** port 22 is not accepting connections until manually enabled

### Requirement: journald uses volatile storage

journald configuration overlay SHALL set volatile storage so logs are not persisted to eMMC by default.

#### Scenario: journald volatile config present

- **WHEN** P1 rootfs is inspected
- **THEN** `journald.conf.d/00-lws-hmi-volatile.conf` exists with Storage=volatile

### Requirement: Boot KPI to first home frame

From power-on on eMMC storage, the Flutter Hello World home frame SHALL become visible within 10 seconds under Plan A configuration, measured on ynh960 baseline hardware.

#### Scenario: KPI stopwatch test

- **WHEN** tester power-cycles ynh960 with eMMC P1 image and times to first visible Hello World content
- **THEN** elapsed time is ≤ 10 seconds in typical conditions (document actual measurement)
