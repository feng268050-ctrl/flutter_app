## MODIFIED Requirements

### Requirement: VBUS plug starts USB ECM debug

The target SHALL load the modular Linux **`g_ether`** driver in ECM mode and configure **`usb0`** with address **`192.168.55.1/24`** when **Debug over USB** is enabled (preference on), the OTG port is in **peripheral** role, and VBUS attach is detected (`USB=1`) during Linux runtime. The implementation SHALL NOT start plug-ssh while Debug over USB is off or the OTG port is in **host** role. The implementation SHALL NOT create a competing configfs gadget or manually reset the DWC3 controller.

#### Scenario: Cable connected after boot with Debug over USB on

- **WHEN** Debug over USB is on, the board has booted to multi-user, and a USB data cable is connected to the OTG port
- **THEN** within 10 seconds `usb0` exists with `192.168.55.1/24` and the ECM gadget is bound to the platform UDC

#### Scenario: Cable already connected at boot

- **WHEN** Debug over USB is on and a USB data cable is connected before or during boot completion
- **THEN** the ECM interface becomes available without requiring serial or UI interaction

#### Scenario: Debug over USB off does not start plug-ssh

- **WHEN** Debug over USB is off (Micro-USB host mode)
- **THEN** `lws-hmi-usb-plug-ssh.service` is not started from VBUS/extcon alone and `g_ether` is not left bound for debug SSH

## ADDED Requirements

### Requirement: Turning Debug over USB off tears down USB ECM debug

When Debug over USB is disabled (or the OTG port is switched to host for keyboard), the target SHALL stop SSH on **`usb0`** and unload **`g_ether`** (same teardown intent as VBUS unplug) so the UDC can operate as USB host.

#### Scenario: Toggle Debug over USB off

- **WHEN** plug-ssh is active and the operator turns Debug over USB off (Demo or `usb-otg-mode.sh host`)
- **THEN** within 15 seconds `g_ether` is unloaded (or unbound), sshd is no longer listening on `usb0`, and host role can enumerate peripherals
