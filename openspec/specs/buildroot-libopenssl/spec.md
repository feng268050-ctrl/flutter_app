# buildroot-libopenssl Specification

## Purpose
Overlay-owned Buildroot `libopenssl` version pin, CVE High/Critical acceptance bar, apply-overlay sync, package rebuild hygiene, and rootfs/device verification for system `libssl.so.3` / `libcrypto.so.3`.

## Requirements

### Requirement: Overlay pins a secure libopenssl version

The product SHALL track Buildroot `libopenssl` under `overlay/buildroot/package/libopenssl/` (recipe `.mk`, `.hash`, and any required patches/`Config.in` deltas). `make apply-overlay` MUST install that recipe into the SDK Buildroot package tree so colleagues do not depend on hand-edits under gitignored `linux-sdk/`. The pinned OpenSSL version MUST be chosen from the design ladder: preferred **OpenSSL 3.5 LTS ≥ 3.5.5** (or newer 3.5.x security release), else **OpenSSL 3.0 LTS ≥ 3.0.19**, else last-resort **OpenSSL ≥ 3.2.6** with an explicit follow-up to leave EOL 3.2. The shipped libraries MUST remain `libssl.so.3` / `libcrypto.so.3` (OpenSSL 3.x). Enabling the `openssl` CLI is NOT required by this capability.

#### Scenario: apply-overlay syncs libopenssl recipe

- **WHEN** a developer changes `overlay/buildroot/package/libopenssl/` and runs `make apply-overlay`
- **THEN** the SDK `buildroot/package/libopenssl/` tree reflects the overlay pin (version in `.mk` matches overlay)

#### Scenario: pin is not vendor 3.2.1

- **WHEN** the active overlay `libopenssl.mk` is inspected after this change
- **THEN** `LIBOPENSSL_VERSION` is not `3.2.1` and meets the design ladder floor for the chosen release line

### Requirement: High and Critical OpenSSL CVEs are closed for the shipped version

Before the change is accepted, the pinned OpenSSL version MUST have **no unpatched NVD Critical or High** vulnerabilities that affect that version, and **no unpatched OpenSSL-advisory High** issues that affect that version. Verification MUST cite NVD and/or OpenSSL vendor advisories for the exact pinned version (check date recorded in the implementing PR). Issues that do not affect the pinned line (e.g. CVE-2025-15467 on non-3.2 lines when shipping 3.2.6, or non-OpenSSL CVEs misattributed in search results) MUST NOT block acceptance.

#### Scenario: advisory re-check passes

- **WHEN** implementers complete the rootfs bump to the pinned version
- **THEN** a recorded advisory check for that version reports zero applicable NVD Critical/High and zero applicable OpenSSL High findings

### Requirement: Rootfs rebuild installs the new libopenssl binaries

Changing the `libopenssl` recipe MUST go through an explicit package rebuild that dircleans the package (e.g. `scripts/br-make-packages.sh` for `libopenssl`) before `make build-rootfs`, so Buildroot stamps do not reuse `3.2.1` binaries. After deploy, the running system or inspected rootfs MUST show the pinned OpenSSL version string in `libcrypto.so.3` (and `libssl.so.3` when present).

#### Scenario: device or rootfs shows pinned version

- **WHEN** the upgraded image is inspected on device (or the built rootfs `target/` tree)
- **THEN** `libcrypto.so.3` version metadata matches the overlay pin (not `OpenSSL 3.2.1 30 Jan 2024`)

#### Scenario: stamp reuse is avoided

- **WHEN** developers rebuild after changing `LIBOPENSSL_VERSION`
- **THEN** they run the package dirclean rebuild helper for `libopenssl` before `make build-rootfs` (documented in change tasks / AGENTS rebuild table if a new helper name is introduced)

### Requirement: libopenssl overlay re-syncs after Buildroot LTS bump

After owned Buildroot moves to the pinned **2025.02.x** tip, `make apply-overlay` MUST still install the product `overlay/buildroot/package/libopenssl/` recipe into the SDK package tree (including stashing obsolete Rockchip/OpenSSL patches as today). The first rootfs on the new baseline MUST explicitly dirclean/rebuild `libopenssl` so stamps from 2024.02 / vendor 3.2.1 are not reused. Version floors and CVE acceptance requirements from this capability remain unchanged.

#### Scenario: post-BR-bump libopenssl rebuild

- **WHEN** developers ship the first product rootfs after the Buildroot LTS upgrade
- **THEN** `libopenssl` is rebuilt via the explicit package rebuild path and the rootfs/device still reports the overlay-pinned OpenSSL 3.x version (not vendor 3.2.1)
