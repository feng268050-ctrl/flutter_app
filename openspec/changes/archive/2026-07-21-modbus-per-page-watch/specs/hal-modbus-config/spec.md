## ADDED Requirements

### Requirement: Multiple watch subscribers with distinct id filters
`hal/modbus` SHALL allow multiple concurrent `watchAttributes` subscriptions on one HAL instance. Each subscription MAY supply its own `ids` filter. Emissions to a subscriber SHALL include only changes (and reminders) for attributes in that subscriber’s filter (or all changing attributes when `ids` is omitted, per existing watch semantics). Starting or canceling one subscription MUST NOT stop continuous polling or other subscribers. Product Apps that show multiple live Modbus surfaces SHOULD use per-subscriber `ids` rather than a single App-owned undifferentiating fan-out of all watched attributes.

#### Scenario: Two subscribers different ids
- **WHEN** continuous polling is active
- **AND** subscriber A watches `telemetry.gun_motor_temp` only
- **AND** subscriber B watches `alarm.gun_comm` only
- **AND** only the motor temperature decoded value changes in a cycle
- **THEN** subscriber A SHALL receive that change
- **AND** subscriber B MUST NOT receive an emission for that cycle (unless a reminder or other B-filtered change is due)

#### Scenario: Cancel one watch leaves poll and peers
- **WHEN** two watch subscriptions are active
- **AND** the App cancels one subscription
- **THEN** continuous polling SHALL continue
- **AND** the remaining subscription SHALL keep receiving filtered updates
