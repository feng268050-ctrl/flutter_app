## MODIFIED Requirements

### Requirement: Config-driven GPIO and Modbus
`hal/gpio` and `hal/modbus` SHALL be constructed from a versioned config file (or parsed config object). Product indicator LEDs SHALL be expressed as a Status LED bank (named channels) in gpio config, with optional migration from named lines. Line hardware addressing SHALL support dual Linux backends (gpiod character device and `gpio_innohi` sysfs) as specified by `hal-gpio-gpiod-backend`. Modbus register maps SHALL be expressed as named attributes in modbus config (including bitfield alarms as human-readable attribute ids). Product Apps MUST NOT hard-code ynh960 pin numbers or Modbus addresses/bitmasks as the long-term pattern after cutover. GPIO and Modbus SHALL remain separate top-level modules (not under `hal/io`). **Product** `gpio.json` / `modbus.json` catalogs SHALL be owned by the product App (or pack) and referenced from `BoardProfile.configs`; they MUST NOT be shipped under `packages/cyber_hal/boards/<board_id>/` as the sole product map (the same motherboard may serve multiple products).

#### Scenario: Demo LEDs via gpio config
- **WHEN** the Demo toggles panel LEDs after gpio cutover
- **THEN** it SHALL open the Status LED bank / channels by config id (e.g. device `chassis_rgb` channel `red`, or migrated `led_red`) through `hal/gpio` and SHALL NOT embed `GPIO_5` paths in App Dart constants

#### Scenario: Demo Modbus via attribute ids
- **WHEN** the Demo reads a Modbus-backed attribute after cutover
- **THEN** it SHALL use the attribute id from modbus config through `hal/modbus` and SHALL NOT embed raw register addresses in App UI code as the long-term pattern
