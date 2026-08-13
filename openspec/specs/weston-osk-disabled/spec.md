# weston-osk-disabled Specification

## Purpose
Product HMI Weston must not start `weston-keyboard` (or any `[input-method]` OSK client). Soft text entry stays on CyberIME; physical HID stays on libinput/XKB. No `weston-mouse` controls when that client is absent.

## Requirements

### Requirement: HMI Weston seat does not start weston-keyboard

The product HMI Weston configuration (runtime ini used by `hmi-launch` / `weston-hmi-config`, and matching static/post-hook defaults) MUST NOT launch `/usr/libexec/weston-keyboard` or any other `[input-method]` on-screen keyboard client. Soft text entry for product Apps MUST continue to use CyberIME. Physical HID keyboards MUST continue to work through the existing libinput / XKB / eLinux path without this client.

#### Scenario: Cold boot has no weston-keyboard

- **WHEN** the board boots and `hmi.service` has started Weston for the HMI seat
- **THEN** `pidof weston-keyboard` is empty

#### Scenario: CyberIME still available without HID

- **WHEN** no physical keyboard is connected and the operator focuses a CyberIME text field
- **THEN** the CyberIME soft panel is shown

#### Scenario: Physical HID still types without weston-keyboard

- **WHEN** a USB or Bluetooth HID keyboard is connected and a text field has focus
- **THEN** key events still reach the focused field through the existing input path
- **AND** `weston-keyboard` is not required to be running

### Requirement: weston-mouse out of scope when absent

If the image does not ship or launch a `weston-mouse` (or equivalent Weston pointer helper client), the system MUST NOT add controls for it. Pointer preferences remain under OS Settings → Mouse.

#### Scenario: No weston-mouse on current stack

- **WHEN** the current product Weston desktop-shell session is running on ynh960
- **THEN** `weston-mouse` is not required to be present or running
