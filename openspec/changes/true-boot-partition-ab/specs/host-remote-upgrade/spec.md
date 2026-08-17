## MODIFIED Requirements

### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that selects a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SN=` / `IP=`), **first ensures an OTA `tar.gz` and sibling `.sig` via `make pack-ota`** (unless an alternate package input is documented elsewhere), starts an **ephemeral host HTTP server** that serves the archive and `.sig`, triggers the on-device HMI to **HTTP download** those files into **`/userdata/ota/`**, runs the **staged verify-extract-apply** pipeline shared with product OTA (**MUST** Ed25519-verify before write), and returns successfully as soon as board reboot-after-arm is requested. It SHALL NOT wait for SSH disconnect, post-reboot SSH, or claim that boot health was verified.

For the SSH path, the host SHALL: obtain the `tar.gz` and `.sig`; preflight the active/inactive letter and refuse unsafe slot state; bind HTTP on an address the device can reach (USB-SSH default `192.168.55.2`, LAN: local source IP toward the board, overridable via `OTA_HTTP_HOST=` / `OTA_HTTP_PORT=`); trigger the on-device HMI to enter the dedicated upgrade page and download; report **HTTP send** progress on the host console until archive + `.sig` are fully served (`TRANSFER_COMPLETE`); then exit successfully without waiting for on-device apply. On-device **`cyber_ota`** SHALL verify, extract, and burn via Dart-orchestrated `openssl`/`tar`/`dd`, writing the inactive rootfs and the inactive letter’s FIT to that letter’s boot partition only (no `boot`→`boot_b` backup). Default full-system mode MUST update the inactive **boot and rootfs** letter pair. SSH SHALL be used as a **control plane** (trigger + transfer complete), not as the bulk transfer path for the OTA archive.

**`make upgrade` MUST** stage the OTA package under `/userdata/ota/` (unlike the retired stream-to-partition default). **`make upgrade` MUST NOT** enter RockUSB loader mode or invoke Rockchip `upgrade_tool uf` / `flash-usb.sh` upgrade for the SSH path. For USB-SSH/SSH, **`make upgrade` MUST** require device verification of the Ed25519 `.sig`.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs via staged apply with verify

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after packaging with a signature
- **THEN** the device HTTP-downloads `tar.gz` and `.sig` from the host into `/userdata/ota/`, on-device verify-extract-apply writes the inactive rootfs and the inactive letter’s boot partition after successful Ed25519 verification, the board requests reboot without using RockUSB, and the command returns as soon as reboot-after-arm is started

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the packaged host-HTTP + device-pull (archive + `.sig`) + staged verify-apply full-system upgrade is performed against that registered IP without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SN=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SN` or `IP`
