## ADDED Requirements

### Requirement: Image includes MTP gadget userspace for OTG mtp mode

The lws-hmi Buildroot configuration SHALL include the kernel and userspace pieces required to run USB **MTP** gadget mode for `usb-otg-mtp` (FunctionFS/configfs MTP and/or the selected MTP responder package such as umtprd, as decided in implementation). Shipping the image MUST NOT omit MTP deps while advertising `mode=mtp`.

#### Scenario: MTP binary present on rootfs

- **WHEN** `verify-rootfs-overlay` / rootfs checks run after this change
- **THEN** the chosen MTP responder (or documented unit/helper path) is present on the rootfs used by ynh960

## MODIFIED Requirements

### Requirement: Image retains USB HID host support for the 1 mm expansion

The lws-hmi Buildroot/kernel configuration for ynh960 SHALL retain (or restore if previously trimmed) the USB HID and **USB host controller** pieces required for a wired keyboard on the **1 mm pin-header host expansion**: host controller / PHY for that path, `usbhid`/`hid-generic` (or equivalent). Trim fragments and the Micro-USB OTG overlay MUST NOT leave that host expansion disabled solely to enable OTG gadget or dual-role mode. Micro-USB OTG dual-role, plug-ssh, and **MTP** remain in scope of `usb-otg-id-role` / `usb-plug-ssh-debug` / `usb-otg-mtp` and MUST keep working per those specs.

#### Scenario: HID host path present for keyboard expansion

- **WHEN** the flashed image boots and a USB HID keyboard is plugged in via the 1 mm host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Expansion host keyboard still enumerates with debug

- **WHEN** a USB HID keyboard is attached via the 1 mm host expansion while OTG mode is `debug`
- **THEN** the keyboard still enumerates on the expansion host path
