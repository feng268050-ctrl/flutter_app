## MODIFIED Requirements

### Requirement: USB HID mouse enumerates on existing host paths

The system SHALL support a wired **USB HID mouse** (or mouse-class HID pointer) on the same host paths as the USB keyboard: the **1 mm pin-header USB host expansion**, and the **Micro-USB** jack when OTG **`mode=host`**. When attached, the kernel MUST expose an input event node under `/dev/input/` usable by libinput/flutter-pi.

#### Scenario: Mouse appears on 1 mm host

- **WHEN** an operator connects a standard USB HID mouse through the 1 mm USB host adapter/harness
- **THEN** within 10 seconds `lsusb` (or equivalent) lists the mouse and at least one matching `/dev/input/event*` pointer device exists

#### Scenario: Mouse on Micro-USB host

- **WHEN** `mode=host` and an operator connects a USB HID mouse through an OTG adapter on Micro-USB
- **THEN** within 10 seconds the kernel enumerates the mouse and exposes an input event node under `/dev/input/`

#### Scenario: Hot unplug

- **WHEN** the mouse is unplugged from a supported host path
- **THEN** the corresponding HID input node is removed without crashing `hmi.service`
