## MODIFIED Requirements

### Requirement: make devices lists RockUSB and USB-SSH targets

The repository SHALL extend **`make devices`** to list **RockUSB** flash devices (`upgrade_tool ld`), **USB-SSH** Linux boards, **registered remote SSH** boards (`MODE=SSH`), and **adb-connected Android** devices (`MODE` column: `Loader`, `Maskrom`, `USB-SSH`, `SSH`, `android`, etc.) in a **single merged table** with columns including **`SN`**, **`LocationID`**, host **`IFACE`** (USB-SSH only; `-` for SSH), and target **`IP`** (`192.168.55.1` for USB-SSH; registered IP for SSH; matches `IP=` selection for `MODE=SSH`). The table MUST NOT include a **ChipID** column. **SN** follows product identity (Vendor Storage SN, else chip serial); for android adb and RockUSB loader rows, SN SHALL be the adb SerialNo / upgrade_tool SerialNo. There SHALL NOT be a separate **`make devices-usb-ssh`** target.

When USB-SSH device(s) are present and **`sshpass`** is not installed, the command SHALL print an install hint (push-app / reboot require sshpass).

#### Scenario: Two boards connected

- **WHEN** two boards are connected via USB ECM
- **THEN** the command output contains two rows with distinct `SN` values and distinct host `IFACE` values

#### Scenario: Mixed RockUSB and USB-SSH

- **WHEN** one board is in RockUSB Loader mode and another is running Linux with USB plug-ssh active
- **THEN** `make devices` shows one row with `MODE` Loader (or Maskrom) and one row with `MODE` USB-SSH in the same table

#### Scenario: Registered remote SSH appears with USB-SSH

- **WHEN** one USB-SSH board is plugged in and one remote IP was registered with `make connect`
- **THEN** `make devices` shows both a `USB-SSH` row and an `SSH` row in the same table

### Requirement: SN selects target for push-app

When more than one deployable Linux target is available (USB-SSH and/or registered SSH), **`make push-app`** SHALL require **`SN=`** matching the board **SN**, or **`IP=`** matching a registered **`MODE=SSH`** address. **`IP=`** SHALL NOT select USB-SSH devices. Multi-device selection remains consistent with `scripts/flash-usb.sh` SN ergonomics for USB-SSH. Deprecated **`SERIAL=`** SHALL be accepted as an alias for **`SN=`**. Host tooling MUST NOT accept **`CHIP_ID=`** as a device selector.

#### Scenario: Multiple devices without SN

- **WHEN** two USB-SSH devices are connected and the user runs `make push-app` without `SN` or `IP`
- **THEN** the command fails with a message to run `make devices` and set `SN` or `IP`

#### Scenario: Push with SN

- **WHEN** `SN=<sn> make push-app` is run with multiple devices connected
- **THEN** artifacts are deployed only to the board matching that SN

#### Scenario: Push with IP to SSH device

- **WHEN** a remote SSH device is registered and the user runs `IP=<ip> make push-app`
- **THEN** artifacts are deployed only to that registered SSH address

### Requirement: make reboot-loader enters RockUSB Loader from Linux

The repository SHALL provide **`make reboot-loader`** (`scripts/flash-usb.sh`) so a board running the **Linux HMI image** with **USB plug-ssh active** reboots into **RockUSB Loader** by running **`/usr/bin/reboot-loader`** on the target over the USB network SSH link, then waits until **`upgrade_tool ld`** reports a connected Loader device (existing `wait_for_rockusb` behavior).

#### Scenario: Linux board over USB-SSH

- **WHEN** the board is running Linux, USB debug is active (`192.168.55.1` reachable on `usb0`), and the host runs `make reboot-loader`
- **THEN** the host executes `reboot-loader` on the target via `ssh` and RockUSB Loader appears within the configured timeout

#### Scenario: SN selects board for reboot-loader

- **WHEN** multiple USB-SSH devices are connected and the user runs `SN=<sn> make reboot-loader`
- **THEN** only the board matching that SN receives the reboot command and becomes the RockUSB Loader device

#### Scenario: adb fallback when no USB-SSH target

- **WHEN** `make reboot-loader` runs, no USB-SSH row matches, and `adb` is available with a connected Android device
- **THEN** the host uses `adb reboot loader` (existing behavior) instead of SSH

#### Scenario: Linux without USB-SSH fails clearly

- **WHEN** the board runs Linux, USB plug-ssh is not active, and `adb` is unavailable
- **THEN** `make reboot-loader` fails with a message to connect USB (plug-ssh) or enter MaskROM/Loader manually

#### Scenario: Already in RockUSB Loader

- **WHEN** `make reboot-loader` runs and `make devices` already shows a RockUSB Loader device for the selected `SN`
- **THEN** the command succeeds without sending a reboot (no-op or immediate `wait_for_rockusb` pass)
