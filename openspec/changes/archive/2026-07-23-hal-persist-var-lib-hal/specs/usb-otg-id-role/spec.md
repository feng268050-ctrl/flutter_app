## MODIFIED Requirements

### Requirement: Manual USB Debug preference for Micro-USB role

Because Micro-USB **ID may be unwired or OTG adapters leave ID floating**, the system SHALL NOT require IDDIG auto-role for Demo/product control. The image SHALL provide `/usr/libexec/hmi/usb-otg-mode.sh` with commands `debug` / `host` / `status` / `apply` that select Micro-USB **peripheral (Debug over USB / plug-ssh)** vs **host (keyboard)**. Preference SHALL be stored at `/var/lib/hal/usb-debug` (`1` = debug, `0` = host). When the preference file is missing, Debug over USB SHALL default to **on**.

#### Scenario: Default Debug over USB on

- **WHEN** `/var/lib/hal/usb-debug` is absent and `usb-otg-mode.sh apply` runs
- **THEN** the OTG PHY is set for the peripheral/debug path so PC plug-ssh can start on VBUS

#### Scenario: Debug over USB off enables Micro-USB host

- **WHEN** an operator runs `usb-otg-mode.sh host` (or Demo turns Debug over USB off)
- **THEN** preference is `0`, `otg_mode` is `host`, and `ssh-debug-usb.service` is stopped so a keyboard on an OTG adapter can enumerate

#### Scenario: Preference survives reboot via userdata bind

- **WHEN** Debug over USB was set off and the board reboots with `/var/lib/hal` bound to userdata
- **THEN** boot apply restores host mode without requiring Demo interaction
