## MODIFIED Requirements

### Requirement: Phased FrostUI parity excluding IME

`packages/cyber_ui` SHALL grow until lws-ui FrostUI modules `border`, `button`, `control`, `dialog`, and `clock` have Cyber counterparts sufficient for product Settings/Home/Monitor chrome. **Soft-keyboard / CyberIME rendering remains out of `cyber_ui`** and is delivered by the separate `packages/cyber_ime` package (this change). Existing blur/card/click/volume APIs MUST remain and be extended rather than replaced wholesale. CyberUI dialog/overlay hosts MAY expose lift/refresh hooks for CyberIME composition without absorbing keyboard widgets.

#### Scenario: Module map lists control suite

- **WHEN** Phase B–D are complete
- **THEN** the package README module map lists switch, checkbox, slider, segmented, stepper, and dialog-host entries

#### Scenario: Keyboard lives in cyber_ime

- **WHEN** product code needs an HMI soft keyboard
- **THEN** it depends on `cyber_ime` rather than importing keyboard layouts from `cyber_ui`
