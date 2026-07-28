## ADDED Requirements

### Requirement: sim board_id does not imply Stub backends

`resolveHalBackend` SHALL select Stub backends only when `HAL_BACKEND` is explicitly `stub`. The board id `sim` alone MUST resolve to Linux backends so QEMU/guest profiles can use Linux HAL modules.

#### Scenario: sim board uses Linux by default

- **WHEN** `resolveHalBackend(boardId: 'sim')` is called with `HAL_BACKEND` unset or empty
- **THEN** the result SHALL be Linux (not Stub)

#### Scenario: Explicit stub env

- **WHEN** `HAL_BACKEND=stub` is set
- **THEN** `resolveHalBackend` SHALL return Stub regardless of board id

### Requirement: Package sim profile matches guest contract

`packages/cyber_hal/boards/sim.json` SHALL be upgraded to declare guest-oriented capabilities and `net_roles` for product ethernet and wifi (aligned with OEM sim board profile). It MUST omit `usbOtg`. It remains a package example/fixture; product gpio/modbus authority stays in the App.

#### Scenario: sim.json has product net roles

- **WHEN** loading `packages/cyber_hal/boards/sim.json`
- **THEN** `net_roles` SHALL include `ethernet.primary` and `wifi.station` and capabilities SHALL omit `usbOtg`
