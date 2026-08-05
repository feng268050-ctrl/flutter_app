# usb-otg-id-role Specification

## Purpose

Micro-USB dual-role control for ynh960: operator **Debug over USB** preference selects peripheral (plug-ssh) vs host (OTG keyboard). Kernel keeps `dr_mode=otg`; product UX does not rely on IDDIG auto-role (common OTG adapters leave ID floating).
## Requirements
### Requirement: Manual USB Debug preference for Micro-USB role

Because Micro-USB **ID may be unwired or OTG adapters leave ID floating**, the system SHALL NOT require IDDIG auto-role for Demo/product control. The image SHALL provide `/usr/libexec/usb/usb-otg-mode.sh` with commands `debug` / `host` / `status` / `apply` that select Micro-USB **peripheral (Debug over USB / plug-ssh)** vs **host (keyboard)**. Preference SHALL be stored at `/var/lib/hal/usb-debug` (`1` = debug, `0` = host). When the preference file is missing, Debug over USB SHALL default to **on**.

#### Scenario: Default Debug over USB on

- **WHEN** `/var/lib/hal/usb-debug` is absent and `usb-otg-mode.sh apply` runs
- **THEN** the OTG PHY is set for the peripheral/debug path so PC plug-ssh can start on VBUS

#### Scenario: Debug over USB off enables Micro-USB host

- **WHEN** an operator runs `usb-otg-mode.sh host` (or Demo turns Debug over USB off)
- **THEN** preference is `0`, `otg_mode` is `host`, and `ssh-debug-usb.service` is stopped so a keyboard on an OTG adapter can enumerate

#### Scenario: Preference survives reboot via userdata bind

- **WHEN** Debug over USB was set off and the board reboots with `/var/lib/hal` bound to userdata
- **THEN** boot apply restores host mode without requiring Demo interaction

### Requirement: Kernel retains OTG dual-role capability

The Micro-USB controller SHALL remain configured for OTG dual-role (`dr_mode=otg` or equivalent) so userspace can switch `otg_mode` between peripheral and host under the Debug over USB preference.

#### Scenario: otg_mode writable

- **WHEN** Debug over USB is toggled on the running system
- **THEN** `/sys/devices/platform/fe8a0000.usb2-phy/otg_mode` reflects `peripheral` or `host` accordingly

### Requirement: Micro-USB role controlled by usb-otg-mode helper

Because Micro-USB **ID may be unwired or OTG adapters leave ID floating**, the system SHALL NOT require IDDIG auto-role for product control on boards that publish `auto_host_support=false` in `/etc/usb-otg.ini`. The image SHALL provide `/usr/libexec/usb/usb-otg-mode.sh` (or successor) with commands that select Micro-USB modes **`debug`** (peripheral + plug-ssh), **`mtp`** (peripheral + MTP), and **`host`** (keyboard/mouse peripherals), plus **`status`** / **`apply`**. An **`attached`** subcommand MAY remain as a no-op diagnostic returning detached; it MUST NOT be a product attach signal.

Persisted preference SHALL be **`/var/lib/hal/usb-otg.conf`** (`mode=debug|mtp|host`, default debug). Board policy SHALL be **`/etc/usb-otg.ini`** (`debug_only`, `auto_host_support`). Legacy **`/var/lib/hal/usb-debug`** and session-only **`/run/usb-otg.mode`** MUST NOT remain the ongoing source of truth.

#### Scenario: Apply restores conf

- **WHEN** `/var/lib/hal/usb-otg.conf` has `mode=mtp` and `usb-otg-mode.sh apply` runs without auto-host selection
- **THEN** MTP gadget behavior is selected

#### Scenario: Explicit host

- **WHEN** an operator runs `usb-otg-mode.sh host` (or the App sets `mode=host`)
- **THEN** conf records `mode=host`, `otg_mode` is `host`, and plug-ssh / MTP gadgets are stopped so a keyboard on an OTG adapter can enumerate

#### Scenario: Auto-host on boards with ID/CC

- **WHEN** `auto_host_support=true` and boot/udev apply sees `USB-HOST=1`
- **THEN** boot apply selects host role at runtime without requiring a mode-picker dialog
### Requirement: Dual-role controller retained

The Micro-USB controller SHALL remain configured for OTG dual-role (`dr_mode=otg` or equivalent) so userspace can switch `otg_mode` between peripheral and host under the selected mode.
