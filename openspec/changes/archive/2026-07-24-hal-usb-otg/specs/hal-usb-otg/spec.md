## ADDED Requirements

### Requirement: Portable UsbOtg API

`cyber_hal` SHALL expose a portable **`UsbOtg`** type under **`hal/usb_otg`** that provides at least: read current persisted **`UsbOtgMode`** (`debug` / `mtp` / `host`), **`setMode`** (persist + apply), **`apply`** for boot reconcile, **`getSupport`** reading `/etc/usb-otg.ini`, and **`pickerModes`** for Settings. Product Apps MUST depend on this API rather than board scripts directly. Linux backends MUST inject board helpers via `BoardProfile` or constructors.

`UsbOtg` MUST NOT expose product attach/detach streams, `isAttached`, or insert notifications. Cable presence is out of scope for this change.

#### Scenario: Import without network wifi

- **WHEN** a product App imports only `hal/usb_otg`
- **THEN** it SHALL NOT be required to pull Wi‑Fi or Bluetooth modules

#### Scenario: Set mode persists and applies

- **WHEN** the App calls `setMode(mtp)` successfully
- **THEN** `/var/lib/hal/usb-otg.conf` contains `mode=mtp` and the on-device apply path selects MTP gadget behavior

### Requirement: Board policy via usb-otg.ini

The image or board pack SHALL publish **`/etc/usb-otg.ini`** before product UI relies on OTG policy, containing at least:

- **`debug_only=true|false`** — when true, Settings offers only Debug
- **`auto_host_support=true|false`** — when true, ID/CC may silent-select host at apply (runtime; conf unchanged)

#### Scenario: ynh960 ini defaults

- **WHEN** the lws-hmi / ynh960 image reaches multi-user
- **THEN** `/etc/usb-otg.ini` exists with `debug_only=false` and `auto_host_support=false`

#### Scenario: Auto host at apply

- **WHEN** `auto_host_support=true` and apply sees host via ID/CC
- **THEN** host role is applied at runtime without requiring a mode picker

### Requirement: Boot restores persisted mode

Boot `apply` SHALL restore `/var/lib/hal/usb-otg.conf` (default **`debug`** when missing) unless `debug_only` forces debug or auto-host selects host at runtime.

#### Scenario: Missing conf defaults to debug

- **WHEN** conf is absent and `debug_only` is false and auto-host does not force host
- **THEN** apply selects `debug`

### Requirement: Product materials for UsbOtg

A board that enables `UsbOtg` SHALL supply at least: role switch path; `/etc/usb-otg.ini`; mode apply helpers for debug, mtp, and host; writable `/userdata/storage` when MTP is offered; and `BoardProfile` injection points. Missing materials SHALL surface as unsupported/apply failure rather than silent no-op success.

#### Scenario: Missing helper fails closed

- **WHEN** a Linux `UsbOtg` backend is constructed without injectable mode helper and without a viable sysfs role path
- **THEN** mode apply/status SHALL fail with an unsupported or explicit error (not pretend success)
