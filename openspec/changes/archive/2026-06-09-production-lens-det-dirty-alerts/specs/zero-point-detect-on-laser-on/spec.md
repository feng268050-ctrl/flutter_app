## ADDED Requirements

### Requirement: Production zero-point offset may set post-laser-stop alert pending

After aggregating valid zero-point samples, when offsets exceed position tolerance in production weld scope, the App MAY still apply incremental Modbus 0090H correction per existing requirements, but SHALL additionally set a pending zero-point offset user alert to be shown after laser stops, as specified in `production-zero-point-offset-alerts`.

#### Scenario: Auto write and alert pending are not mutually exclusive

- **WHEN** a zero-point task applies incremental correction to 0090H
- **AND** offsets were outside tolerance
- **THEN** Modbus write behavior SHALL follow existing clamp and write rules
- **AND** pending zero-point offset alert MAY still be set for display after laser OFF
