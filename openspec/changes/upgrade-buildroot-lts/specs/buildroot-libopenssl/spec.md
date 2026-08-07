## ADDED Requirements

### Requirement: libopenssl overlay re-syncs after Buildroot LTS bump

After owned Buildroot moves to the pinned **2025.02.x** tip, `make apply-overlay` MUST still install the product `overlay/buildroot/package/libopenssl/` recipe into the SDK package tree (including stashing obsolete Rockchip/OpenSSL patches as today). The first rootfs on the new baseline MUST explicitly dirclean/rebuild `libopenssl` so stamps from 2024.02 / vendor 3.2.1 are not reused. Version floors and CVE acceptance requirements from this capability remain unchanged.

#### Scenario: post-BR-bump libopenssl rebuild

- **WHEN** developers ship the first product rootfs after the Buildroot LTS upgrade
- **THEN** `libopenssl` is rebuilt via the explicit package rebuild path and the rootfs/device still reports the overlay-pinned OpenSSL 3.x version (not vendor 3.2.1)
