## MODIFIED Requirements

### Requirement: OEM board profile without product gpio/modbus catalogs

OEM `board_profile.json` SHALL declare board identity, capabilities, net roles, helpers, storage mounts, and route metrics as needed. It MUST NOT be the authoritative owner of `configs.gpio` / `configs.modbus` product catalogs (those remain App assets). Shipping OEM boards (`ynh960`, `ek3562`, and successors on the product line) MUST NOT declare `helpers.modbus_rtu_device` for the product welder UART — the App `modbus.json` `device_by_board` (plus default `transport.device`) selects RTU `device` by `board_id`. The QEMU `sim` board MAY keep `modbus_rtu_device` as a guest USB-serial remap for package tests / non-App consumers; product `modbus.json` SHALL also map `sim` → `/dev/ttyUSB0` under `device_by_board`.

The product HMI App (`lws_hmi`) MUST NOT ship `assets/hal/board_profile.json` as a Flutter asset or treat any App-bundled board profile as a Linux device fallback. Host/desktop MAY use an in-code stub profile (not a Flutter asset).

#### Scenario: OEM profile has no gpio/modbus asset paths

- **WHEN** inspecting `oem/boards/ynh960/board_profile.json`
- **THEN** it SHALL NOT point `configs.gpio` / `configs.modbus` at product App catalogs as the sole ownership story (App merges via `withProductConfigs`)

#### Scenario: Shipping OEM omits modbus_rtu_device

- **WHEN** inspecting `oem/boards/ynh960/board_profile.json` and `oem/boards/ek3562/board_profile.json`
- **THEN** helpers SHALL NOT include `modbus_rtu_device`

#### Scenario: HMI App has no board_profile asset

- **WHEN** inspecting `app/lws_hmi/pubspec.yaml` assets and `app/lws_hmi/assets/hal/`
- **THEN** `board_profile.json` SHALL NOT be listed or present under the App HAL assets

### Requirement: sim board profile without OTG

OEM `oem/boards/sim/board_profile.json` SHALL declare capabilities for ethernet, wifi, bluetooth, gpio, modbus, sysInfo, datetime, sshDebug, and typical I/O (backlight/volume/keyboard/mouse as applicable). It MUST omit `usbOtg`. It MUST NOT reference ynh960 helper paths. Product gpio/modbus catalogs remain App-owned. For the QEMU guest, helpers MAY include `modbus_rtu_device` remapping Modbus RTU to the USB-serial node (e.g. `/dev/ttyUSB0`) as a non-App / package-test fallback; product `modbus.json` `device_by_board.sim` SHALL also be `/dev/ttyUSB0`.

#### Scenario: No usbOtg and no ynh960 helpers

- **WHEN** inspecting `oem/boards/sim/board_profile.json`
- **THEN** capabilities SHALL NOT include `usbOtg` and helpers SHALL NOT point at `/oem/boards/ynh960/`

#### Scenario: Emulator Modbus device remap

- **WHEN** inspecting sim board helpers used by the emulator guest
- **THEN** `modbus_rtu_device` SHALL be present and point at a USB-serial path suitable for host passthrough
