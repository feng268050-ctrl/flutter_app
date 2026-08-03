## ADDED Requirements

### Requirement: Kernel FIT ships pinned 6.1 LTS version

Product firmware images that include the kernel FIT (`boot.img` / `boot_b.img`) SHALL embed a Linux kernel whose release string is the documented 6.1.y LTS pin from `kernel-61-lts-security` (minimum `6.1.180`, not `6.1.99`). Rootfs module directories shipped with that image MUST match the same kernel ABI/release as the FIT.

#### Scenario: uname after factory or upgrade image

- **WHEN** a ynh960 board boots a firmware image built after this change (via flash or A/B upgrade)
- **THEN** `uname -r` reports the pinned `6.1.<tip>` and loadable product modules match that release
