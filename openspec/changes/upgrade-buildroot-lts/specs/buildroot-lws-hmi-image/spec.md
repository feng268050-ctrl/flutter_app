## ADDED Requirements

### Requirement: Product rootfs builds on pinned Buildroot 2025.02.x

After this change, `make lunch` / `make build-rootfs` for the lws_hmi profile SHALL run against owned Buildroot whose `BR2_VERSION` matches the product **2025.02.x LTS** pin required by `buildroot-lts-baseline` (not **2024.02**). Existing defconfig composition, overlay verify, and platform package presence requirements remain in force on that baseline.

#### Scenario: rootfs build on LTS baseline

- **WHEN** a developer runs `make apply-overlay` then `make build-rootfs` after the Buildroot LTS upgrade
- **THEN** the build uses the pinned 2025.02.x tree, completes without missing defconfig/package errors attributable to the old 2024.02 baseline, and `scripts/verify-rootfs-overlay.sh` reports PASS
