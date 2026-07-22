## MODIFIED Requirements

### Requirement: Dangerous operations policy via App facade

The App SHALL expose a dangerous-operations facade that laser-enable preflight, runtime interrupt, and warn-severity consumers consult (same allow-* / keepLaserOn rules as before). Warn presentation SHALL consult the facade for INFO vs WARN styling on bypassable codes. Turning a bypass OFF SHALL invoke the App laser re-evaluate entry point when wired (soft-fail if laser interrupt is not yet available).

#### Scenario: Toggle off invokes re-evaluate hook

- **WHEN** the operator turns Allow Work after Gas Alarm OFF
- **THEN** the App laser re-evaluate entry point is invoked
