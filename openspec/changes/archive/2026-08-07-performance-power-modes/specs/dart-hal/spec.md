## MODIFIED Requirements

### Requirement: Industry-style public API

Portable HAL public types SHALL use system-service vocabulary including at least: `Capabilities` / `BoardInfo`; under `hal/network`: network device/role APIs plus `ProxySettings` and **`SshDebug`** (LAN SSH); under `hal/output`: **display** (`Backlight`, `AutoSleep`, **`Orientation`**), **sound** (`Volume`, `ButtonFeedback`), and **load / thermal profile** (`LoadProfile` / equivalent with tokens `performance` / `balanced`); under `hal/input`: keyboard and mouse; `hal/gpio`; `hal/modbus`; under **`hal/usb_otg`**: OTG mode (`debug`/`mtp`/`host`) without attach/detach product APIs; `BluetoothManager` / related; `TimeService`; `SysInfo`. Implementation types (`Linux*`, `*Backend`) MUST NOT be required by product App code. Temporary `*Controller` wrappers MAY exist during migration. The HAL package MUST NOT expose a top-level `hal/http` module. Long-term public layout SHALL use grouped packages where decided (`hal/output`, `hal/input`, `hal/network`) plus top-level `hal/usb_otg`, `hal/gpio` / `hal/modbus` (not under an `io`/`media` umbrella). A long-term **`hal/debug`** barrel for SSH+USB MUST NOT remain. URL probe UI stays in the App. System proxy policy SHALL live under `hal/network/proxy`. Panel orientation SHALL live under `hal/output/display` (not a top-level `hal/orientation` entrypoint). Load / thermal profile SHALL live under `hal/output` (not under App-only stores). The package MUST NOT expose a top-level `hal/display` / `package:cyber_hal/display.dart` entrypoint.

#### Scenario: New integration uses network module

- **WHEN** a new Settings page integrates Wi‑Fi through HAL
- **THEN** documented imports SHALL be under `package:cyber_hal/network` (e.g. wifi subpackage), not a new portable type whose primary name is `WifiController`

#### Scenario: Orientation under output display

- **WHEN** a product App sets panel orientation
- **THEN** it SHALL import `package:cyber_hal/output/display/orientation.dart` (or `output/display.dart`) and MUST NOT use a top-level `hal/orientation` module

#### Scenario: LAN SSH under network

- **WHEN** a product App toggles LAN SSH debug
- **THEN** it SHALL import `SshDebug` from `package:cyber_hal/network` (or `network/ssh_debug.dart`) and MUST NOT require `hal/debug`

#### Scenario: Load profile under output

- **WHEN** a product App reads or sets performance / balanced mode
- **THEN** it SHALL use the HAL output load-profile API (Linux helper + `power.conf`, stub in-memory)
- **AND** MUST NOT shell out to sysfs governors directly from App widgets

## ADDED Requirements

### Requirement: Load / thermal profile API

The HAL SHALL expose get/set for load / thermal profile with values `performance` and `balanced`. On Linux, `setMode` SHALL invoke the board helper (persist + apply clock/cpuidle policy). `getMode` SHALL read `/var/lib/hal/power.conf` (missing/invalid → `performance`). The stub backend SHALL keep an in-memory mode for host tests and the emulator. Invoking set/get MUST NOT require a Rust `hald`.

#### Scenario: Linux setMode persists and applies

- **WHEN** the App calls setMode(`balanced`) on a Linux backend
- **THEN** `/var/lib/hal/power.conf` contains `mode=balanced`
- **AND** the board helper is invoked to apply the balanced hardware profile

#### Scenario: Stub round-trip

- **WHEN** host tests use the stub load-profile backend and set `performance` then `balanced`
- **THEN** subsequent getMode returns `balanced` without touching real sysfs
