# host-push-hmi Specification

## Purpose

Host-side USB-SSH workflow for Flutter app iteration: `make push-app`, `make devices`, `make reboot`, and `make reboot-loader` over the ECM link without rootfs reflash.
## Requirements
### Requirement: make push-app deploys Flutter app over USB SSH

The repository SHALL provide **`make push-app` as a Make alias of `make upgrade-app`** (see `host-app-upgrade`). Both names SHALL use the signed path: package/sign `tar.gz`, host HTTP serve, device `download <url>`, Ed25519 verify, install to `/opt/hmi`, restart `hmi.service`. The former unsigned SCP / `/var/lib/hmi/push-app-staging/` hot-swap bulk-transfer path MUST be removed. Updating `/opt/hmi` without rebuilding rootfs SHALL still not require `make build-rootfs`, `make build-img`, board reboot, or `make flash`.

#### Scenario: Supported iteration without rootfs rebuild

- **WHEN** only Dart/assets changed and `make build-app` then `make push-app` (or `make upgrade-app`) succeeds
- **THEN** the new app is installed on the target and `hmi.service` is restarted
- **AND** no `make build-rootfs`, `make build-img`, board reboot, or `make flash` is required for the update to take effect

#### Scenario: push-app does not use unsigned SCP

- **WHEN** the operator runs `make push-app` with signing configured
- **THEN** the transfer uses host HTTP + device download of the signed archive
- **AND** MUST NOT SCP `libapp.so` / `flutter_assets` as the bulk path

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

When more than one deployable Linux target is available (USB-SSH and/or registered SSH), **`make upgrade-app`** and its alias **`make push-app`** SHALL require **`SN=`** matching the board **SN**, or **`IP=`** matching a registered **`MODE=SSH`** address. **`IP=`** SHALL NOT select USB-SSH devices. Multi-device selection remains consistent with `scripts/flash-usb.sh` SN ergonomics for USB-SSH. Deprecated **`SERIAL=`** SHALL be accepted as an alias for **`SN=`**. Host tooling MUST NOT accept **`CHIP_ID=`** as a device selector.

#### Scenario: Multiple devices without SN

- **WHEN** two USB-SSH devices are connected and the user runs `make upgrade-app` or `make push-app` without `SN` or `IP`
- **THEN** the command fails with a message to run `make devices` and set `SN` or `IP`

#### Scenario: Upgrade with SN

- **WHEN** `SN=<sn> make push-app` is run with multiple devices connected
- **THEN** the download/install is triggered only on the board matching that SN

#### Scenario: Upgrade with IP to SSH device

- **WHEN** a remote SSH device is registered and the user runs `IP=<ip> make upgrade-app`
- **THEN** the session targets only that registered SSH address

### Requirement: Host routes SSH via correct interface

Host scripts SHALL connect to `192.168.55.1` using the network interface associated with the selected device's USB ECM link (e.g. OpenSSH **`BindInterface`** on macOS, **`BindAddress`** on Linux) so multiple devices may share the same target IP.

#### Scenario: BindInterface used for multi-device

- **WHEN** two devices are connected and `SN=` selects one device
- **THEN** `scp` and `ssh` traffic for `push-app` egress only via that device's host interface

### Requirement: Host configures link-local address

Before `scp`/`ssh`, host scripts SHALL assign **`192.168.55.2/24`** to the host side of the USB ECM interface if not already configured.

#### Scenario: First push after plug

- **WHEN** the host interface for a device is up but has no address in `192.168.55.0/24`
- **THEN** `push-app` configures `192.168.55.2/24` on that interface before connecting

### Requirement: push-app waits for device readiness

`make upgrade-app` / `make push-app` SHALL retry reachability to the selected target (including `192.168.55.1` on the selected USB-SSH interface) for at least 30 seconds before failing, to tolerate gadget bring-up delay after plug.

#### Scenario: Device not yet ready

- **WHEN** the user runs `make push-app` immediately after plugging in USB
- **THEN** the script waits until the target responds or times out with an actionable error

### Requirement: sshpass required for USB-SSH host commands

Host scripts that log in to **`root@192.168.55.1`** over USB-SSH (`make upgrade-app`, `make push-app`, **`make reboot`**, **`make reboot-loader`**) SHALL require **`sshpass`** (or future key-based auth) and SHALL print platform-specific install instructions when it is missing.

#### Scenario: push-app without sshpass

- **WHEN** the user runs `make push-app` and `sshpass` is not on `PATH`
- **THEN** the command fails with an error and install hint (e.g. `brew install esolitos/ipa/sshpass` on macOS)

### Requirement: make reboot triggers normal board reset

The repository SHALL provide **`make reboot`** that reboots a connected board **without** entering RockUSB Loader: Linux HMI via USB-SSH or registered remote SSH (**sysrq reboot**); Android via **`adb reboot`**. **`make reboot-loader`** is the Loader entry path and SHALL NOT use registered **`MODE=SSH`** devices.

#### Scenario: Linux board over USB-SSH

- **WHEN** the board is running Linux with USB debug active and the host runs `make reboot`
- **THEN** the host schedules sysrq reboot on the target and returns without waiting for boot to complete

#### Scenario: Linux board over registered SSH

- **WHEN** a remote SSH device is registered (and selected by default or via `IP=` / `SN=`) and the host runs `make reboot`
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
### Requirement: make reboot-loader ignores remote SSH registry

**`make reboot-loader`** SHALL select only USB-SSH (or adb / already-present RockUSB) targets. When the only Linux target is a registered **`MODE=SSH`** device, the command SHALL fail with guidance to use USB-SSH or enter Loader/MaskROM manually rather than SSHing to the remote IP for `reboot-loader`.

#### Scenario: Only remote SSH registered

- **WHEN** no USB-SSH device is present, a remote SSH IP is registered, and the host runs `make reboot-loader`
- **THEN** the command does not send `reboot-loader` over the SSH registry connection and fails with an actionable message
