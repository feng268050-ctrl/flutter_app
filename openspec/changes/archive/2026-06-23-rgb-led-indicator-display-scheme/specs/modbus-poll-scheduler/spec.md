## ADDED Requirements

### Requirement: Laser Enable UI changes refresh GPIO indicators outside poll cycle

In addition to RGB LED updates at the end of each normal Modbus poll cycle, the application SHALL refresh GPIO indicator state when Laser Enable is successfully written from Quick Mode or Engineer Mode, without waiting for the next 100 ms poll tick.

The refresh MUST use the same `GpioLedHandler` logic and the same laser-enable visibility source as the poll-driven path.

#### Scenario: Laser Enable on between polls

- **WHEN** the operator enables Laser Enable and the Modbus write succeeds
- **AND** the next poll cycle has not yet completed
- **THEN** green and red LED states MUST reflect the new laser-enable and cached device status immediately

#### Scenario: Laser Enable off between polls

- **WHEN** the operator disables Laser Enable (End of Work or equivalent) and the Modbus write succeeds
- **THEN** green LED MUST turn off and red LED MUST follow laser-output / idle-blink rules on immediate refresh
