## MODIFIED Requirements

### Requirement: Rootfs overlay ships A/B upgrade helpers

The lws_hmi rootfs overlay SHALL include the board full-system apply/confirm helpers (scripts and any systemd units required by `ab-firmware-slots`), including support for **Ed25519-verified staged apply** of **boot and rootfs** on the inactive letter (and optional signed oem), progress status suitable for HMI/`cyber_ota` burn callbacks, and refuse of unsigned or failed-signature bundles. `scripts/verify-rootfs-overlay.sh` SHALL fail if those helpers are missing from the staging target after `make build-rootfs`.

#### Scenario: verify finds upgrade helpers

- **WHEN** `make build-rootfs` completes successfully after this change
- **THEN** `verify-rootfs-overlay.sh` reports PASS including A/B upgrade helper presence checks

#### Scenario: Helpers gate on signatures

- **WHEN** staged apply is invoked with a required image missing a valid `*.img.sig`
- **THEN** the helper refuses to write partitions and exits non-zero

## ADDED Requirements

### Requirement: Rootfs embeds OTA Ed25519 public key

The product rootfs SHALL install the OTA verification public key at the documented path (default `/etc/hmi/ota-ed25519.pub`) via overlay or package so on-device verify in staged apply / `cyber_ota` can succeed for images signed by the matching release private key. The private key MUST NOT be present in the rootfs.

#### Scenario: Pubkey installed in overlay target

- **WHEN** `make build-rootfs` (or overlay verify) runs after this change
- **THEN** the staging/rootfs contains the documented OTA pubkey file and does not contain the OTA private key
