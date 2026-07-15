## MODIFIED Requirements

### Requirement: Image retains USB HID host support for the 1 mm expansion

The lws-hmi Buildroot/kernel configuration for ynh960 SHALL retain (or restore if previously trimmed) the USB HID and **USB host controller** pieces required for a wired keyboard on the **1 mm pin-header host expansion**: host controller / PHY for that path, `usbhid`/`hid-generic` (or equivalent). Trim fragments and the Micro-USB OTG overlay MUST NOT leave that host expansion disabled solely to enable OTG gadget or dual-role mode. Micro-USB OTG dual-role and plug-ssh remain in scope of `usb-otg-id-role` / `usb-plug-ssh-debug` and MUST keep working per those specs.

#### Scenario: HID host path present for keyboard expansion

- **WHEN** the flashed image boots and a USB HID keyboard is plugged in via the 1 mm host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Overlay verify lists new helpers if shipped

- **WHEN** the change adds overlay helpers specific to host-expansion keyboard bring-up (if any)
- **THEN** `scripts/verify-rootfs-overlay.sh` (and env-verify expectations if applicable) includes those helpers

## ADDED Requirements

### Requirement: Image enables Micro-USB OTG dual-role with HID host on OTG

The lws-hmi kernel/Device Tree/Buildroot configuration SHALL enable **OTG dual-role** on the Micro-USB `usbdrd` path (`dr_mode=otg` or equivalent) with USB HID host support when that port is in host role, without removing the 1 mm expansion host enablement. DWC3 MUST NOT be built gadget-only if that prevents OTG host on Micro-USB.

#### Scenario: OTG host keyboard without out-of-tree modules

- **WHEN** the flashed image boots, Micro-USB is in host role via ID, and a USB HID keyboard is attached through an OTG host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Peripheral plug-ssh still available

- **WHEN** the same image is used with a PC data cable on Micro-USB (peripheral role + VBUS)
- **THEN** plug-ssh ECM debug can still come up per `usb-plug-ssh-debug`
