# boot-self-check Specification

## ADDED Requirements

### Requirement: Boot self-check synchronous Modbus reads use serial command gate

Synchronous Modbus input register reads performed during boot self-check (including `readDeviceStatusBlocking` and `readFullModbusSnapshotBlocking`) SHALL pass through the same `ModbusSerialGate` used at runtime so that spacing between the status read and data read in a full snapshot, and between snapshot reads and any concurrent serial traffic, follows `COMMAND_INTERVAL_MS`.

#### Scenario: Full snapshot respects command interval between status and data

- **WHEN** boot self-check performs a full Modbus snapshot (device status then device data)
- **THEN** the app SHALL enforce at least `COMMAND_INTERVAL_MS` between the end of the status read and the start of the data read
- **AND** SHALL complete both reads before evaluating Modbus-backed check items

#### Scenario: Self-check does not bypass gate on production hardware

- **WHEN** boot self-check runs on production hardware with Modbus RTU connected
- **THEN** synchronous Modbus reads SHALL NOT bypass the serial command gate
