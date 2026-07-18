## ADDED Requirements

### Requirement: Modbus config schema
`hal/modbus` SHALL load a versioned config document (JSON preferred) that declares at least: `version`, `transport` (RTU device path, baud, framing, `unit_id`, timeout), and an `attributes[]` catalog. Each attribute SHALL have a stable string `id`, `access` (`r` / `w` / `rw`), a `register` binding (`space`, `address`, `count`), and a `decode` description. The config MAY include a top-level `capabilities` object (e.g. which function codes / spaces are allowed).

#### Scenario: Transport for ynh960 welder link
- **WHEN** loading the shipped ynh960 modbus config
- **THEN** transport SHALL open the product UART (e.g. `/dev/ttyS5` at the product baud) via `modbus_client` (or documented equivalent)

### Requirement: Attribute API over raw addresses
Product Apps SHALL read/write logical attributes by `id`. HAL SHALL translate attribute ids to register operations and decode/encode values. An optional raw register API MAY exist for engineering/debug only and MUST NOT be required for Demo product paths after cutover.

#### Scenario: Firmware version attribute
- **WHEN** the App calls `readAttribute("device.firmware_version")` with a config that maps that id to holding `0x0002`
- **THEN** HAL SHALL perform the corresponding Modbus read and return a decoded value without the App supplying the address

#### Scenario: Unknown attribute id
- **WHEN** the App requests an attribute id absent from config
- **THEN** HAL SHALL return a structured not-found error and MUST NOT invent a register address

### Requirement: Register maps live in config
Numeric Modbus addresses used by product UIs SHALL live in the modbus config (or an explicit product overlay config), not as long-lived Dart `static const` maps inside the App after cutover. Config `version` SHALL allow golden tests against known lws-ui / Demo register sets.

#### Scenario: Temperature map migration
- **WHEN** migrating gun-motor temperature from App constants
- **THEN** the attribute (e.g. `alarm.gun_motor_temp` → `0x0061`) SHALL appear in modbus config and App code SHALL reference the attribute id
