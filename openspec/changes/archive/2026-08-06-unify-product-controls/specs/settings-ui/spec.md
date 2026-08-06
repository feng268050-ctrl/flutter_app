## MODIFIED Requirements

### Requirement: Prefer Cyber controls when available

As CyberUI gains switch, checkbox, slider, segmented, stepper, and dialog-host widgets, Settings screens that currently use Material stand-ins for the same role SHALL migrate to the Cyber counterparts in the adoption phase (Phase G), unless a documented exception applies (e.g. platform picker that has no Cyber equivalent yet). **Text / password / numeric keyboard entry SHALL use CyberIME** rather than relying on the system soft keyboard once `cyber_ime` is integrated. Settings boolean rows and checkboxes that are already on Cyber MUST remain on `CyberSwitch` / `CyberCheckbox` (large tier 28 for checkbox faces) and MUST NOT regress to Material `Switch` / `Checkbox`.

#### Scenario: Volume and sound-effect already on Cyber path

- **WHEN** the operator opens Volume or Sound Effect under Display & Sound after Phase G
- **THEN** those screens use Cyber volume / sound-effect chrome from `cyber_ui` (or documented successor) rather than a one-off Material-only glass kit

#### Scenario: Switch rows use CyberSwitch

- **WHEN** a Settings boolean row that previously used Material `Switch` is migrated in Phase G
- **THEN** that row uses `CyberSwitch` (or package equivalent) rather than raw Material `Switch` alone

#### Scenario: Password entry uses CyberIME

- **WHEN** the operator focuses a Settings password field after CyberIME adoption
- **THEN** input is committed through CyberIME rather than the system soft keyboard alone

#### Scenario: Settings checkbox stays Cyber large

- **WHEN** a Settings row presents a checkbox control
- **THEN** it uses `CyberCheckbox` at `CyberDimens.checkboxLargeSize` (28)
