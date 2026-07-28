## ADDED Requirements

### Requirement: RGB LED Settings forces Off on enter

When the operator opens the Common Settings RGB LED page, the App SHALL suppress production RGB LED policy for the duration of the page, force red/yellow/green to Off, and present Off as the selected mode for each color until the operator chooses Steady or Blink. Leaving the page SHALL end the suppress and allow production policy to refresh.

#### Scenario: Settings entry resets indicators

- **WHEN** the operator navigates to the RGB LED settings page
- **THEN** all three colors are forced Off
- **AND** production alarm/standby/ready policy does not overwrite manual selections while the page remains open

#### Scenario: Leaving settings resumes policy

- **WHEN** the operator leaves the RGB LED settings page
- **THEN** production policy resumes and reapplies computed modes
