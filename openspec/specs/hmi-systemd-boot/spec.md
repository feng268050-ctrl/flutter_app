# hmi-systemd-boot Specification

## Purpose
TBD - created by archiving change p1-linux-flutter-platform. Update Purpose after archive.
## Requirements
### Requirement: Plan A minimal systemd is PID 1

The P1 image SHALL use systemd as PID 1 (init and service manager) and SHALL ship `libsystemd.so` for the eLinux HMI (`sd_event`); libsystemd availability does not by itself mandate systemd as init, but both are enabled via `lws_hmi_systemd.config`. **P3.1 / D11:** the image SHALL enable **systemd-networkd** and **systemd-resolved**. The image SHALL ship and preset-**enable** **systemd-timesyncd** (Settings Automatic NTP default on). It MUST keep systemd-logind and polkit packages disabled per that config.

#### Scenario: systemd is init

- **WHEN** P1 device boots
- **THEN** `ps -p 1` shows systemd as PID 1

#### Scenario: networkd and resolved enabled (P3.1)

- **WHEN** the appliance image reaches multi-user target after the D11 network cutover
- **THEN** `systemd-networkd` and `systemd-resolved` are enabled (preset) and provide L3 addressing and DNS

### Requirement: hmi.service auto-starts the HMI after local-fs only

The `hmi.service` unit SHALL be enabled in `multi-user.target.wants`, start `/usr/bin/eLinux HMI --release -o landscape_left /opt/hmi` with `Nice=-5`, restart on failure, and MUST depend only on `local-fs.target` and `cpu-performance.service` — not on `network-online.target` or `systemd-udev-settle.service`. The HMI MUST NOT depend on a rootfs `mediamtx.service` (MediaMTX is App-owned under `/opt/hmi`).

#### Scenario: hmi enabled at image build

- **WHEN** P1 rootfs is produced
- **THEN** symlink exists at `etc/systemd/system/multi-user.target.wants/hmi.service`

#### Scenario: verify-boot confirms Plan A boot chain

- **WHEN** operator runs `verify-boot` on device after flash
- **THEN** output reports PASS for hmi/mainserver/performance/pwrkey enabled and sshd/wpa_supplicant/network not in multi-user wants

#### Scenario: HMI starts automatically

- **WHEN** device boots to multi-user without manual intervention
- **THEN** `eLinux HMI` process is running with `/opt/hmi` as bundle path

### Requirement: Boot-supporting services enabled at image build

Post-build hook SHALL enable `hmi.service`, `mainserver.service` (Innohi display daemon), `cpu-performance.service` (CPU/DMC/GPU governors), and `pwrkey-poweroff.service` in `multi-user.target.wants`. `param-update.service` SHALL be enabled in `sysinit.target.wants` for early display init.

#### Scenario: mainserver enabled

- **WHEN** P1 rootfs is produced
- **THEN** symlink exists at `etc/systemd/system/multi-user.target.wants/mainserver.service`

#### Scenario: performance service runs before hmi

- **WHEN** device boots
- **THEN** `cpu-performance.service` completes (`RemainAfterExit=yes`) before `hmi.service` starts

### Requirement: Non-critical services disabled at image build

Post-build hook SHALL disable `sshd.service`, `sshd.socket`, `bluetooth.service`, `wifibt-init.service`, `wpa_supplicant.service`, `network.service`, and `log-guardian.service` from all `*.wants` directories. `systemd-network-generator.service` SHALL be masked. `08-systemd-finalize.sh` SHALL undo SDK post-hook re-enables (e.g. `log-guardian`). The image MUST NOT ship a product `mediamtx.service` unit.

#### Scenario: sshd not listening by default

- **WHEN** P1 device boots on LAN
- **THEN** port 22 is not accepting connections until manually enabled

#### Scenario: Wi-Fi/BT deferred at boot

- **WHEN** P1 device reaches multi-user target
- **THEN** `wifibt-init.service`, `wpa_supplicant.service`, and `network.service` are not in multi-user wants

#### Scenario: mediamtx not a boot unit

- **WHEN** P1 device boots
- **THEN** no `mediamtx.service` unit is enabled in multi-user wants
- **AND** a mediamtx process MUST NOT be running solely because of boot (App may start it later after IPC is healthy)

### Requirement: journald uses volatile storage

journald configuration overlay SHALL set volatile storage so logs are not persisted to eMMC by default.

#### Scenario: journald volatile config present

- **WHEN** P1 rootfs is inspected
- **THEN** `journald.conf.d/00-volatile-storage.conf` exists with Storage=volatile

### Requirement: eMMC noatime via fstab

Post-build hook SHALL patch `/etc/fstab` to add `noatime` mount options on ext4 partitions. `noatime` MUST NOT be passed via kernel `rootflags=noatime` bootargs.

#### Scenario: noatime on root mount

- **WHEN** P1 device boots and `mount` is inspected
- **THEN** root ext4 mount includes `noatime`

### Requirement: Stable board poweroff without Mali DRM oops

The image SHALL provide `pwrkey-poweroff.service`, `pwrkey-poweroff.sh`, `shutdown.sh`, and a `/usr/bin/systemctl` wrapper. The pwrkey handler SHALL request poweroff after the `KEY_POWER` release event. Rockchip `input-event-daemon.service` SHALL be disabled because its short-press release handler requests suspend and races the poweroff flow. Until repeated eLinux HMI teardown is proven stable, poweroff, halt, and reboot SHALL avoid stopping `hmi.service`, sync storage, and use SysRq `s/u/o` or `s/u/b`.

#### Scenario: pwrkey service active

- **WHEN** P1 device boots with gpio-keys power input present
- **THEN** `pwrkey-poweroff.service` is active

#### Scenario: systemctl wrapper installed

- **WHEN** P1 rootfs is inspected
- **THEN** `/usr/bin/systemctl` symlinks to `/usr/libexec/hmi/systemctl-poweroff-wrapper.sh` and `/usr/bin/systemctl.real` exists

#### Scenario: Poweroff avoids HMI teardown

- **WHEN** the power key or `systemctl poweroff` requests shutdown
- **THEN** storage is synced and shutdown uses SysRq without stopping eLinux HMI

#### Scenario: SysRq is unavailable

- **WHEN** the requested SysRq action does not complete
- **THEN** shutdown falls back to forced `systemctl.real` shutdown

### Requirement: Flutter process teardown does not crash DRM GEM release

The kernel SHALL tolerate transient `NULL`/invalid object entries and an object whose `obj->dev` has become a non-kernel address in a DRM file's GEM handle IDR. Because repeated teardown has also produced a non-NULL but corrupted `drm_gem_object.funcs` pointer, Rockchip SHALL publish its immutable GEM funcs table and the GEM core SHALL restore that canonical pointer before invoking release or free callbacks.

#### Scenario: Stop eLinux HMI while render threads are exiting

- **WHEN** `hmi.service` is stopped and eLinux HMI releases DRM/GEM handles
- **THEN** the kernel does not oops in `drm_gem_object_release_handle`

#### Scenario: Switch between release and debug payloads

- **WHEN** tooling replaces the active HMI payload
- **THEN** it stops all service-managed and detached `eLinux HMI` instances, waits for process and deferred DRM/Mali teardown, and only then starts one new instance
- **AND** the DRM device can be acquired by a subsequent eLinux HMI process

### Requirement: Boot KPI to first home frame

From power-on on eMMC storage, the Flutter Hello World home frame SHALL become visible within 10 seconds under Plan A configuration, measured on ynh960 baseline hardware.

#### Scenario: KPI stopwatch test

- **WHEN** tester power-cycles ynh960 with eMMC P1 image and times to first visible Hello World content
- **THEN** elapsed time is ≤ 10 seconds in typical conditions (measured ~8.4 s on ynh960 eMMC, 2026-07)

### Requirement: Device boot verification script

The image SHALL ship `verify-boot` in the device command path; it validates Plan A unit enable/disable state, pwrkey poweroff setup, performance governors, eLinux HMI running, and critical-chain expectations.

#### Scenario: verify-boot passes on P1 device

- **WHEN** operator runs `verify-boot` after flash
- **THEN** script reports `=== verify-boot: ALL PASS ===` and exits 0

### Requirement: Device operator commands use verb-first names

The image SHALL expose `verify-boot`, `verify-env`, and `diagnose-hmi` through `/usr/bin`, while keeping their implementation scripts under `/usr/libexec/hmi/`.

#### Scenario: Operator invokes verification without implementation paths

- **WHEN** an operator opens a device shell after flash
- **THEN** `verify-boot`, `verify-env`, and `diagnose-hmi` resolve from `PATH`

### Requirement: Deferred Wi-Fi and Bluetooth units may start on demand

Plan A SHALL continue to leave `wifibt-init.service`, `wpa_supplicant.service`, `network.service`, and `bluetooth.service` out of `multi-user.target.wants` at image build. The image MAY provide HMI-facing helpers that `systemctl start` those units **after boot** when the application enables Wi-Fi or Bluetooth. `hmi.service` MUST continue to depend only on local-fs / performance — not on `network-online.target` or Wi-Fi/BT readiness.

#### Scenario: Boot still defers wifibt and bluetooth

- **WHEN** the device reaches multi-user target without user/App radio enable
- **THEN** `wifibt-init.service`, `wpa_supplicant.service`, `network.service`, and `bluetooth.service` are not required to be active, and those units remain absent from multi-user wants

#### Scenario: On-demand start does not change hmi dependencies

- **WHEN** an operator or the HMI starts `wpa_supplicant` or `bluetooth` after boot
- **THEN** `hmi.service` unit dependencies still do not include `network-online.target` or those radio units

### Requirement: eth0 addressing never blocks hmi first frame

Plan A SHALL continue to leave `network.service` and `dhcpcd.service` out of `multi-user.target.wants`. HMI-facing eth0 helpers MAY configure eth0 **after boot** when the application enables Ethernet or applies IPv4. `hmi.service` MUST continue to depend only on local-fs / performance — not on `network-online.target`, eth0 carrier, or DHCP completion.

#### Scenario: Boot does not wait for eth0

- **WHEN** the device reaches multi-user target without Ethernet cable or eth0 IPv4
- **THEN** `hmi.service` still starts and first-frame paint is not gated on eth0 link or addressing

#### Scenario: On-demand eth0 config does not change hmi dependencies

- **WHEN** an operator or the HMI runs eth0 DHCP/static helpers after boot
- **THEN** `hmi.service` unit dependencies still do not include `network-online.target` or eth0 readiness

### Requirement: Settings restore unit at multi-user

`settings-restore.service` SHALL be enabled in `multi-user.target.wants`. On-demand Wi‑Fi/eth0 units (`wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`) MUST remain disabled at boot via preset and MUST NOT appear in `multi-user.target.wants` except as started by restore or Demo.

#### Scenario: Preset disables on-demand radio units

- **WHEN** the image is built
- **THEN** preset disables `wlan-wpa.service`, `wlan-dhcp.service`, and `eth0-network.service`

### Requirement: HMI does not own settings cgroup

`hmi.service` MUST continue to start without `network-online.target`. Stopping `hmi.service` MUST NOT be the stop path for settings network units.

#### Scenario: hmi has no network-online dependency

- **WHEN** inspecting `hmi.service`
- **THEN** it does not require `network-online.target`

