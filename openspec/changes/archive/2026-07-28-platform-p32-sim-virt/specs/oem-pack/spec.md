## ADDED Requirements

### Requirement: sim_virt OEM pack

The repository SHALL provide OEM pack `sim_virt` with `oem/packs/sim_virt/manifest.json` declaring `board_id` `sim`, `screen_id` `virt`, paths `boards/sim` and `screens/virt`, and `compat.soc_family` of `virt` (not `rk356x`). `OEM_ID=sim_virt make build-oem` SHALL produce `oem/out/sim_virt/oem.img`.

#### Scenario: sim_virt pack present

- **WHEN** a developer inspects `oem/packs/sim_virt/manifest.json`
- **THEN** the manifest SHALL declare `pack_id` `sim_virt`, `board_id` `sim`, `screen_id` `virt`, and `compat.soc_family` `virt`

#### Scenario: build-oem for sim_virt

- **WHEN** `OEM_ID=sim_virt make build-oem` succeeds
- **THEN** `oem/out/sim_virt/oem.img` SHALL exist as an ext4 image containing the pack layout

### Requirement: sim board profile without OTG

OEM `oem/boards/sim/board_profile.json` SHALL declare capabilities for ethernet, wifi, bluetooth, gpio, modbus, sysInfo, datetime, sshDebug, and typical I/O (backlight/volume/keyboard/mouse as applicable). It MUST omit `usbOtg`. It MUST NOT reference ynh960 helper paths. Product gpio/modbus catalogs remain App-owned. For the QEMU guest, helpers MAY include `modbus_rtu_device` remapping Modbus RTU to the USB-serial node (e.g. `/dev/ttyUSB0`) while product `modbus.json` keeps the board UART path for ynh960.

#### Scenario: No usbOtg and no ynh960 helpers

- **WHEN** inspecting `oem/boards/sim/board_profile.json`
- **THEN** capabilities SHALL NOT include `usbOtg` and helpers SHALL NOT point at `/oem/boards/ynh960/`

#### Scenario: Emulator Modbus device remap

- **WHEN** inspecting sim board helpers used by the emulator guest
- **THEN** `modbus_rtu_device` SHALL be present and point at a USB-serial path suitable for host passthrough

### Requirement: virt screen without lcd seed

OEM `oem/screens/virt/screen.json` SHALL declare logical width/height and `default_orientation` for the QEMU virtio display (defaults aligned with emulator `xres`/`yres`). It MUST NOT require `lcd/` ParamUpdate files for compose or HMI launch on the virt guest.

#### Scenario: virt screen.json compose

- **WHEN** oem-compose succeeds for `sim_virt`
- **THEN** `/run/hmi/screen.env` SHALL expose `SCREEN_DEFAULT_ORIENTATION` from virt `screen.json` without requiring lcd param files
