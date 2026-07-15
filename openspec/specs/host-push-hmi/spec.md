# host-push-hmi Specification

## Purpose

Host-side USB-SSH workflow for Flutter app iteration: `make push-app`, `make devices`, `make reboot`, and `make reboot-loader` over the ECM link without rootfs reflash.

## Requirements


### Requirement: make push-app deploys Flutter app over USB SSH

The repository SHALL provide **`make push-app`** that deploys the current Flutter release artifacts to **`/opt/hmi/lib/libapp.so`** and **`/opt/hmi/data/flutter_assets/`** on the target via `scp` over the USB ECM link, then restarts `hmi.service` so the new app loads without rebooting the board. This behavior depends on the kernel DRM GEM teardown fix defined by `hmi-systemd-boot`.

Deployment SHALL stage files under **`/var/lib/lws-hmi/push-app-staging/`**, replace `/opt/hmi` app artifacts while the current HMI remains running, sync storage, then restart `hmi.service`. If the restart does not leave flutter-pi active, the helper SHALL reset the systemd failure state and retry activation a bounded number of times.

#### Scenario: Single device connected

- **WHEN** exactly one USB-SSH device is connected and the host runs `make build-app` followed by `make push-app`
- **THEN** the new `libapp.so` and `flutter_assets` are installed on the target and `hmi.service` is restarted successfully

#### Scenario: Push without rootfs rebuild

- **WHEN** only Dart/assets changed and `make push-app` succeeds
- **THEN** no `make build-rootfs`, `make build-img`, board reboot, or `make flash` is required for the update to take effect

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

### Requirement: Host routes SSH via correct interface

Host scripts SHALL connect to `192.168.55.1` using the network interface associated with the selected device's USB ECM link (e.g. OpenSSH **`BindInterface`** on macOS, **`BindAddress`** on Linux) so multiple devices may share the same target IP.

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

### Requirement: sshpass required for USB-SSH host commands

Host scripts that log in to **`root@192.168.55.1`** over USB-SSH (`make push-app`, **`make reboot`**, **`make reboot-loader`**) SHALL require **`sshpass`** (or future key-based auth) and SHALL print platform-specific install instructions when it is missing.

#### Scenario: push-app without sshpass

- **WHEN** the user runs `make push-app` and `sshpass` is not on `PATH`
- **THEN** the command fails with an error and install hint (e.g. `brew install esolitos/ipa/sshpass` on macOS)

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

## Requirements
### Requirement: make reboot-loader enters RockUSB Loader from Linux

The repository SHALL provide **`make reboot-loader`** (`scripts/flash-usb.sh`) so a board running the **Linux HMI image** with **USB plug-ssh active** reboots into **RockUSB Loader** by running **`/usr/bin/reboot-loader`** on the target over the USB network SSH link, then waits until **`upgrade_tool ld`** reports a connected Loader device (existing `wait_for_rockusb` behavior).

#### Scenario: Linux board over USB-SSH

- **WHEN** the board is running Linux, USB debug is active (`192.168.55.1` reachable on `usb0`), and the host runs `make reboot-loader`
- **THEN** the host executes `reboot-loader` on the target via `ssh` and RockUSB Loader appears within the configured timeout

#### Scenario: SERIAL selects board for reboot-loader

- **WHEN** multiple USB-SSH devices are connected and the user runs `SERIAL=<iSerial> make reboot-loader`
- **THEN** only the board matching that serial receives the reboot command and becomes the RockUSB Loader device

#### Scenario: adb fallback when no USB-SSH target

- **WHEN** `make reboot-loader` runs, no USB-SSH row matches, and `adb` is available with a connected Android device
- **THEN** the host uses `adb reboot loader` (existing behavior) instead of SSH

#### Scenario: Linux without USB-SSH fails clearly

- **WHEN** the board runs Linux, USB plug-ssh is not active, and `adb` is unavailable
- **THEN** `make reboot-loader` fails with a message to connect USB (plug-ssh) or enter MaskROM/Loader manually

#### Scenario: Already in RockUSB Loader

- **WHEN** `make reboot-loader` runs and `make devices` already shows a RockUSB Loader device for the selected `SERIAL`
- **THEN** the command succeeds without sending a reboot (no-op or immediate `wait_for_rockusb` pass)
### Requirement: make reboot-loader ignores remote SSH registry

**`make reboot-loader`** SHALL select only USB-SSH (or adb / already-present RockUSB) targets. When the only Linux target is a registered **`MODE=SSH`** device, the command SHALL fail with guidance to use USB-SSH or enter Loader/MaskROM manually rather than SSHing to the remote IP for `reboot-loader`.

#### Scenario: Only remote SSH registered

- **WHEN** no USB-SSH device is present, a remote SSH IP is registered, and the host runs `make reboot-loader`
- **THEN** the command does not send `reboot-loader` over the SSH registry connection and fails with an actionable message
