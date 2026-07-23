## MODIFIED Requirements

### Requirement: Production zero-point offset sets immediate user alert

After aggregating valid zero-point samples, when offsets exceed position tolerance in production weld scope, the App MAY still apply incremental Modbus 0090H correction per existing requirements, and SHALL set and show the zero-point offset user alert **immediately** as specified in `production-zero-point-offset-alerts` (alarm code **H034**).

#### Scenario: Auto write and alert are not mutually exclusive

- **WHEN** a zero-point task applies incremental correction to 0090H
- **AND** offsets were outside tolerance
- **THEN** Modbus write behavior SHALL follow existing clamp and write rules
- **AND** H034 warn log and dialog MAY be shown immediately without waiting for laser OFF
