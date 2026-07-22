## ADDED Requirements

### Requirement: Advanced settings JSON may cache numeric thresholds

`/var/lib/hmi/advanced-settings.json` MAY store numeric threshold fields (zero offset, swing, powers, pressure, temperatures, recovery interval) in addition to AI/dangerous booleans. Missing numeric keys MUST soft-fail to documented defaults without wiping boolean keys.

#### Scenario: Numerics and booleans coexist

- **WHEN** the file contains both `keepLaserOnWhileAlarmed` and `laserStartPower`
- **THEN** both are loaded on warm-read
