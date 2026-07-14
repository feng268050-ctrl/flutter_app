## ADDED Requirements

### Requirement: Home screen lists five device-info rows

The P2 home (or primary demo) screen SHALL display exactly these rows as simple `label: value` text (English labels matching lws-ui Device Information naming):

1. Device SN
2. Gunhead SN
3. Firmware Version
4. Laser Version
5. Wire Feeder Version

A missing or failed value SHALL display exactly `-`.

#### Scenario: All rows visible

- **WHEN** the user views the P2 demo home after first frame
- **THEN** all five labels are visible with a value string (possibly `-`)

#### Scenario: Device SN from iSerial identity

- **WHEN** board iSerial / `read-serial` identity is available
- **THEN** Device SN shows that serial string and is NOT read from Modbus

#### Scenario: Device SN unavailable

- **WHEN** iSerial / `read-serial` identity cannot be obtained
- **THEN** Device SN displays `-`

### Requirement: Home screen lists four Alarm Information temperatures

The P2 demo SHALL also list the four welding-gun sensor temperatures from lws-ui Monitor → **Alarm Information**, as simple `label: value` rows:

1. Motor Temperature
2. Motor Driver Temperature
3. Protective Mirror Temperature
4. Collimator Temperature

Values SHALL use lws-ui scaling (signed register ÷ 10, one decimal, `°C`). Unconnected / error readings (`raw <= -999`) and Modbus failures SHALL display exactly `-`.

#### Scenario: Alarm temperature rows visible

- **WHEN** the user views the P2 demo home after first frame
- **THEN** all four Alarm Information temperature labels are visible with a value string (possibly `-`)

### Requirement: Three exclusive LED mode rows

The demo SHALL provide three control rows labeled for Red, Yellow, and Green. Each row SHALL offer three mutually exclusive choices: **Steady**, **Blink**, and **Off**. Selecting one choice in a row MUST deselect the other two in that row. Rows MUST NOT force a single global mode across colors.

#### Scenario: Exclusive selection within a row

- **WHEN** the user selects Blink on the Red row while Steady was selected
- **THEN** Red is Blink (not Steady), and Yellow/Green selections are unchanged

#### Scenario: Initial mode is Off

- **WHEN** the demo screen first appears
- **THEN** each LED row’s selected mode is Off

### Requirement: UI wires to Modbus and GPIO adapters

Tapping Steady / Blink / Off SHALL invoke the Linux GPIO RGB LED API for that color. Modbus-backed rows SHALL refresh from the Linux Modbus RTU client (on appear and/or a simple refresh), without blocking first paint on success.

#### Scenario: LED control invokes GPIO

- **WHEN** the user selects Steady on the Green row
- **THEN** the GPIO LED controller is asked to set Green to Steady

#### Scenario: Modbus fields refresh without crash

- **WHEN** Modbus is offline
- **THEN** Gunhead SN, Firmware Version, Laser Version, and Wire Feeder Version show `-` and the LED controls remain usable
