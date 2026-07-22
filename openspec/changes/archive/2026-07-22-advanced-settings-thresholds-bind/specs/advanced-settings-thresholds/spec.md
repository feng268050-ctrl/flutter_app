## ADDED Requirements

### Requirement: Thresholds watch and write Modbus attributes

- Prefer `readGroup('settings')` to prime UI (`settings` is on_demand; continuous poll does not refresh it). Fall back to per-id `readAttribute`.
- Per-slider release: `writeAttribute` with App codec (lws-ui ×10 / +75 / ×100); temps use catalog scale via HAL.
- Soft-fail when the port is unavailable (retain last UI / cache value).

#### Scenario: Commit laser start power

- **WHEN** the operator releases the Laser Starting Power slider at 25
- **THEN** the App writes the attribute `setting.laser_start_power` with the wire encoding matching product scale
- **AND** the value is cached under advanced-settings JSON

#### Scenario: Soft-fail offline

- **WHEN** Modbus write fails
- **THEN** the Settings UI remains usable with the last local value
- **AND** the App does not crash

### Requirement: Local numeric cache in advanced-settings.json

Numeric thresholds SHALL be optionally persisted as keys in `/var/lib/hmi/advanced-settings.json` alongside AI/dangerous booleans. On cold start, cache seeds UI before Modbus watch updates arrive.

#### Scenario: Restart retains cache

- **WHEN** the operator sets motor temp threshold to 65 and the process restarts before Modbus responds
- **THEN** the UI shows 65 from cache until a successful attribute update arrives
