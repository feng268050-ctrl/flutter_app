## ADDED Requirements

### Requirement: Alarm codes use letter plus three decimal digits

Every production alarm code defined in `AlarmCodeConstants` and `AlarmCodeEnums` SHALL use exactly one uppercase letter prefix followed by exactly three decimal digits (e.g. `H001`, `E010`, `C002`). Codes MUST NOT use four or more digits after the letter prefix.

#### Scenario: H-series codes ten through thirty-four use three digits

- **WHEN** the app assigns an H-series alarm for the 10th through 34th handheld-head fault slot
- **THEN** the code SHALL be `H010` through `H034` respectively
- **AND** MUST NOT use `H0010` through `H0034`

#### Scenario: Legacy four-digit H codes are not recognized

- **WHEN** `AlarmCodeEnums.findByCode` is called with a legacy four-digit H code such as `H0022`
- **THEN** the method SHALL return `null`
- **AND** demo alarm trigger (`make alarm CODE=…`) SHALL NOT show a dialog for that code

### Requirement: App does not migrate or auto-clear legacy warn_table alarm codes

The app MUST NOT add Room migrations, startup jobs, or background tasks to rewrite or delete `warn_table` rows as part of this rename. Legacy four-digit H codes (`H0010`–`H0034`) in existing rows are cleared **manually** by the operator (e.g. alarm list clear in engineer UI or adb), not by application code.

#### Scenario: No automatic warn_table cleanup on startup

- **WHEN** the application starts and `warn_table` still contains rows with `code = 'H0022'`
- **THEN** the app SHALL NOT delete or UPDATE those rows automatically
- **AND** new laser-communication warn episodes SHALL insert rows with `code = 'H022'`

#### Scenario: New episodes use normalized codes only

- **WHEN** a Modbus-derived serious warn is created for protective lens overtemperature (formerly H0010)
- **THEN** `warn_table` and `WarnDialogVo.errorCode` SHALL use `H010`
