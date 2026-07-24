## MODIFIED Requirements

### Requirement: VBUS plug starts USB ECM debug

The target SHALL load the modular Linux **`g_ether`** driver in ECM mode and configure **`usb0`** with address **`192.168.55.1/24`** when OTG **`mode=debug`**, the OTG port is in **peripheral** role, and VBUS attach is detected (`USB=1`) during Linux runtime. The implementation SHALL NOT start plug-ssh while mode is **`host`** or **`mtp`**, or while the OTG port is in **host** role. The implementation SHALL NOT create a competing configfs gadget or manually reset the DWC3 controller.

#### Scenario: Cable connected after boot with debug mode

- **WHEN** `mode=debug`, the board has booted to multi-user, and a USB data cable is connected to the OTG port
- **THEN** within 10 seconds `usb0` exists with `192.168.55.1/24` and the ECM gadget is bound to the platform UDC

#### Scenario: Cable already connected at boot

- **WHEN** `mode=debug` and a USB data cable is connected before or during boot completion
- **THEN** the ECM interface becomes available without requiring serial or UI interaction

#### Scenario: Non debug mode does not start plug-ssh

- **WHEN** `mode` is `host` or `mtp`
- **THEN** `ssh-debug-usb.service` is not started from VBUS/extcon alone and `g_ether` is not left bound for debug SSH

### Requirement: Turning Debug over USB off tears down USB ECM debug

When OTG mode leaves **`debug`** (switched to **`host`** or **`mtp`**), the target SHALL stop SSH on **`usb0`** and unload **`g_ether`** (same teardown intent as VBUS unplug) so the UDC can operate as USB host or run MTP.

#### Scenario: Toggle away from debug

- **WHEN** plug-ssh is active and the operator sets `mode=host` or `mode=mtp` (App dialog or `usb-otg-mode.sh`)
- **THEN** within 15 seconds `g_ether` is unloaded (or unbound), sshd is no longer listening on `usb0`, and the new mode’s apply path can proceed
