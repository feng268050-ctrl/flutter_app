# linux-usb-hid-mouse Specification

## Purpose

Wired USB HID mouse (pointer) on ynh960: **1 mm pin-header USB host expansion** always, and **Micro-USB** when Debug over USB is off (OTG host). Kernel enum, evdev/libinput → flutter-pi pointer events, and a visible on-screen cursor.

## Requirements

### Requirement: USB HID mouse enumerates on existing host paths

The system SHALL support a wired **USB HID mouse** (or mouse-class HID pointer) on the same host paths as the USB keyboard: the **1 mm pin-header USB host expansion**, and the **Micro-USB** jack when Debug over USB is **off** (OTG host). When attached, the kernel MUST expose an input event node under `/dev/input/` usable by libinput/flutter-pi.

#### Scenario: Mouse appears on 1 mm host

- **WHEN** an operator connects a standard USB HID mouse through the 1 mm USB host adapter/harness
- **THEN** within 10 seconds `lsusb` (or equivalent) lists the mouse and at least one matching `/dev/input/event*` pointer device exists

#### Scenario: Mouse on Micro-USB host

- **WHEN** Debug over USB is off and an operator connects a USB HID mouse through an OTG adapter on Micro-USB
- **THEN** within 10 seconds the kernel enumerates the mouse and exposes an input event node under `/dev/input/`

#### Scenario: Hot unplug

- **WHEN** the mouse is unplugged
- **THEN** the corresponding HID input node is removed without crashing `hmi.service`

### Requirement: Pointer events reach Flutter

With the HMI Flutter app running under flutter-pi, USB mouse motion, primary/secondary buttons, and vertical wheel events SHALL be delivered through the platform input path (evdev/libinput → flutter-pi → Flutter) without a custom Dart HID decoder.

#### Scenario: Wheel scrolls Demo content

- **WHEN** a USB mouse is attached and the operator scrolls the wheel over a scrollable Demo surface
- **THEN** the surface scrolls in response to the wheel events

#### Scenario: Click hits hit-testable widget

- **WHEN** a USB mouse is attached and the operator moves to a button and presses the primary button
- **THEN** that button’s press handler runs

### Requirement: On-screen mouse pointer is visible

When at least one USB HID mouse (pointer device that enables flutter-pi’s cursor) is attached, the system SHALL display a **visible** on-screen pointer that tracks mouse motion. The pointer MUST remain usable on ynh960 even if the DRM hardware cursor plane is unavailable or broken (software or other reliable fallback MAY be used). When no cursor-capable pointer device is attached, the system SHOULD hide the pointer (touch-only operation).

#### Scenario: Pointer appears after plug

- **WHEN** an operator plugs a USB mouse while the HMI is running
- **THEN** within 5 seconds a visible pointer is shown and moves with the mouse

#### Scenario: Pointer tracks motion

- **WHEN** the mouse is moved across the display
- **THEN** the visible pointer position tracks the motion without staying stuck in a corner

#### Scenario: Unplug hides pointer

- **WHEN** the last cursor-capable mouse is unplugged
- **THEN** the on-screen pointer is hidden (or no longer moves) without crashing the HMI
