## ADDED Requirements

### Requirement: Same-mode Blink does not restart flash phase

When a GPIO line is already in Blink mode, a subsequent `setMode(Blink)` without force MUST be a no-op: it MUST NOT cancel the blink timer or force the line logical high. The first transition into Blink from another mode MUST start the 1000 ms on / 1000 ms off cycle from the on phase.

#### Scenario: Repeated Blink keeps phase

- **WHEN** a line is blinking and the off phase is active
- **AND** the caller requests Blink again without force
- **THEN** the line MUST remain in the off phase until the scheduled tick
- **AND** MUST NOT immediately turn on

### Requirement: Forced Off always rewrites the pin

`setMode(Off, force: true)` (or equivalent reset API) MUST cancel blink and write the off level even when the line's cached mode is already Off, so boot or external HIGH leftovers can be cleared.

#### Scenario: Force Off clears sticky HIGH

- **WHEN** the line cache reports Off but the sysfs value is still high
- **AND** the caller requests Off with force
- **THEN** the backend MUST write the off level
