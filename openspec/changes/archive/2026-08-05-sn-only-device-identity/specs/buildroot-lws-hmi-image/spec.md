## MODIFIED Requirements

### Requirement: Host USB flash via Makefile and upgrade_tool

The repo SHALL provide `scripts/flash-usb.sh` and Makefile targets for ynh960 firmware programming on a **macOS, Linux (x86_64), or Windows (Git Bash / MSYS2)** host with Rockchip **upgrade_tool** vendored at `tools/upgrade_tool/{macos,linux,windows}/`, aligned with `tools/upgrade_tool/命令行开发工具使用文档.pdf`. The host script SHALL select the platform subdirectory from the host OS (`Darwin` → `macos`, `Linux` → `linux`, `MINGW*` / `MSYS*` / `CYGWIN*` → `windows`).

- `make audit` — pre-flight before flash (firmware on host, upgrade_tool, RockUSB)
- `make devices` — list connected devices (MODE / SN / LocationID / USB; no ChipID column)
- `make flash` — unified flash: `uf update.img`; auto `ul` loader when RockUSB is Maskrom; `IMAGE=` overrides firmware path

Multi-device selection SHALL use `SN=` matching table **SN** (adb SerialNo or RockUSB SerialNo for those modes). Host tooling MUST NOT accept **`CHIP_ID=`** as a device selector. macOS Docker builds SHALL auto-export `output/firmware/` to host after `make build-img`.

#### Scenario: devices table lists RockUSB Loader

- **WHEN** board is in RockUSB Loader mode and developer runs `make devices`
- **THEN** output includes a row with MODE `Loader`, SN matching device SerialNo, LocationID, and USB `0x2207:…`
- **AND** the table SHALL NOT include a ChipID column

#### Scenario: bootloader enters RockUSB from Android

- **WHEN** device runs Android with adb connected and developer runs `SN=… make reboot-loader`
- **THEN** subsequent `make devices` shows a RockUSB Loader row visible to `upgrade_tool ld`

#### Scenario: flash writes update.img

- **WHEN** RockUSB device is connected and `output/firmware/update.img` exists
- **THEN** `make flash` invokes `upgrade_tool uf` on that image (or `make flash IMAGE=/path/to.img`)

#### Scenario: multi-device requires SN

- **WHEN** more than one RockUSB device is connected and `SN` is not set
- **THEN** `make flash` fails with a message to run `make devices` and set `SN=`
