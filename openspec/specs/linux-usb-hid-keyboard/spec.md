# linux-usb-hid-keyboard Specification

## Purpose

Wired USB HID keyboard on the ynh960 **1 mm pin-header USB host expansion** (not Micro-USB OTG plug-ssh): kernel enum, evdev/libinput → flutter-pi text input for Demo and later product surfaces. Soft IME remains P4.
## Requirements
### Requirement: USB HID keyboard enumerates on the 1 mm host expansion

The system SHALL support a wired **USB HID keyboard** attached via the product’s **1 mm pin-header USB host expansion** (not the on-board Micro-USB OTG jack) such that, when a keyboard is attached through that host path, the kernel enumerates the device and exposes an input event node under `/dev/input/` (typically named or linked as a keyboard).

#### Scenario: Keyboard appears after plug

- **WHEN** an operator connects a standard USB HID keyboard through the 1 mm USB host adapter/harness
- **THEN** within 10 seconds `lsusb` (or equivalent) lists the keyboard and at least one matching `/dev/input/event*` device exists

#### Scenario: Hot unplug

- **WHEN** the keyboard is unplugged from the host expansion path
- **THEN** the corresponding HID input node is removed without crashing `hmi.service`

### Requirement: Keys reach flutter-pi / Flutter focus

With a focused text input in the HMI Flutter app running under flutter-pi, printable keys and common editing keys from the USB HID keyboard SHALL be delivered through the platform input path (evdev/libinput → flutter-pi → Flutter) without requiring a Dart soft-IME.

#### Scenario: Type into Demo field

- **WHEN** the Demo keyboard section text field has focus and the operator types ASCII characters on the USB keyboard attached via the 1 mm host expansion
- **THEN** those characters appear in the text field

### Requirement: Micro-USB OTG plug-ssh remains a separate path

Keyboard host bring-up SHALL NOT require unloading plug-ssh `g_ether` or switching the on-board Micro-USB OTG connector to host mode. Soft on-screen keyboard (FrostIME) is out of scope for this capability.

#### Scenario: Concurrent Micro-USB plug-ssh and expansion host keyboard

- **WHEN** Micro-USB OTG plug-ssh is active (or available) and a USB HID keyboard is attached via the 1 mm host expansion
- **THEN** keyboard enumeration and typing smoke MUST still be possible without an OTG role-switch procedure
