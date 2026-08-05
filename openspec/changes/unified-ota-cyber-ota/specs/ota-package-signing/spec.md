## ADDED Requirements

### Requirement: make ota-package builds a tar.gz archive of partition images

The repository SHALL provide **`make ota-package`** that packages the required partition images (`*.img`) and an orchestration `manifest.json` into a **single `tar.gz`** at a documented path under `output/firmware/<APP>/` (default `APP=lws_hmi`). The archive exists to reduce transfer size versus shipping loose images. **`make upgrade` MUST** depend on this target for its default package input (unless an alternate package path such as `UPGRADE_PACKAGE=` is used). Future **`make publish` MUST** use the same package artifact as its prerequisite. The archive MUST NOT contain per-image detached signatures as the trust mechanism.

#### Scenario: ota-package emits tar.gz with images and manifest

- **WHEN** required boot/rootfs (and optional oem) image artifacts exist and the operator runs `APP=<id> make ota-package`
- **THEN** a `tar.gz` exists at the documented output path and contains those `*.img` files plus a manifest

#### Scenario: missing image refuses packaging

- **WHEN** a required image is absent
- **THEN** `make ota-package` exits non-zero and does not publish a package intended for upgrade/publish

#### Scenario: OEM-only package contents

- **WHEN** the operator runs `OEM_ONLY=1 make ota-package` with `oem.img` available
- **THEN** the archive contains oem image (and manifest) without requiring boot/rootfs members for that mode

### Requirement: make ota-package emits a detached Ed25519 signature for cloud and publish

When signing is configured (`OTA_SIGNING_KEY` or documented equivalent), **`make ota-package` SHALL** publish a detached **Ed25519** signature beside the archive (`<archive>.sig`, e.g. `ota-package.tar.gz.sig`). The signature SHALL cover the complete archive bytes (hash-then-sign). This signature is required for **cloud OTA / `make publish`**. **`make upgrade` MUST NOT** require the signature file to exist or be uploaded. Individual partition images are **not** required to have sibling `*.img.sig` files. **`uboot.img` and MiniLoader SHALL NOT** be signed or included by this OTA packaging pipeline.

#### Scenario: package signature emitted when key configured

- **WHEN** `APP=<id> make ota-package` completes successfully with signing configured
- **THEN** both the documented `tar.gz` and its sibling `.sig` exist

#### Scenario: missing signing key refuses publish-oriented packaging

- **WHEN** `OTA_SIGNING_KEY` is unset/unusable and the operator runs packaging for **publish/CI** (or an explicitly signed-package mode)
- **THEN** the command exits non-zero and MUST NOT promote an unsigned archive as the cloud publish artifact

#### Scenario: local upgrade packaging without key may omit signature

- **WHEN** signing is unset and the operator only needs a local `make upgrade` archive
- **THEN** `make ota-package` MAY emit the `tar.gz` without a `.sig`, and `make upgrade` MUST still be able to consume that archive

### Requirement: Device embeds the OTA verification public key

The product rootfs SHALL embed the Ed25519 public key used to verify **cloud** OTA archives at a documented path (default `/etc/ota/ed25519.pub`). The corresponding private key SHALL exist only on the signing/release host (or HSM) and MUST NOT be shipped on the device or committed to git.

#### Scenario: Pubkey present on image

- **WHEN** a built rootfs overlay/image is inspected for OTA materials
- **THEN** the documented pubkey file is present and readable for cloud verify helpers / `cyber_ota`

### Requirement: Cloud apply requires archive signature; host upgrade does not

For **cloud / Settings / product download** ingress, before any partition write the system SHALL require Ed25519 verification of the **complete OTA `tar.gz`** against the device-embedded pubkey and the detached archive `.sig`. Verification MUST succeed **before** extract is treated as trusted input. A cloud channel `sha512` alone MUST NOT authorize writes.

For **host `make upgrade` / HostUploadIngress**, the system SHALL **not** require a `.sig` and SHALL **not** perform Ed25519 verification as a precondition to extract-and-apply.

#### Scenario: Tampered cloud archive refuses apply

- **WHEN** a cloud-downloaded `tar.gz` fails Ed25519 verification against the embedded pubkey
- **THEN** apply refuses to write and exits unsuccessful

#### Scenario: Host upgrade without signature still applies

- **WHEN** `make upgrade` has uploaded an unsigned `tar.gz` under `/userdata/ota/` and host-upload apply runs
- **THEN** the session extracts and writes without requiring Ed25519 success
