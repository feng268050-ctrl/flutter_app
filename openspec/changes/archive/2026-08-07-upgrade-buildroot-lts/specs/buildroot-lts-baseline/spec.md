## ADDED Requirements

### Requirement: Product tracks Buildroot 2025.02.x LTS tip

The product SHALL build the appliance rootfs with owned `linux-sdk/buildroot` on the upstream Buildroot **2025.02.x** long-term support line. The locked point release MUST be at least **2025.02.16**, or a newer **2025.02.x** tip chosen at implementation time. The tree MUST NOT remain on **2024.02** after this change is accepted. The product MUST NOT treat the three-month stable series (e.g. 2026.05.x) as the default baseline in this capability.

#### Scenario: BR2_VERSION matches LTS pin

- **WHEN** developers inspect `linux-sdk/buildroot/Makefile` `BR2_VERSION` (or equivalent version stamp) after the upgrade
- **THEN** the value is `2025.02` (or the full `2025.02.<n>` localversion) matching the documented pin and is not `2024.02`

#### Scenario: tip meets floor

- **WHEN** the implementing PR records the locked Buildroot tag
- **THEN** that tag is **≥ 2025.02.16** on the 2025.02.x line

### Requirement: Git-tracked Buildroot version pin for colleagues

Until `linux-sdk/` is committed to git, the repository SHALL record the expected Buildroot LTS tip in a git-tracked pin (e.g. `overlay/buildroot/BUILDROOT_VERSION` containing a single `2025.02.<n>` line) and document it in `docs/linux-sdk-vendor-import.md` (mirroring the kernel `KERNEL_6_1_SUBLEVEL` pattern). Colleagues MUST be able to learn the expected baseline without reading a local SDK tree.

#### Scenario: pin file present in repo

- **WHEN** a developer opens the tracked Buildroot version pin and vendor-import docs after this change
- **THEN** both state the same `2025.02.<n>` expectation

### Requirement: LTS tip is the primary remediation unit

Closing Buildroot infrastructure and default-recipe security/bugfix for the baseline SHALL be achieved by tracking the **2025.02.x LTS tip**, not by maintaining a primary stack of one-off package cherry-picks on frozen 2024.02. Product overlay pins (OpenSSL, GStreamer, BlueZ, Flutter, etc.) remain authoritative for those packages and MAY still bump independently when the LTS tip is insufficient.

#### Scenario: acceptance cites LTS tip not cherry-pick list

- **WHEN** security/acceptance notes for this change are written
- **THEN** they record the locked 2025.02.x tip as the Buildroot baseline and do not claim a short cherry-pick list on 2024.02 as the primary remediation

### Requirement: Major Buildroot bump requires clean output rebuild

After moving from 2024.02 to 2025.02.x, developers MUST discard reusable Buildroot output stamps from the old series (e.g. `make clean-buildroot-output` or equivalent) before `make lunch` and `make build-rootfs`, so packages are not silently reused across the major version boundary. Shipping rootfs MUST be produced from a build on the new baseline.

#### Scenario: clean rebuild path documented and used

- **WHEN** implementers produce the first product rootfs on 2025.02.x
- **THEN** Buildroot output from 2024.02 is cleaned (or otherwise invalidated) before lunch/rootfs, and `scripts/verify-rootfs-overlay.sh` reports PASS on the new image
