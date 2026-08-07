## ADDED Requirements

### Requirement: BlueZ overlay re-syncs after Buildroot LTS bump

After owned Buildroot moves to the pinned **2025.02.x** tip, `make apply-overlay` MUST still install the product BlueZ overlay recipes and MUST continue to stash/disable the Rockchip ABI-breaking BlueZ Connect(s) patch. The first rootfs on the new baseline MUST explicitly dirclean/rebuild `bluez5_utils` (and headers / bluez-alsa as applicable) so 2024.02 stamps are not reused. Version floors and Device1 contract requirements from this capability remain unchanged.

#### Scenario: post-BR-bump BlueZ rebuild preserves Device1

- **WHEN** developers ship the first product rootfs after the Buildroot LTS upgrade
- **THEN** BlueZ packages are rebuilt from the overlay pin, the Rockchip-only Connect(s) patch remains inactive, and `bluetoothd` reports the pinned version ≥ 5.87
