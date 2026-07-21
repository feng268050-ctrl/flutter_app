## ADDED Requirements

### Requirement: Monitor Alarm Logs use historical repository

The Monitor Alarm Information “Alarm Logs” surface SHALL display App-persisted historical alarm rows from the store implementing the `cyber_alarm` alarm log repository port (not only the live true-bit list). Clear SHALL invoke that repository clear API. Live active alarms MAY still be shown as a separate live section or badge driven by attribute watches, but Clear MUST NOT be implemented as a stub snackbar once this capability lands.

#### Scenario: History visible on Monitor

- **WHEN** at least one historical row exists and the operator opens Alarm Information
- **THEN** Alarm Logs shows that row’s code and time (and label when available)

#### Scenario: Clear removes history UI

- **WHEN** the operator activates Clear on Alarm Logs
- **THEN** historical rows disappear from the Logs list
- **AND** the App MUST NOT claim “coming soon”

### Requirement: Monitor remains a consumer of warn APIs

Monitor Alarm Information SHALL subscribe to HAL (or App façades) for lights/temps/active bits as today, and SHALL consume historical log streams/APIs from the App façade over `cyber_alarm`. Monitor MUST NOT implement warn episode policy or open a second warn dialog stack local to the tab.

#### Scenario: No tab-local episode controller

- **WHEN** Alarm Information is open and a Modbus alarm rises
- **THEN** modal warn presentation is performed by the App-wide presentation host backed by `cyber_alarm`
- **AND** the Alarm Information tab does not create a parallel episode state machine
