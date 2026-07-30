## MODIFIED Requirements

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
