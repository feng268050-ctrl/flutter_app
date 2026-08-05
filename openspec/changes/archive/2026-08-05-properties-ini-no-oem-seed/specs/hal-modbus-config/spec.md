## MODIFIED Requirements

### Requirement: Read health for comm fault (C001 input)

HAL SHALL expose aggregate continuous-poll read health suitable for controller↔HMI communication faults (C001-class). Config MAY define a sliding window (`window_size`, `failure_threshold`, default 5 / 3) and mode (`slide_window` | `immediate`) under `poll.health` in the product modbus asset. HAL SHALL record group-cycle outcomes into that window and emit **aggregate** `ModbusHealth` events only (not per-group rising/falling that would bypass the window). Recovery SHALL emit `ok: true` when the window is healthy again. HAL SHALL support a runtime mode override API (`applyHealthWindowMode`) so the App can apply `properties.ini` `control_card_comm_alarm_mode` (`slide_window` | `immediate`); empty/absent `properties.ini` key keeps the asset default. On-demand `readGroup` MUST NOT drive the C001 health stream. HAL MUST NOT own Warn dialog presentation.

#### Scenario: Truncated status keeps last-good

- **WHEN** a continuous group read is truncated or fails
- **THEN** HAL SHALL retain last-good decoded attribute values for that group, record a health failure, and MUST NOT invent register values

#### Scenario: Aggregate window gates C001 input

- **WHEN** `poll.health.mode` is `slide_window` with failure_threshold 3
- **AND** continuous poll records fewer than three failures in the window
- **THEN** aggregate health SHALL remain `ok: true` (no premature per-group `ok: false` emission for C001)

#### Scenario: properties.ini mode override

- **WHEN** the App calls `applyHealthWindowMode('immediate')` after loading `control_card_comm_alarm_mode`
- **THEN** the next continuous-poll failure SHALL make aggregate health unhealthy without waiting for the slide-window threshold
