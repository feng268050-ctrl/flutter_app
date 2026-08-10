# buildroot-bluez-security Specification

## Purpose
Overlay-owned BlueZ version pin, stock-patch policy, rebuild/verify, coordination with kernel LTS for CVE-2024-8805, optional profile hardening, and residual-risk documentation.

## Requirements

### Requirement: Overlay pins BlueZ userspace at 5.87 or newer

The product SHALL track Buildroot `bluez5_utils` (and matching `bluez5_utils-headers` when packaged separately) under `overlay/buildroot/package/` with `BLUEZ5_UTILS_VERSION` at least **5.87**, or a newer 5.x release locked at implementation time. `make apply-overlay` MUST install that recipe into the SDK Buildroot package tree. The shipped `bluetoothd` / `bluetoothctl` version string MUST match the pin and MUST NOT remain `5.77`.

#### Scenario: apply-overlay syncs BlueZ recipe

- **WHEN** a developer changes the overlay BlueZ package pin and runs `make apply-overlay`
- **THEN** SDK `buildroot/package/bluez5_utils/` reflects the overlay version

#### Scenario: device reports pinned BlueZ

- **WHEN** rootfs built from the pin is deployed
- **THEN** `bluetoothd -v` (or equivalent) reports the pinned version ≥ 5.87

### Requirement: Stock BlueZ D-Bus Device1 contract is preserved

After syncing the upgraded recipe, `apply-overlay` MUST continue to disable Rockchip’s ABI-breaking BlueZ patch (stash/remove `0001-bluez-modified-only-for-rockchip.patch`) so `org.bluez.Device1` Connect/Disconnect remain empty-argument stock methods required by the HMI stack.

#### Scenario: Rockchip BlueZ patch stays stashed

- **WHEN** `make apply-overlay` completes after this change
- **THEN** the Rockchip-only BlueZ Connect(s) patch is not active in the SDK package tree used for the product image

### Requirement: CVE-2024-8805 is closed via kernel LTS, not BlueZ alone

Closing **CVE-2024-8805** (HID / Just-Works adjacent High; kernel alias CVE-2024-53144) SHALL be achieved by shipping a Linux kernel that includes the stable fix (6.1.y ≥ 6.1.115, per `kernel-61-lts-security`). This BlueZ userspace change MUST NOT claim that bumping `bluez5_utils` alone remediates CVE-2024-8805. Implementation tracking MAY land BlueZ and kernel upgrades in either order, but both MUST be done for full remediation of that issue.

#### Scenario: acceptance notes separate kernel vs userspace

- **WHEN** this change’s security acceptance is written
- **THEN** it records BlueZ pin for userspace and explicitly points to the kernel LTS pin for CVE-2024-8805

### Requirement: Optional hardening reduces unused Bluetooth surface

Where the product does not require Phone Book Access / file transfer, the image SHALL disable or omit OBEX (`obexd` not started; prefer Buildroot disable when feasible). Policy files under `/etc/bluetooth/` MAY tighten `JustWorksRepairing` and reconnect UUID lists after a documented UX spike, but MUST NOT remove required Classic HID, BLE HOGP, or opt-in A2DP Sink behaviors defined by `linux-bluetooth`.

#### Scenario: OBEX not running when unused

- **WHEN** hardening tier H1 is applied and PBAP/file transfer are out of product scope
- **THEN** `obexd` is not started as part of normal Bluetooth stack bring-up

### Requirement: Residual postponed CVEs are documented

Acceptance MUST document that Debian-postponed issues without upstream fixes (including AVRCP-related **CVE-2023-44431** while AVRCP remains enabled for A2DP Sink) may still apply after upgrading to 5.87. The change SHALL maximize available upgrades and hardening without claiming complete elimination of those findings.

#### Scenario: PR records residual risk

- **WHEN** the implementing PR is opened
- **THEN** it lists closed/mitigated items (version bump, kernel dependency, hardening applied) and residual postponed CVEs still relevant to enabled profiles

### Requirement: Package rebuild installs new BlueZ binaries

Changing the BlueZ recipe MUST use an explicit package dirclean rebuild (e.g. `scripts/br-make-packages.sh` for `bluez5_utils` and headers) before `make build-rootfs`, so Buildroot stamps do not reuse 5.77 binaries.

#### Scenario: stamp reuse avoided

- **WHEN** developers rebuild after changing `BLUEZ5_UTILS_VERSION`
- **THEN** they run the package dirclean helper for BlueZ before `make build-rootfs`

### Requirement: BlueZ overlay re-syncs after Buildroot LTS bump

After owned Buildroot moves to the pinned **2025.02.x** tip, `make apply-overlay` MUST still install the product BlueZ overlay recipes and MUST continue to stash/disable the Rockchip ABI-breaking BlueZ Connect(s) patch. The first rootfs on the new baseline MUST explicitly dirclean/rebuild `bluez5_utils` (and headers / bluez-alsa as applicable) so 2024.02 stamps are not reused. Version floors and Device1 contract requirements from this capability remain unchanged.

#### Scenario: post-BR-bump BlueZ rebuild preserves Device1

- **WHEN** developers ship the first product rootfs after the Buildroot LTS upgrade
- **THEN** BlueZ packages are rebuilt from the overlay pin, the Rockchip-only Connect(s) patch remains inactive, and `bluetoothd` reports the pinned version ≥ 5.87
