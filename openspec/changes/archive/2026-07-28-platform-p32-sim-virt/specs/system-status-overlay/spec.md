## ADDED Requirements

### Requirement: GPIO LED status overlay host (emulator)

The Flutter HMI App SHALL provide a global GPIO LED status overlay that shows red, yellow, and green LED lamps derived from the product GPIO LED controller. On `board_id == sim` the overlay SHALL be shown automatically (no settings toggle). On real boards (e.g. ynh960) it SHALL NOT be shown. Presentation SHALL be lights-only (no status text), vertically arranged near the top-left without colliding with the system status overlay, and MUST allow pointer events to pass through to underlying controls.

Blink and level changes SHALL follow the HAL: after an initial GPIO level read, the overlay updates when `GpioHal` notifies level listeners on each successful `set` (the overlay MUST NOT run its own blink timer).

#### Scenario: Overlay does not block taps

- **WHEN** the GPIO LED overlay is visible
- **AND** the user taps a control under or beside the overlay region
- **THEN** the underlying control still receives the tap

#### Scenario: Auto on sim only

- **WHEN** the composed board profile has `board_id` `sim`
- **THEN** the GPIO LED overlay SHALL be visible without a misc-settings switch
- **WHEN** `board_id` is a real board id such as `ynh960`
- **THEN** the overlay SHALL NOT be shown

#### Scenario: LED states reflected via HAL listener

- **WHEN** the overlay is active and a GPIO LED line logical level changes through HAL `set` (including blink toggles)
- **THEN** the overlay presentation SHALL update to match those levels
