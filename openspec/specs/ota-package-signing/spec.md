# ota-package-signing Specification

## Purpose
Host `make pack-ota` tar.gz + Ed25519 detached `.sig`, and device pubkey at `/etc/ota/ed25519.pub`.

## Requirements
### Requirement: make pack-ota builds a tar.gz archive of partition images

The repository SHALL provide **`make pack-ota`** that packages the required partition images (`*.img`) and an orchestration `manifest.json` into a **single `tar.gz`** at a documented path under `output/firmware/<APP>/` (default `APP=lws_hmi`). The archive exists to reduce transfer size versus shipping loose images. **`make upgrade` MUST** depend on this target for its default package input (unless an alternate package path such as `UPGRADE_PACKAGE=` is used). Future **`make publish` MUST** use the same package artifact as its prerequisite. The archive MUST NOT contain per-image detached signatures as the trust mechanism.

#### Scenario: pack-ota emits tar.gz with images and manifest

- **WHEN** required boot/rootfs (and optional oem) image artifacts exist and the operator runs `APP=<id> make pack-ota` with signing configured
- **THEN** a `tar.gz` exists at the documented output path and contains those `*.img` files plus a manifest

#### Scenario: missing image refuses packaging

- **WHEN** a required image is absent
- **THEN** `make pack-ota` exits non-zero and does not publish a package intended for upgrade/publish

#### Scenario: OEM-only package contents

- **WHEN** the operator runs `OEM_ONLY=1 make pack-ota` with `oem.img` available and signing configured
- **THEN** the archive contains oem image (and manifest) without requiring boot/rootfs members for that mode

### Requirement: make pack-ota emits a detached Ed25519 signature for upgrade, cloud, and publish

When signing is configured (`OTA_SIGNING_KEY` or documented equivalent), **`make pack-ota` SHALL** publish a detached **Ed25519** signature beside the archive (`<archive>.sig`, e.g. `ota-package.tar.gz.sig`). The signature SHALL cover the complete archive bytes (hash-then-sign). This signature is required for **USB-SSH/SSH `make upgrade`**, **cloud OTA**, and **`make publish`**. Individual partition images are **not** required to have sibling `*.img.sig` files. **`uboot.img` and MiniLoader SHALL NOT** be signed or included by this OTA packaging pipeline.

#### Scenario: package signature emitted when key configured

- **WHEN** `APP=<id> make pack-ota` completes successfully with signing configured
- **THEN** both the documented `tar.gz` and its sibling `.sig` exist

#### Scenario: missing signing key refuses packaging for upgrade or publish

- **WHEN** `OTA_SIGNING_KEY` is unset/unusable and the operator runs `make pack-ota` (default packaging used by SSH `make upgrade` or publish/CI)
- **THEN** the command exits non-zero and MUST NOT promote an unsigned archive as the upgrade/publish artifact

### Requirement: Device embeds the OTA verification public key

The product rootfs SHALL embed the Ed25519 public key used to verify OTA archives (cloud and host HTTP pull) at a documented path (default `/etc/ota/ed25519.pub`). The corresponding private key SHALL exist only on the signing/release host (or HSM) and MUST NOT be shipped on the device or committed to git.

#### Scenario: Pubkey present on image

- **WHEN** a built rootfs overlay/image is inspected for OTA materials
- **THEN** the documented pubkey file is present and readable for verify helpers / `cyber_ota`

### Requirement: Staged apply (cloud and host SSH HTTP) requires archive signature

For **cloud / Settings / product download** and for **host USB-SSH/SSH `make upgrade` / HostHttpIngress**, before any partition write the system SHALL require Ed25519 verification of the **complete OTA `tar.gz`** against the device-embedded pubkey and the detached archive `.sig`. Verification MUST succeed **before** extract is treated as trusted input. A cloud channel `sha512` alone MUST NOT authorize writes.

RockUSB `di` / `make flash` remain outside this signature gate.

#### Scenario: Tampered archive refuses apply

- **WHEN** a staged `tar.gz` (cloud or host HTTP) fails Ed25519 verification against the embedded pubkey
- **THEN** apply refuses to write and exits unsuccessful

#### Scenario: Host upgrade without signature refuses apply

- **WHEN** `make upgrade` over SSH lacks a usable `.sig` beside the archive (or verification fails)
- **THEN** the session MUST NOT extract-and-write partitions successfully

### Requirement: Peripheral firmware blobs use the same Ed25519 trust root

Detached Ed25519 signatures for control-board `.bin` and camera `.zip` payloads (host HTTP helpers and cloud publish/download) SHALL use the **same** signing tooling wire format and device-embedded public key as system OTA archives (`ota-sign.sh` / `OTA_SIGNING_KEY` on the host; `/etc/ota/ed25519.pub` on device).

Before Modbus or CGI apply of a host-downloaded or cloud-downloaded peripheral payload, the system SHALL require successful Ed25519 verification of the complete file bytes against that pubkey and the sibling `.sig`. A channel manifest field alone MUST NOT authorize apply.

#### Scenario: Tampered peripheral blob refuses apply

- **WHEN** a staged control-board `.bin` or camera `.zip` fails Ed25519 verification against the embedded pubkey
- **THEN** peripheral apply refuses to start Modbus or CGI flash
- **AND** exits unsuccessful

#### Scenario: Same pubkey verifies system OTA and peripherals

- **WHEN** a rootfs image is inspected for OTA materials
- **THEN** the documented `/etc/ota/ed25519.pub` (or equivalent) is the trust root used for both system OTA `tar.gz` and peripheral firmware blob verification
