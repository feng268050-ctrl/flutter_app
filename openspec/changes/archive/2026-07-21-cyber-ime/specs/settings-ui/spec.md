## ADDED Requirements

### Requirement: Settings text entry uses CyberIME when available

Settings surfaces that collect free text, passwords, or numeric parameters through operator keyboards (at least Wi‑Fi password / connect, HTTP proxy host or port, and one numeric Settings field) SHALL attach a CyberIME session for those fields when `cyber_ime` is a product dependency. Those fields MUST NOT depend on the OEM/system soft keyboard as the primary input method on Linux HMI.

#### Scenario: Wi-Fi password field uses CyberIME

- **WHEN** the operator focuses the Wi‑Fi password field in Settings
- **THEN** the CyberIME keyboard panel is shown for that field type profile
- **AND** committed characters update the password field

#### Scenario: HTTP proxy field uses CyberIME

- **WHEN** the operator focuses an HTTP proxy text or port field that requires keyboard entry
- **THEN** a CyberIME session is attached with the appropriate field type (Text or Number)

## MODIFIED Requirements

### Requirement: Prefer Cyber controls when available

As CyberUI gains switch, checkbox, slider, segmented, stepper, and dialog-host widgets, Settings screens that currently use Material stand-ins for the same role SHALL migrate to the Cyber counterparts in the adoption phase (Phase G), unless a documented exception applies (e.g. platform picker that has no Cyber equivalent yet). **Text / password / numeric keyboard entry SHALL use CyberIME** rather than relying on the system soft keyboard once `cyber_ime` is integrated.

#### Scenario: Volume and sound-effect already on Cyber path

- **WHEN** the operator opens Volume or Sound Effect under Display & Sound after Phase G
- **THEN** those screens use Cyber volume / sound-effect chrome from `cyber_ui` (or documented successor) rather than a one-off Material-only glass kit

#### Scenario: Switch rows use CyberSwitch

- **WHEN** a Settings boolean row that previously used Material `Switch` is migrated in Phase G
- **THEN** that row uses `CyberSwitch` (or package equivalent) rather than raw Material `Switch` alone

#### Scenario: Password entry uses CyberIME

- **WHEN** the operator focuses a Settings password field after CyberIME adoption
- **THEN** input is committed through CyberIME rather than the system soft keyboard alone
