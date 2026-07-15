## MODIFIED Requirements

### Requirement: make devices lists RockUSB and USB-SSH targets

The repository SHALL extend **`make devices`** to list **RockUSB** flash devices (`upgrade_tool ld`), **USB-SSH** Linux boards, **registered remote SSH** boards (`MODE=SSH`), and **adb-connected Android** devices (`MODE` column: `Loader`, `Maskrom`, `USB-SSH`, `SSH`, `android`, etc.) in a **single merged table** with columns including **`SERIAL`**, **`LocationID`**, host **`IFACE`** (USB-SSH only; `-` for SSH), and target **`IP`** (`192.168.55.1` for USB-SSH; registered IP for SSH; matches `IP=` selection for `MODE=SSH`). There SHALL NOT be a separate **`make devices-usb-ssh`** target.

When USB-SSH device(s) are present and **`sshpass`** is not installed, the command SHALL print an install hint (push-app / reboot require sshpass).

#### Scenario: Two boards connected

- **WHEN** two boards are connected via USB ECM
- **THEN** the command output contains two rows with distinct `SERIAL` values and distinct host `IFACE` values

#### Scenario: Mixed RockUSB and USB-SSH

- **WHEN** one board is in RockUSB Loader mode and another is running Linux with USB plug-ssh active
- **THEN** `make devices` shows one row with `MODE` Loader (or Maskrom) and one row with `MODE` USB-SSH in the same table

#### Scenario: Registered remote SSH appears with USB-SSH

- **WHEN** one USB-SSH board is plugged in and one remote IP was registered with `make connect`
- **THEN** `make devices` shows both a `USB-SSH` row and an `SSH` row in the same table

### Requirement: SERIAL selects target for push-app

When more than one deployable Linux target is available (USB-SSH and/or registered SSH), **`make push-app`** SHALL require **`SERIAL=`** (or **`LWS_HMI_SERIAL=`**) matching the board serial, or **`IP=`** / **`LWS_HMI_IP=`** matching a registered **`MODE=SSH`** address. **`IP=`** SHALL NOT select USB-SSH devices. Multi-device selection remains consistent with `scripts/flash-usb.sh` SERIAL ergonomics for USB-SSH.

#### Scenario: Multiple devices without SERIAL

- **WHEN** two USB-SSH devices are connected and the user runs `make push-app` without `SERIAL` or `IP`
- **THEN** the command fails with a message to run `make devices` and set `SERIAL` or `IP`

#### Scenario: Push with SERIAL

- **WHEN** `SERIAL=<iSerial> make push-app` is run with multiple devices connected
- **THEN** artifacts are deployed only to the board matching that serial

#### Scenario: Push with IP to SSH device

- **WHEN** a remote SSH device is registered and the user runs `IP=<ip> make push-app`
- **THEN** artifacts are deployed only to that registered SSH address

### Requirement: make reboot triggers normal board reset

The repository SHALL provide **`make reboot`** that reboots a connected board **without** entering RockUSB Loader: Linux HMI via USB-SSH or registered remote SSH (**sysrq reboot**); Android via **`adb reboot`**. **`make reboot-loader`** is the Loader entry path and SHALL NOT use registered **`MODE=SSH`** devices.

#### Scenario: Linux board over USB-SSH

- **WHEN** the board is running Linux with USB debug active and the host runs `make reboot`
- **THEN** the host schedules sysrq reboot on the target and returns without waiting for boot to complete

#### Scenario: Linux board over registered SSH

- **WHEN** a remote SSH device is registered (and selected by default or via `IP=` / `SERIAL=`) and the host runs `make reboot`
- **THEN** the host schedules sysrq reboot over unbound TCP SSH and returns without waiting for boot to complete

#### Scenario: Android adb fallback

- **WHEN** no USB-SSH or registered SSH target is available and adb reports a connected Android device
- **THEN** `make reboot` uses `adb reboot`

## ADDED Requirements

### Requirement: make reboot-loader ignores remote SSH registry

**`make reboot-loader`** SHALL select only USB-SSH (or adb / already-present RockUSB) targets. When the only Linux target is a registered **`MODE=SSH`** device, the command SHALL fail with guidance to use USB-SSH or enter Loader/MaskROM manually rather than SSHing to the remote IP for `reboot-loader`.

#### Scenario: Only remote SSH registered

- **WHEN** no USB-SSH device is present, a remote SSH IP is registered, and the host runs `make reboot-loader`
- **THEN** the command does not send `reboot-loader` over the SSH registry connection and fails with an actionable message
