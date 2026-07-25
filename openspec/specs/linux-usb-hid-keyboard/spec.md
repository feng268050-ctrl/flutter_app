# linux-usb-hid-keyboard Specification

## Purpose

Wired USB HID keyboard on ynh960: **1 mm pin-header USB host expansion** always, and **Micro-USB** when Debug over USB is off (OTG host). Kernel enum, evdev/libinput → eLinux HMI text input for Demo and later product surfaces. Soft IME remains P4.

## Requirements
### Requirement: USB HID keyboard enumerates on the 1 mm host expansion

The system SHALL support a wired **USB HID keyboard** attached via the product’s **1 mm pin-header USB host expansion** such that, when a keyboard is attached through that host path, the kernel enumerates the device and exposes an input event node under `/dev/input/` (typically named or linked as a keyboard). The on-board Micro-USB jack MAY also host a keyboard when OTG **`mode=host`** (see `usb-otg-id-role` / `hal-usb-otg`); the 1 mm path MUST remain supported.

#### Scenario: Keyboard appears after plug

- **WHEN** an operator connects a standard USB HID keyboard through the 1 mm USB host adapter/harness
- **THEN** within 10 seconds `lsusb` (or equivalent) lists the keyboard and at least one matching `/dev/input/event*` device exists

#### Scenario: Hot unplug

- **WHEN** the keyboard is unplugged from the host expansion path
- **THEN** the corresponding HID input node is removed without crashing `hmi.service`
### Requirement: USB HID keyboard enumerates on Micro-USB when Debug over USB is off

The system SHALL support a wired **USB HID keyboard** attached to the on-board **Micro-USB** jack when OTG **`mode=host`** (formerly “Debug over USB off”), such that the kernel enumerates the device and exposes an input event node under `/dev/input/` usable by eLinux HMI, in addition to the existing **1 mm pin-header USB host expansion** path.

#### Scenario: Keyboard on OTG after host mode

- **WHEN** `mode=host` and an operator connects a USB HID keyboard through an OTG adapter on Micro-USB
- **THEN** within 10 seconds `lsusb` (or equivalent) lists the keyboard and at least one matching `/dev/input/event*` device exists

#### Scenario: Keys from OTG keyboard reach Demo field

- **WHEN** the Demo keyboard section text field has focus and the operator types ASCII characters on a keyboard attached via Micro-USB in host mode
- **THEN** those characters appear in the text field
### Requirement: Keys reach eLinux HMI / Flutter focus

With a focused text input in the HMI Flutter app running under eLinux HMI, printable keys and common editing keys from the USB HID keyboard SHALL be delivered through the platform input path (evdev/libinput → eLinux HMI → Flutter) without requiring a Dart soft-IME, whether the keyboard is attached via the **1 mm host expansion** or via **Micro-USB host** (`mode=host`).

#### Scenario: Type into Demo field

- **WHEN** the Demo keyboard section text field has focus and the operator types ASCII characters on the USB keyboard attached via the 1 mm host expansion
- **THEN** those characters appear in the text field
### Requirement: Micro-USB OTG plug-ssh remains a separate path

Keyboard host bring-up on the **1 mm expansion** SHALL NOT require unloading plug-ssh `g_ether` or changing OTG mode. Soft on-screen keyboard (FrostIME) is out of scope. Keyboard on Micro-USB SHALL use **`mode=host`** per `usb-otg-id-role` / `hal-usb-otg` and MUST NOT require plug-ssh to stay loaded in host mode.

#### Scenario: Concurrent Micro-USB plug-ssh and expansion host keyboard

- **WHEN** `mode=debug` (peripheral plug-ssh) and a USB HID keyboard is attached via the 1 mm host expansion
- **THEN** keyboard enumeration and typing smoke MUST still be possible without switching OTG mode for the expansion keyboard
