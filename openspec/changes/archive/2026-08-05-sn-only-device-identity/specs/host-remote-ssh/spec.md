## MODIFIED Requirements

### Requirement: make devices lists registered SSH devices

**`make devices`** SHALL include registry rows with **`MODE=SSH`**, **`IP`** set to the registered IP, **`IFACE`** as `-`, and **`SN`** from the cached or live-probed board identity when known. The table MUST NOT include a **ChipID** column for these rows.

#### Scenario: Registered device appears

- **WHEN** at least one IP is registered via `make connect`
- **THEN** `make devices` shows a row with `MODE` SSH and `IP` equal to that address
