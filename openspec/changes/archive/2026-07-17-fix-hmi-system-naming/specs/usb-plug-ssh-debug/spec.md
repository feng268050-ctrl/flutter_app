## MODIFIED Requirements

### Requirement: USB plug-ssh not started from VBUS alone

When Debug over USB preference is off, VBUS alone MUST NOT start the gadget SSH path.

#### Scenario: Host mode blocks plug-ssh from VBUS

- **WHEN** `/var/lib/hmi/usb-debug` indicates host mode and VBUS is present
- **THEN** `ssh-debug-usb.service` is not started from VBUS alone
