## MODIFIED Requirements

### Requirement: Keys reach eLinux HMI / Flutter focus

With a focused text input in the HMI Flutter app running under eLinux HMI, printable keys and common editing keys from the USB HID keyboard SHALL be delivered through the platform input path (evdev/libinput → eLinux HMI → Flutter) without requiring a Dart soft-IME, whether the keyboard is attached via the **1 mm host expansion** or via **Micro-USB host** (`mode=host`), **when physical keyboard policy is enabled**.

#### Scenario: Policy off blocks libinput keyboard delivery

- **WHEN** `physical_keyboard_enabled=0` and a USB keyboard is attached
- **THEN** libinput SHALL ignore the keyboard device and HAL `Keyboard.isPresent()` SHALL return false

#### Scenario: Type into Demo field when enabled

- **WHEN** physical keyboard policy is enabled, the Demo keyboard section text field has focus, and the operator types ASCII characters on the USB keyboard attached via the 1 mm host expansion
- **THEN** those characters appear in the text field
