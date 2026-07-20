## ADDED Requirements

### Requirement: Phased FrostUI parity excluding IME

`packages/cyber_ui` SHALL grow until lws-ui FrostUI modules `border`, `button`, `control`, `dialog`, and `clock` have Cyber counterparts sufficient for product Settings/Home/Monitor chrome. **CyberIME is explicitly excluded** from this requirement. Existing blur/card/click/volume APIs MUST remain and be extended rather than replaced wholesale.

#### Scenario: Module map lists control suite

- **WHEN** Phase B–D are complete
- **THEN** the package README module map lists switch, checkbox, slider, segmented, stepper, and dialog-host entries
