## ADDED Requirements

### Requirement: HAL remains attribute and health source only for warns

HAL Modbus SHALL continue to expose decoded `alarm.*` attributes, optional `meta.alarm_code` / `meta.label`, change-only watches (including distinguishable reminder kinds), and read-health streams suitable as inputs to App / `cyber_alarm` C001-class UI. HAL MUST NOT implement warn dialog UI, episode persistence, resist-ack queues, or product alarm-code severity catalogs. Product warn presentation and historical logging remain `cyber_alarm` + App responsibilities (not HAL).

#### Scenario: Health stream without dialog

- **WHEN** continuous group health reports failure
- **THEN** HAL emits health suitable for App / `cyber_alarm` consumption
- **AND** HAL MUST NOT open a warn dialog

#### Scenario: Meta is annotation not policy owner

- **WHEN** config provides `meta.alarm_code` on `alarm.gun_comm`
- **THEN** Apps MAY join that code to a product catalog (via `cyber_alarm`) for presentation
- **AND** HAL MUST NOT require dialog copy fields in modbus config as the presentation system of record
