## ADDED Requirements

### Requirement: Micro-USB role controlled by usb-otg-mode helper

Because Micro-USB **ID may be unwired or OTG adapters leave ID floating**, the system SHALL NOT require IDDIG auto-role for product control on boards that publish `auto_host_support=false` in `/etc/usb-otg.ini`. The image SHALL provide `/usr/libexec/hmi/usb-otg-mode.sh` (or successor) with commands that select Micro-USB modes **`debug`** (peripheral + plug-ssh), **`mtp`** (peripheral + MTP), and **`host`** (keyboard/mouse peripherals), plus **`status`** / **`apply`**. An **`attached`** subcommand MAY remain as a no-op diagnostic returning detached; it MUST NOT be a product attach signal.

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
