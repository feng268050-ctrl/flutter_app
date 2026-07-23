## MODIFIED Requirements

### Requirement: Industry-style public API

Portable HAL public types SHALL use system-service vocabulary including at least: `Capabilities` / `BoardInfo`; under `hal/network`: network device/role APIs plus `ProxySettings`; under `hal/output`: **display** (`Backlight`, `AutoSleep`) and **sound** (`Volume`, `ButtonFeedback`); under `hal/input`: keyboard and mouse; `hal/gpio`; `hal/modbus`; under `hal/debug`: SSH and USB debug; `BluetoothManager` / related; `TimeService`; `SysInfo`. Implementation types (`Linux*`, `*Backend`) MUST NOT be required by product App code. Temporary `*Controller` wrappers MAY exist during migration. The HAL package MUST NOT expose a top-level `hal/http` module or a `DisplayOrientation` / `hal/orientation` API. Long-term public layout SHALL use grouped packages where decided (`hal/output`, `hal/input`, `hal/network`, `hal/debug`) and top-level `hal/gpio` / `hal/modbus` (not under an `io`/`media` umbrella). URL probe UI stays in the App. System proxy policy SHALL live under `hal/network/proxy`. Panel orientation is launch/board-fixed (D19). Embedder/stack detection (`DisplayStack`) SHALL live under `hal/sys_info`. The package MUST NOT expose a top-level `hal/display` / `package:cyber_hal/display.dart` entrypoint.

#### Scenario: New integration uses network module

- **WHEN** a new Settings page integrates Wi‑Fi through HAL
- **THEN** documented imports SHALL be under `package:cyber_hal/network` (e.g. wifi subpackage), not a new portable type whose primary name is `WifiController`

### Requirement: Domain package grouping

Related capabilities SHALL be grouped under domain packages with optional sub-imports where naming fits: `hal/network` {ethernet, wifi, proxy}; `hal/output` {**display** {backlight, auto-sleep}, **sound** {volume, button-feedback}}; `hal/input` {keyboard, mouse}; `hal/debug` {ssh, usb}. `hal/gpio` and `hal/modbus` SHALL remain separate top-level modules. Apps MUST be able to import a single subpackage without pulling unused siblings.

#### Scenario: Volume without backlight

- **WHEN** a product App needs only volume
- **THEN** it SHALL be able to import `hal/output/sound/volume` (or `hal/output/sound`) without importing backlight / auto-sleep

#### Scenario: AutoSleep without volume

- **WHEN** a product App needs only AutoSleep
- **THEN** it SHALL be able to import `hal/output/display/auto_sleep` (or `hal/output/display`) without importing volume / button-feedback

#### Scenario: Gpio without modbus

- **WHEN** a product App needs only gpio lines
- **THEN** it SHALL import `hal/gpio` and MUST NOT be required to depend on `hal/modbus`

## ADDED Requirements

### Requirement: DisplayStack under sys_info

Embedder/stack detection (`DisplayStack`, probe helpers, and mouse-setting availability gates derived from the stack) SHALL be exported from `package:cyber_hal/sys_info.dart`. Product Apps MUST NOT import a top-level `package:cyber_hal/display.dart`.

#### Scenario: App resolves stack via sys_info

- **WHEN** Settings needs the active display stack label or mouse-knob gates
- **THEN** it SHALL obtain `DisplayStack` through `sys_info` (or `BoardBindings.displayStack`) without importing `cyber_hal/display.dart`
