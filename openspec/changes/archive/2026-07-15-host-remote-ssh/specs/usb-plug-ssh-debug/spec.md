## ADDED Requirements

### Requirement: USB plug-ssh start keeps usb0-only sshd even when LAN debug is active

When LAN/WLAN on-demand SSH debug is already active, USB plug-ssh start SHALL still bring up the ECM gadget, `usb0` addressing, and a usb0-only sshd listening on `192.168.55.1:22`.

#### Scenario: Plug USB while LAN debug enabled

- **WHEN** `enable-ssh-debug.sh` has started LAN sshd on eth0/wlan0 and the operator connects USB OTG
- **THEN** `usb0` is configured with `192.168.55.1/24` and a USB-dedicated sshd accepts connections on that address
