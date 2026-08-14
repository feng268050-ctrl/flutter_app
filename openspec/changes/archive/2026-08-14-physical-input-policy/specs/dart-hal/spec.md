## ADDED Requirements

### Requirement: Physical input policy HAL module

`hal/input` SHALL export `PhysicalInputPolicy` reading and writing `/var/lib/hal/input.conf` keys `physical_keyboard_enabled` and `physical_mouse_enabled`. Missing keys SHALL default to enabled. `LinuxKeyboard.isPresent` and `LinuxMouseSettingsController.isPresent` SHALL consult policy before HID probes.

#### Scenario: Default enabled without conf

- **WHEN** `input.conf` is absent and pack seed did not run
- **THEN** policy reports keyboard and mouse enabled
