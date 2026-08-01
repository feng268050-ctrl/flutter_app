## MODIFIED Requirements

### Requirement: Plan A minimal systemd is PID 1

The P1 image SHALL use systemd as PID 1 (init and service manager) and SHALL ship `libsystemd.so` for the eLinux HMI (`sd_event`); libsystemd availability does not by itself mandate systemd as init, but both are enabled via `lws_hmi_systemd.config`. **P3.1 / D11:** the image SHALL enable **systemd-networkd** and **systemd-resolved**. The image SHALL ship **systemd-timesyncd** and the appliance preset MUST **enable** `systemd-timesyncd.service` at boot (Settings Automatic NTP default on). On ynh960, the image MUST use the external PCF8563-compatible RTC on i2c5 @0x51 for HCTOSYS/SYSTOHC and MUST NOT register the RK809 PMIC RTC (`CONFIG_RTC_DRV_RK808` unset in the ynh960 kernel fragment). It MUST keep systemd-logind and polkit packages disabled per that config. chrony MUST remain unset.

#### Scenario: systemd is init

- **WHEN** P1 device boots
- **THEN** `ps -p 1` shows systemd as PID 1

#### Scenario: networkd and resolved enabled (P3.1)

- **WHEN** the appliance image reaches multi-user target after the D11 network cutover
- **THEN** `systemd-networkd` and `systemd-resolved` are enabled (preset) and provide L3 addressing and DNS

#### Scenario: timesyncd enabled by default

- **WHEN** the appliance image reaches multi-user target with default datetime prefs
- **THEN** `systemd-timesyncd` is enabled by preset
- **AND** `hmi.service` MUST NOT depend on `time-sync.target` or `network-online.target`

## ADDED Requirements

### Requirement: External RTC systohc without NTP

Post-build / overlay SHALL enable `rtc-systohc.timer` and SHALL ship `rtc-systohc.service` that runs `hwclock -w -u` so the external RTC tracks the running clock when NTP is off or unreachable. The image MUST NOT ship fake-hwclock load/save units.

#### Scenario: rtc-systohc in appliance preset

- **WHEN** the rootfs overlay preset `99-appliance.preset` is inspected
- **THEN** it contains `enable rtc-systohc.timer`
- **AND** it contains `enable systemd-timesyncd.service`

#### Scenario: verify-env accepts enabled timesyncd

- **WHEN** operator runs `verify-env` on a device built with this change after flash/upgrade
- **THEN** the script reports that the timesyncd unit/binary is present and that the service is enabled by preset (or warns if unexpectedly disabled)
