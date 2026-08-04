## ADDED Requirements

### Requirement: Build targets produce Ed25519 detached signatures for partition images

`make build-kernel`, `make build-rootfs`, and `make build-oem` (and any other documented target that publishes a whole-device upgrade partition image under `output/firmware/` or `oem/out/`) SHALL, on successful image publish, also publish a detached **Ed25519** signature file beside each signed image using the naming pattern `<image>.sig` for `<image>` (e.g. `rootfs.img.sig` next to `rootfs.img`). The signature SHALL cover the complete image bytes (hash-then-sign). **`uboot.img` and MiniLoader artifacts SHALL NOT** be signed by this repository pipeline (vendor-provided; flash-only).

#### Scenario: rootfs build emits signature

- **WHEN** `APP=<id> make build-rootfs` completes successfully with signing configured
- **THEN** `output/firmware/<id>/rootfs.img` and `output/firmware/<id>/rootfs.img.sig` both exist

#### Scenario: kernel FITs emit signatures

- **WHEN** `make build-kernel` completes successfully with signing configured
- **THEN** each published `boot.img` and `boot_b.img` under `output/firmware/` has a matching `*.img.sig`

#### Scenario: oem build emits signature

- **WHEN** `make build-oem` completes successfully with signing configured
- **THEN** the resolved `oem.img` has a sibling `oem.img.sig`

#### Scenario: uboot remains unsigned by this pipeline

- **WHEN** a developer inspects signing outputs after a normal firmware build
- **THEN** no requirement forces this pipeline to emit an Ed25519 sig for vendor `uboot.img`

### Requirement: make ota-package packs signed images into one zip

The repository SHALL provide **`make ota-package`** that packages the required signed partition images (`*.img` + sibling `*.img.sig`) and an orchestration `manifest.json` into a **single compressed zip** at a documented path under `output/firmware/<APP>/` (default `APP=lws_hmi`). The package exists to reduce storage and transfer size versus shipping loose images. **`make upgrade` MUST** depend on this target. Future **`make publish` MUST** use the same package artifact as its prerequisite (publish implementation MAY be out of this change’s coding scope but the contract SHALL be documented). Zip integrity alone MUST NOT authorize writes; trust remains per-image Ed25519 signatures after extract.

#### Scenario: ota-package emits zip with images and signatures

- **WHEN** required signed boot/rootfs (and optional oem) artifacts exist and the operator runs `APP=<id> make ota-package`
- **THEN** a zip exists at the documented output path and contains those `*.img` / `*.img.sig` files plus a manifest

#### Scenario: missing signature refuses packaging

- **WHEN** a required image lacks its sibling `.img.sig`
- **THEN** `make ota-package` exits non-zero and does not publish a package intended for upgrade/publish

#### Scenario: OEM-only package contents

- **WHEN** the operator runs `OEM_ONLY=1 make ota-package` with signed `oem.img` available
- **THEN** the zip contains oem image + signature (and manifest) without requiring boot/rootfs members for that mode

### Requirement: Device embeds the OTA verification public key

The product rootfs SHALL embed the Ed25519 public key used to verify OTA partition images at a documented path (default `/etc/hmi/ota-ed25519.pub`). The corresponding private key SHALL exist only on the signing/release host (or HSM) and MUST NOT be shipped on the device or committed to git.

#### Scenario: Pubkey present on image

- **WHEN** a built rootfs overlay/image is inspected for OTA materials
- **THEN** the documented pubkey file is present and readable for verify helpers / `cyber_ota`

### Requirement: Manifest is not the trust root

If an OTA `manifest.json` is used for version UX and file lists (including inside the OTA zip), the system SHALL still require per-image Ed25519 verification before any partition write. A crafted or unsigned digest/manifest, or an intact zip with a bad member signature, MUST NOT authorize writing images.

#### Scenario: Tampered manifest cannot skip sigs

- **WHEN** a manifest lists images but one listed image fails Ed25519 verify
- **THEN** apply refuses to write and exits unsuccessful
