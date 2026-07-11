## ADDED Requirements

### Requirement: make push-app deploys Flutter app over USB SSH

The repository SHALL provide **`make push-app`** that deploys the current Flutter release artifacts to **`/opt/hmi/lib/libapp.so`** and **`/opt/hmi/data/flutter_assets/`** on the target via `scp` over the USB ECM link, then restarts **`hmi.service`** via `ssh`.

#### Scenario: Single device connected

- **WHEN** exactly one USB-SSH device is connected and the host runs `make build-app` followed by `make push-app`
- **THEN** the new `libapp.so` and `flutter_assets` are on the target and `hmi.service` is active after restart

#### Scenario: Push without rootfs rebuild

- **WHEN** only Dart/assets changed and `make push-app` succeeds
- **THEN** no `make build-rootfs` or `make flash` is required for the update to take effect

### Requirement: make devices lists RockUSB and USB-SSH targets

The repository SHALL extend **`make devices`** to list **both** RockUSB flash devices (`upgrade_tool ld`) and USB-SSH boards in a **single merged table** with a **`MODE`** column (`Loader`, `Maskrom`, `USB-SSH`, etc.) and columns including **`SERIAL`**, **`LocationID`**, host **`IFACE`** (USB-SSH only), and target **`ADDR`** (`192.168.55.1` for USB-SSH). There SHALL NOT be a separate **`make devices-usb-ssh`** target.

#### Scenario: Two boards connected

- **WHEN** two boards are connected via USB ECM
- **THEN** the command output contains two rows with distinct `SERIAL` values and distinct host `IFACE` values

#### Scenario: Mixed RockUSB and USB-SSH

- **WHEN** one board is in RockUSB Loader mode and another is running Linux with USB plug-ssh active
- **THEN** `make devices` shows one row with `MODE` Loader (or Maskrom) and one row with `MODE` USB-SSH in the same table

### Requirement: SERIAL selects target for push-app

When more than one USB-SSH device is connected, **`make push-app`** SHALL require **`SERIAL=`** (or **`LWS_HMI_SERIAL=`**) matching the gadget `iSerial`, consistent with `scripts/flash-usb.sh` multi-device behavior.

#### Scenario: Multiple devices without SERIAL

- **WHEN** two USB-SSH devices are connected and the user runs `make push-app` without `SERIAL`
- **THEN** the command fails with a message to run `make devices` and set `SERIAL`

#### Scenario: Push with SERIAL

- **WHEN** `SERIAL=<iSerial> make push-app` is run with multiple devices connected
- **THEN** artifacts are deployed only to the board matching that serial

### Requirement: Host routes SSH via correct interface

Host scripts SHALL connect to `192.168.55.1` using the network interface associated with the selected device's USB ECM link (e.g. OpenSSH **`BindInterface`**) so multiple devices may share the same target IP.

#### Scenario: BindInterface used for multi-device

- **WHEN** two devices are connected and `SERIAL=` selects one device
- **THEN** `scp` and `ssh` traffic for `push-app` egress only via that device's host interface

### Requirement: Host configures link-local address

Before `scp`/`ssh`, host scripts SHALL assign **`192.168.55.2/24`** to the host side of the USB ECM interface if not already configured.

#### Scenario: First push after plug

- **WHEN** the host interface for a device is up but has no address in `192.168.55.0/24`
- **THEN** `push-app` configures `192.168.55.2/24` on that interface before connecting

### Requirement: push-app waits for device readiness

`make push-app` SHALL retry reachability to `192.168.55.1` on the selected interface for at least 30 seconds before failing, to tolerate gadget bring-up delay after plug.

#### Scenario: Device not yet ready

- **WHEN** the user runs `make push-app` immediately after plugging in USB
- **THEN** the script waits until the target responds or times out with an actionable error

### Requirement: make bootloader enters RockUSB Loader from Linux

The repository SHALL extend **`make bootloader`** (`scripts/flash-usb.sh`) so a board running the **Linux HMI image** with **USB plug-ssh active** reboots into **RockUSB Loader** by running **`/usr/lib/lws-hmi/reboot-rockusb-loader`** on the target over the USB ECM SSH link, then waits until **`upgrade_tool ld`** reports a connected Loader device (existing `wait_for_rockusb` behavior).

#### Scenario: Linux board over USB-SSH

- **WHEN** the board is running Linux, USB debug is active (`192.168.55.1` reachable on `usb0`), and the host runs `make bootloader`
- **THEN** the host executes `reboot-rockusb-loader` on the target via `ssh` and RockUSB Loader appears within the configured timeout

#### Scenario: SERIAL selects board for bootloader

- **WHEN** multiple USB-SSH devices are connected and the user runs `SERIAL=<iSerial> make bootloader`
- **THEN** only the board matching that serial receives the reboot command and becomes the RockUSB Loader device

#### Scenario: adb fallback when no USB-SSH target

- **WHEN** `make bootloader` runs, no USB-SSH row matches, and `adb` is available with a connected Android device
- **THEN** the host uses `adb reboot loader` (existing behavior) instead of SSH

#### Scenario: Linux without USB-SSH fails clearly

- **WHEN** the board runs Linux, USB plug-ssh is not active, and `adb` is unavailable
- **THEN** `make bootloader` fails with a message to connect USB (plug-ssh) or enter MaskROM/Loader manually

#### Scenario: Already in RockUSB Loader

- **WHEN** `make bootloader` runs and `make devices` already shows a RockUSB Loader device for the selected `SERIAL`
- **THEN** the command succeeds without sending a reboot (no-op or immediate `wait_for_rockusb` pass)
