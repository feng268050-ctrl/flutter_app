# usb-plug-ssh-debug Specification

## Purpose

Target-side USB ECM plug-to-debug: VBUS-triggered gadget, `usb0` at `192.168.55.1/24`, sshd on `usb0` only, no boot-time enable.

## Requirements


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
- **THEN** `ssh-debug-usb.service` is not started from VBUS/extcon alone and `g_ether` is not left bound for debug SSH

### Requirement: Turning Debug over USB off tears down USB ECM debug

When Debug over USB is disabled (or the OTG port is switched to host for keyboard), the target SHALL stop SSH on **`usb0`** and unload **`g_ether`** (same teardown intent as VBUS unplug) so the UDC can operate as USB host.

#### Scenario: Toggle Debug over USB off

- **WHEN** plug-ssh is active and the operator turns Debug over USB off (Demo or `usb-otg-mode.sh host`)
- **THEN** within 15 seconds `g_ether` is unloaded (or unbound), sshd is no longer listening on `usb0`, and host role can enumerate peripherals

### Requirement: Unplug stops USB debug

The target SHALL stop SSH service on **`usb0`** and unload the **`g_ether`** module when VBUS is removed.

#### Scenario: Cable disconnected

- **WHEN** the USB cable is unplugged from the OTG port
- **THEN** `g_ether` is unloaded, the UDC is released, and sshd is no longer listening on `usb0`

### Requirement: Replug re-enumerates USB debug

After VBUS detach, a subsequent VBUS attach SHALL force a clean `g_ether` reload (including when the module was still sticky) so the host re-enumerates the ECM gadget and `make devices` lists a USB-SSH row again. Concurrent VBUS extcon events during debounce MUST NOT drop the final plug state.

#### Scenario: Unplug then replug

- **WHEN** the OTG cable is unplugged and then replugged during Linux runtime
- **THEN** within 15 seconds the host observes the gadget again and `make devices` shows a USB-SSH row

### Requirement: USB gadget serial identity

Each board SHALL pass a stable USB **`iSerialNumber`** plus deterministic host/device MAC addresses to `g_ether`, derived from hardware identity (Device Tree `serial-number` or SoC unique ID).

#### Scenario: Serial stable across reboots

- **WHEN** the same board reboots and USB debug is started again
- **THEN** the host observes the same `iSerial` value as before the reboot

### Requirement: sshd listens on usb0 only

While USB debug is active, SSH SHALL accept connections only on **`usb0`** at **`192.168.55.1:22`**. SSH MUST NOT listen on `eth0`, `wlan0`, or `0.0.0.0` as a result of this feature.

#### Scenario: No LAN ssh from USB debug

- **WHEN** USB debug is active and `eth0` or `wlan0` has an IP address
- **THEN** `sshd` is not accepting connections on those interfaces

#### Scenario: Password authentication

- **WHEN** a client connects to `root@192.168.55.1` over `usb0` with password `rockchip`
- **THEN** authentication succeeds and a shell is granted

### Requirement: No boot-time USB debug enable

USB ECM debug and ssh on `usb0` MUST NOT be enabled solely by reaching multi-user.target without VBUS. Units and udev rules for this feature MUST NOT be linked in `multi-user.target.wants`.

#### Scenario: Boot without USB cable

- **WHEN** the board boots with no USB host connected
- **THEN** `usb0` is not configured for ECM debug and port 22 is not listening on a USB interface

### Requirement: HMI remains running during ECM

Starting USB ECM debug SHALL NOT stop `hmi.service` automatically. **`make push-app`** SHALL install the complete staged payload while the current HMI remains running, then restart `hmi.service` with bounded activation retries and without rebooting the board. The kernel DRM GEM teardown fix SHALL be present before this in-place restart path is used.

#### Scenario: Plug cable during normal operation

- **WHEN** USB debug starts while the HMI is displaying the home screen
- **THEN** `hmi.service` remains active until explicitly restarted

### Requirement: Boot verification excludes USB debug from wants

`verify-boot` SHALL fail if USB plug-ssh units are enabled in `multi-user.target.wants` or if sshd is enabled for boot-time LAN listen as a side effect of this feature.

#### Scenario: verify-boot on clean image

- **WHEN** `verify-boot` runs after flash
- **THEN** it reports PASS for USB debug not being in `multi-user.target.wants`

### Requirement: USB debug diagnostics are available from PATH

The image SHALL expose the safe, read-only `diagnose-usb-ssh` and `read-serial` commands through `/usr/bin`. It SHALL also expose the explicit lifecycle commands `start-usb-ssh`, `stop-usb-ssh`, and `recover-usb-ssh` for serial-console recovery.

#### Scenario: Operator diagnoses USB networking

- **WHEN** an operator runs `diagnose-usb-ssh` from a device shell
- **THEN** it reports DWC3, VBUS, `g_ether`, `usb0`, and sshd state without changing device state

#### Scenario: Operator recovers USB networking from serial console

- **WHEN** diagnostics show a stale USB-SSH session
- **THEN** the operator can run `recover-usb-ssh` without entering an implementation path
### Requirement: USB plug-ssh start keeps usb0-only sshd even when LAN debug is active

When LAN/WLAN on-demand SSH debug is already active, USB plug-ssh start SHALL still bring up the ECM gadget, `usb0` addressing, and a usb0-only sshd listening on `192.168.55.1:22`.

#### Scenario: Plug USB while LAN debug enabled

- **WHEN** `enable-ssh-debug.sh` has started LAN sshd on eth0/wlan0 and the operator connects USB OTG
- **THEN** `usb0` is configured with `192.168.55.1/24` and a USB-dedicated sshd accepts connections on that address
