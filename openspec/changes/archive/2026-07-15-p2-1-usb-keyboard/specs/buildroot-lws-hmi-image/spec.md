## ADDED Requirements

### Requirement: Image retains USB HID host support for the 1 mm expansion

The lws-hmi Buildroot/kernel configuration for ynh960 SHALL retain (or restore if previously trimmed) the USB HID and **USB host controller** pieces required for a wired keyboard on the **1 mm pin-header host expansion**: host controller / PHY for that path, `usbhid`/`hid-generic` (or equivalent). Trim fragments and the OTG gadget overlay MUST NOT leave that host expansion disabled solely to enable Micro-USB OTG peripheral mode. Micro-USB OTG plug-ssh remains in scope of `usb-plug-ssh-debug` and MUST keep working.

#### Scenario: HID host path present for keyboard expansion

- **WHEN** the flashed image boots and a USB HID keyboard is plugged in via the 1 mm host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Overlay verify lists new helpers if shipped

- **WHEN** the change adds overlay helpers specific to host-expansion keyboard bring-up (if any)
- **THEN** `scripts/verify-rootfs-overlay.sh` (and env-verify expectations if applicable) includes those helpers

### Requirement: flutter-pi keyboard runtime data present

The image SHALL ship the userspace data flutter-pi needs to enable text/raw keyboard input: **xkeyboard-config** files under `/usr/share/X11/xkb` (including `rules/evdev`) and enough X11 locale Compose mapping under `/usr/share/X11/locale` for locale `C` / `C.UTF-8`. Enabling `BR2_PACKAGE_LIBXKBCOMMON` alone is not sufficient. Full X.org (`BR2_PACKAGE_XORG7`) is not required when Compose stubs are provided via rootfs overlay.

#### Scenario: flutter-pi initializes keyboard configuration

- **WHEN** `flutter-pi` starts on a flashed image that includes the keyboard runtime data
- **THEN** it MUST NOT log `Could not initialize keyboard configuration` / `Flutter-pi will run without text/raw keyboard input`
