## MODIFIED Requirements

### Requirement: Modbus config schema
`hal/modbus` SHALL load a versioned config document (JSON preferred) that declares at least: `version`, `transport` (RTU device path, baud, framing, `unit_id`, timeout), and an `attributes[]` catalog. Config SHALL support a `groups` object describing contiguous register segments and a `poll` object for scheduler defaults. Each attribute SHALL have a stable string `id`, `access` (`r` / `w` / `rw`), a `register` binding (`space`, `address`, `count`), and a `decode` description. Attributes MAY reference a `group` id. The config MAY include a top-level `capabilities` object (e.g. which function codes / spaces are allowed).

Product `transport` SHALL support an optional `device_by_board` object mapping `board_id` → RTU device path. The shipping App `modbus.json` SHALL list exactly these keys when present: **`ynh960`**, **`ek3562`**, **`sim`** (MUST NOT require per-SKU forks of the attribute catalog). When resolving the open path for a given `board_id`: (1) if OEM helper `modbus_rtu_device` is set and non-empty, use it; else (2) if `device_by_board` contains that `board_id`, use it; else (3) use `transport.device`. Shipping OEM board profiles MUST NOT be the authoritative source of the product Modbus UART node.

#### Scenario: Transport for product welder link
- **WHEN** loading the product App’s modbus config for board `ynh960`
- **THEN** transport SHALL open `/dev/ttyS5` at the product baud via the package RTU transport (Posix or documented equivalent)

#### Scenario: ek3562 uses device_by_board
- **WHEN** loading Modbus for board `ek3562` with product `device_by_board`
- **THEN** transport SHALL open `/dev/ttyS4` (not `/dev/ttyS5`)

#### Scenario: sim uses device_by_board
- **WHEN** loading Modbus for board `sim` with product `device_by_board`
- **THEN** transport SHALL open `/dev/ttyUSB0`

#### Scenario: Unknown board falls back to transport.device
- **WHEN** `board_id` is absent from `device_by_board` (e.g. `ynh961`) and no OEM device helper is set
- **THEN** transport SHALL open `transport.device` (product default `/dev/ttyS5`)

#### Scenario: OEM helper wins when set
- **WHEN** OEM helpers include `modbus_rtu_device` and `device_by_board` also maps the board
- **THEN** `ModbusHal.fromProfile` SHALL open the OEM helper path

#### Scenario: Poll interval from config
- **WHEN** `poll.interval_ms` is omitted
- **THEN** HAL SHALL default to **100** milliseconds
- **WHEN** `poll.interval_ms` is set to another positive value
- **THEN** continuous group polling SHALL use that interval
