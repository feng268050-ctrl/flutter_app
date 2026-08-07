## MODIFIED Requirements

### Requirement: Boot-supporting services enabled at image build

Post-build hook SHALL enable `hmi.service`, `mainserver.service` (Innohi display daemon), `cpu-performance.service` (CPU/DMC/GPU **power profile** restore from `/var/lib/hal/power.conf`, default `performance`), and `pwrkey-poweroff.service` in `multi-user.target.wants`. `param-update.service` SHALL be enabled in `sysinit.target.wants` for early display init.

#### Scenario: mainserver enabled

- **WHEN** P1 rootfs is produced
- **THEN** symlink exists at `etc/systemd/system/multi-user.target.wants/mainserver.service`

#### Scenario: performance service runs before hmi

- **WHEN** device boots
- **THEN** `cpu-performance.service` completes (`RemainAfterExit=yes`) before `hmi.service` starts

#### Scenario: Boot restores persisted balanced

- **WHEN** `/var/lib/hal/power.conf` contains `mode=balanced` and the device boots
- **THEN** `cpu-performance.service` applies the balanced hardware profile before `hmi.service` starts
- **AND** MUST NOT force the performance governor profile solely because the unit basename contains `performance`

### Requirement: hmi.service auto-starts the HMI after local-fs only

The `hmi.service` unit SHALL be enabled in `multi-user.target.wants`, start `/usr/bin/eLinux HMI --release -o landscape_left /opt/hmi` with `Nice=-5`, restart on failure, and MUST depend only on `local-fs.target` and `cpu-performance.service` — not on `network-online.target`, `time-sync.target`, or `systemd-udev-settle.service`. The HMI MUST NOT depend on a rootfs `mediamtx.service` (MediaMTX is App-owned under `/opt/hmi`).

#### Scenario: hmi enabled at image build

- **WHEN** P1 rootfs is produced
- **THEN** symlink exists at `etc/systemd/system/multi-user.target.wants/hmi.service`

#### Scenario: verify-boot confirms Plan A boot chain

- **WHEN** operator runs `verify-boot` on device after flash
- **THEN** output reports PASS for hmi/mainserver/performance/pwrkey enabled and sshd/wpa_supplicant/network not in multi-user wants

#### Scenario: HMI starts automatically

- **WHEN** device boots to multi-user without manual intervention
- **THEN** `eLinux HMI` process is running with `/opt/hmi` as bundle path

## ADDED Requirements

### Requirement: verify-boot respects persisted power mode

`verify-boot` SHALL validate CPU/devfreq governor (and max-freq cap when applicable) expectations against the effective load profile from `/var/lib/hal/power.conf` (missing or invalid → `performance`). For `performance`, governors SHALL be expected to be `performance` where sysfs exists (WARN if not). For `balanced`, the script MUST NOT require `performance` governors and SHALL accept the balanced selection policy (or report WARN only when governors are unexpectedly still locked to `performance` while mode is `balanced`, at product discretion).

#### Scenario: balanced mode does not false-fail governor check

- **WHEN** `power.conf` has `mode=balanced` and governors follow the balanced profile
- **THEN** `verify-boot` MUST NOT fail solely because governors are not `performance`
