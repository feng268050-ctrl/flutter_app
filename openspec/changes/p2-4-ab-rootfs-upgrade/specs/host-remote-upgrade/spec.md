## ADDED Requirements

### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that selects a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SERIAL=` / `IP=`), transfers a **full-system firmware bundle** that includes at least **`boot.img` and `rootfs.img`** (with digests) from the firmware output, invokes the board apply helper over SSH, and waits until the board returns to SSH after reboot. Default full-system mode MUST update the inactive **boot and rootfs** letter pair (kernel + rootfs). **`make upgrade` MUST NOT** enter RockUSB loader mode or invoke Rockchip `upgrade_tool uf` / `flash-usb.sh` upgrade.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after a successful `make build-img` that produced boot and rootfs images
- **THEN** the inactive boot and rootfs partitions on that board are updated, the board reboots into the new letter, and SSH becomes reachable again without using RockUSB

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the full-system upgrade is performed against that registered IP over SSH without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SERIAL=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SERIAL` or `IP`

### Requirement: Host refuses upgrade when required bundle images are missing

Before transfer, the host upgrade command SHALL verify that required bundle artifacts (`boot.img`, `rootfs.img`, and digests) exist. It SHALL fail fast with a clear error if they are missing (e.g. instruct to run `make build-img`).

#### Scenario: Missing boot.img

- **WHEN** the host runs full-system `make upgrade` and `boot.img` is absent from the expected firmware output path
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `rootfs.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

### Requirement: Host reports apply failure without claiming success

If the board apply returns failure (bad digest, write error, refused userdata touch), the host command SHALL exit non-zero and MUST NOT report a successful letter switch.

#### Scenario: Board rejects bad package

- **WHEN** the host transfers a corrupt payload and the board apply rejects it
- **THEN** `make upgrade` exits non-zero and the board remains on its previous active letter

### Requirement: App-only host mode is available

`make upgrade` SHALL support an app-only mode (e.g. `UPGRADE_MODE=app`) that deploys an application payload to the reserved oem app path without arming a boot/rootfs letter switch. Documentation SHALL distinguish app-only from full-system upgrade (boot+rootfs).

#### Scenario: App-only flag skips letter switch

- **WHEN** the user runs app-only `make upgrade` successfully
- **THEN** the host does not require a boot/rootfs letter reboot cycle for that invocation

### Requirement: Documentation contrasts upgrade vs flash

Host/docs SHALL state that full-system `make upgrade` updates **boot + rootfs** (and optional oem when packaged) over SSH, while **`make flash`** remains required for GPT changes, U-Boot/MiniLoader, and factory reset.

#### Scenario: Help or README mentions kernel in upgrade

- **WHEN** a developer reads Makefile `help` or README Make-commands for `upgrade`
- **THEN** the text indicates full-system upgrade includes the kernel/`boot.img`, not rootfs alone
