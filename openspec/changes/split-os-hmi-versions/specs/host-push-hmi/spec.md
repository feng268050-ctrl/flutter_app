## MODIFIED Requirements

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
