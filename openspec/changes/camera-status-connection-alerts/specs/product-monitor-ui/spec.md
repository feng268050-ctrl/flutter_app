## MODIFIED Requirements

### Requirement: Monitor presents active alarms from HAL attributes

The Monitor screen SHALL list active alarms from the product warn/alarm façade backed by `cyber_alarm` episodes. That list SHALL include:

1. Modbus-backed codes derived from product `alarm.*` boolean attributes that carry `meta.alarm_code` (via the Modbus `AlarmSignalSource` adapter), and
2. Non-Modbus codes that share the same coordinator (at least camera communication **C002** when IP-camera health is unhealthy).

An alarm SHALL appear when its episode fault is active, showing at least the alarm code and label (catalog or attribute meta). Live Modbus updates MUST use `ModbusHal.watchAttributes` (or AppServices equivalent) and MUST NOT run a Dart `Timer` that loops `readAttribute` for continuous status/data groups. Camera C002 MUST NOT require a Modbus attribute bit.

#### Scenario: Active alarm appears in list

- **WHEN** an `alarm.*` attribute with an alarm code becomes true while Monitor is subscribed
- **THEN** the Monitor alarm list shows that alarm’s code and label

#### Scenario: Cleared alarm leaves list

- **WHEN** a previously true alarm attribute becomes false
- **THEN** that alarm is no longer shown as active in the list

#### Scenario: App does not poll Modbus itself

- **WHEN** Monitor needs live temperatures and alarms
- **THEN** it subscribes via HAL watch APIs and does not start a Timer-based `readAttribute` poll loop for those continuous groups

#### Scenario: Camera C002 appears without Modbus bit

- **WHEN** IP-camera health is unhealthy and a C002 episode is active
- **THEN** the Monitor active-alarm list SHALL show code **C002** with the catalog label
- **AND** MUST NOT require a Modbus `alarm.*` attribute for that row
