## MODIFIED Requirements

### Requirement: Micro-USB role controlled by usb-otg-mode helper

The image SHALL provide **`/usr/libexec/hmi/usb-otg-mode.sh`**. USB debug preference SHALL be stored at **`/var/lib/hmi/usb-debug`**.

#### Scenario: Host mode stops plug-ssh unit

- **WHEN** operator sets host mode from Demo
- **THEN** `ssh-debug-usb.service` is stopped

#### Scenario: Pref not in network state dir

- **WHEN** USB debug preference is saved
- **THEN** it is stored at `/var/lib/hmi/usb-debug` not `/var/lib/network/`
