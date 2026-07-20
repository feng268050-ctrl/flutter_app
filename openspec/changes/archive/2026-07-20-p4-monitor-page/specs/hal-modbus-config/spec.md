## ADDED Requirements

### Requirement: Product Monitor consumes catalog attribute ids

Product Monitor UI paths for Alarm Information temperatures and boolean alarms SHALL reference stable attribute ids from the product App modbus config asset (e.g. `telemetry.gun_motor_temp`, `alarm.gun_motor_over_temp`, `alarm.gun_comm`). Those paths MUST NOT hard-code numeric Modbus addresses or bit indices in Dart UI/application code after this capability lands. Adding a missing Monitor field SHALL be done by extending the config catalog (and optionally meta), not by embedding addresses in the widget tree.

#### Scenario: Temperature rows use attribute ids

- **WHEN** Monitor displays Motor temperature
- **THEN** the application layer requests or watches `telemetry.gun_motor_temp` (or an equivalent catalog id) and MUST NOT embed `0x0061` in Monitor UI code

#### Scenario: Alarm list uses attribute ids and meta

- **WHEN** Monitor shows an active gun-communication alarm
- **THEN** it uses the `alarm.gun_comm` attribute (and config meta for code/label when present) rather than parsing a raw status register bitmask in the UI
