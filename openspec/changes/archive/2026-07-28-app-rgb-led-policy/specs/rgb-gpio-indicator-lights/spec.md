## ADDED Requirements

### Requirement: Chassis RGB indicators follow operator semantics

The product App SHALL drive side-panel red, yellow, and green GPIO indicators as three independent operator concepts with a **2 s** blink period (**1 s on / 1 s off**) for red standby and yellow alarm:

| LED | Role | Off | Blink | Steady |
|-----|------|-----|-------|--------|
| Red | Laser | No device sample yet, or laser communication alarm (H022) | Online standby (not emitting) | Emitting (`machine.laser_on`) |
| Yellow | Alarm | No yellow-severity active coded alarm | At least one yellow-severity active coded alarm | *(not used)* |
| Green | Ready | Not ready | *(not used)* | Ready per mode interlocks |

GPIO pin labels and Steady/Blink/Off plumbing remain under `linux-gpio-rgb-led` / product `gpio.json`.

#### Scenario: Standby red blinks

- **WHEN** Modbus status has been primed, `machine.laser_on` is false, and `alarm.laser_comm` is false
- **THEN** the red indicator MUST blink with a 2 s period
- **AND** MUST NOT remain steady on

#### Scenario: Laser offline red off

- **WHEN** `alarm.laser_comm` is true
- **THEN** the red indicator MUST be off
- **AND** MUST NOT blink standby

### Requirement: Red LED indicates emit, standby, and offline

The App SHALL compute red mode as:

1. Off when not yet primed with a device status sample.
2. Steady on when `machine.laser_on` is true.
3. Off when `alarm.laser_comm` is true.
4. Otherwise blink (online standby).

#### Scenario: Emitting — red steady

- **WHEN** `machine.laser_on` is true
- **THEN** red MUST be steady on
- **AND** any red blink MUST be cancelled

### Requirement: Yellow LED indicates yellow-severity coded alarms

The App SHALL blink yellow when any **fault-active** coded alarm is yellow-severity for hardware indicators:

- Codes other than C002 / L001 / W001 / W002 (including **A001** and H/E/…): yellow while fault-active, even if the warn dialog is INFO under dangerous-operations bypass.
- C002 / L001 / W001 / W002: yellow only when not demoted to INFO by the matching allow-* setting.

Yellow MUST be off when no such code is active. Yellow MUST NOT use steady-on.

#### Scenario: Non-bypassable code blinks yellow

- **WHEN** a fault-active episode for `H022` (or other non-C002/L001/W* code) is present
- **THEN** yellow MUST blink

#### Scenario: A001 stays yellow under gas bypass

- **WHEN** A001 is fault-active
- **AND** `allowWorkAfterGasAlarm` is true
- **THEN** yellow MUST still blink

#### Scenario: Bypassed camera alone does not blink yellow

- **WHEN** only C002 is fault-active
- **AND** `allowWorkAfterCameraAlarm` is true
- **THEN** yellow MUST be off

### Requirement: Green LED indicates ready to emit

Green MUST be off when not primed, when `machine.laser_on` is true, when the key switch is off, or when ready is blocked by coded alarms per `advanced-settings-dangerous-operations` allow-* rules. **`keepLaserOnWhileAlarmed` MUST NOT clear the green ready block.**

#### Standard modes (not CNC Cut)

Green MUST be steady on only when Laser Enable is active in the work-screen session holder, `machine.safety_ground_lock` is locked/conducting, key switch is on, laser is not emitting, and ready is not alarm-blocked.

#### CNC Cut

When the active work model wire value is CNC Cut (`ProcessType.cncCutting.wireValue` = 5), green MUST be steady on only when `machine.cnc_connected` is true, key switch is on, laser is not emitting, and ready is not alarm-blocked. CNC ready MUST NOT require Laser Enable or safety ground lock.

#### Scenario: Standard ready — green steady

- **WHEN** Laser Enable session is active, safety ground lock is locked, key is on, laser is off, and ready is not blocked
- **THEN** green MUST be steady on

#### Scenario: CNC ready ignores enable and clamp

- **WHEN** work model is CNC Cut, CNC is connected, key is on, laser is off, and ready is not blocked
- **THEN** green MUST be steady on even if Laser Enable is inactive and safety ground is unlocked

#### Scenario: keepLaserOn does not restore green

- **WHEN** a non-bypassable coded alarm blocks ready
- **AND** `keepLaserOnWhileAlarmed` is true
- **THEN** green MUST remain off

### Requirement: Production policy is centralized and event-driven

Desired modes MUST be computed in one App policy driver (e.g. `RgbLedPolicyDriver` via `RgbLedDecision`) and applied through the GPIO LED controller. Work screens MUST NOT write red/yellow/green modes directly for production behavior.

The driver SHALL refresh on Modbus changes for laser/key/comm/clamp/CNC attributes, warn-alarm monitor updates, dangerous-operations snapshot changes, and Laser Enable holder changes. Concurrent refreshes MUST coalesce (pending flag) so updates are not dropped while GPIO applies.

#### Scenario: Warn edge refreshes yellow without waiting for unrelated UI

- **WHEN** a coded alarm becomes fault-active
- **THEN** the policy driver MUST refresh LED modes from the active episode set

#### Scenario: Laser Enable toggle refreshes green immediately

- **WHEN** the operator successfully toggles Laser Enable on Quick or Engineer Mode
- **THEN** green (and other colors) MUST refresh from the updated session holder without waiting for the next Modbus poll of `control.laser_enable`

### Requirement: Policy start forces Off then applies decisions

Before the first policy-driven mode apply after App warn-alarm start, the App SHALL force all three LED colors to Off (hardware rewrite), then prime device inputs and apply the computed modes.

#### Scenario: Boot leftover HIGH cleared

- **WHEN** production LED policy starts
- **THEN** red, yellow, and green MUST be driven Off once with force
- **AND** afterwards the computed standby/alarm/ready modes MAY turn lamps on or blink

### Requirement: LED Settings suppresses policy and resets Off

While the RGB LED Settings page is open, production policy MUST NOT overwrite manual Steady/Blink/Off. On enter, the page SHALL force all three colors Off and show Off selected. On leave, policy MUST resume and refresh.

#### Scenario: Enter settings clears lamps

- **WHEN** the operator opens RGB LED Settings
- **THEN** production policy is suppressed
- **AND** all three colors are forced Off before manual test controls apply

### Requirement: Same-mode apply does not restart blink

Re-applying Blink (or any identical mode) after a successful apply MUST NOT cancel and restart the blink phase, so Modbus or alarm refresh at sub-second cadence cannot make blink look steady.

#### Scenario: Poll refresh preserves blink phase

- **WHEN** red is already blinking standby
- **AND** policy refresh computes blink again
- **THEN** the HAL blink timer MUST continue without forcing the lamp steady high
