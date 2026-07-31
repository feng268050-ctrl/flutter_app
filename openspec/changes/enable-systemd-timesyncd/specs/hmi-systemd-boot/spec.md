## MODIFIED Requirements

### Requirement: Plan A minimal systemd is PID 1

The P1 image SHALL use systemd as PID 1 (init and service manager) and SHALL ship `libsystemd.so` for the eLinux HMI (`sd_event`); libsystemd availability does not by itself mandate systemd as init, but both are enabled via `lws_hmi_systemd.config`. **P3.1 / D11:** the image SHALL enable **systemd-networkd** and **systemd-resolved**. The image SHALL enable **systemd-timesyncd** for continuous NTP. It MUST keep systemd-logind and polkit packages disabled per that config. chrony MUST remain unset.

#### Scenario: systemd is init

- **WHEN** P1 device boots
- **THEN** `ps -p 1` shows systemd as PID 1

#### Scenario: networkd and resolved enabled (P3.1)

- **WHEN** the appliance image reaches multi-user target after the D11 network cutover
- **THEN** `systemd-networkd` and `systemd-resolved` are enabled (preset) and provide L3 addressing and DNS

#### Scenario: timesyncd enabled

- **WHEN** the appliance image reaches multi-user target with network available
- **THEN** `systemd-timesyncd` is enabled (preset) and NTP can synchronize the system clock
- **AND** `hmi.service` MUST NOT depend on `time-sync.target` or `network-online.target`

## ADDED Requirements

### Requirement: Appliance preset enables systemd-timesyncd

Post-build / overlay systemd preset SHALL enable `systemd-timesyncd.service` together with networkd and resolved so NTP survives `preset-all` during rootfs image build.

#### Scenario: timesyncd in appliance preset

- **WHEN** the rootfs overlay preset `99-appliance.preset` is inspected
- **THEN** it contains `enable systemd-timesyncd.service`

#### Scenario: verify-env reports timesyncd

- **WHEN** operator runs `verify-env` on a device built with this change after flash/upgrade
- **THEN** the script reports that `systemd-timesyncd.service` is enabled (or equivalent PASS check)
