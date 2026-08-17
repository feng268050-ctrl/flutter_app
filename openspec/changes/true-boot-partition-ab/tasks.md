## 1. U-Boot slot-aware FIT select

- [ ] 1.1 Extend the self-built U-Boot patch path (`patch-uboot-bootcmd.sh` and/or dedicated source patch) so FIT load resolves `boot` vs `boot_b` from misc LWSAB (`try_boot` then `active`; A→`boot`, B→`boot_b`; invalid marker → `boot`)
- [ ] 1.2 Rebuild and publish `prebuilt/bootloader/<uboot_id>/uboot.img` with the existing backup policy (`docs/uboot-rkbin.md`)
- [ ] 1.3 Lab-validate on ynh960 serial: active A loads `boot`; armed `try_boot=B` loads `boot_b`; corrupt marker falls back to `boot`

## 2. Board A/B helpers

- [ ] 2.1 Replace `ab_arm_try_boot_fit` with inactive-letter-only FIT write (`boot` or `boot_b`); remove `boot`→`boot_b` backup
- [ ] 2.2 Change `ab-boot-confirm` rollback to misc-only restore of previous letter; remove / stop calling `ab_swap_boot_partitions`
- [ ] 2.3 Grep overlay helpers/tests for backup/swap assumptions and update `verify-rootfs-overlay` checks if they assert old behavior

## 3. cyber_ota apply path

- [ ] 3.1 Update Dart apply (`ota_apply.dart` / `ab_slot.dart`) to write the inactive FIT only to the inactive boot partition; delete `backupBootToBootB` usage
- [ ] 3.2 Align write-phase progress with “no backup copy” (kernel phase is solely inactive FIT `dd`)
- [ ] 3.3 Add/adjust package unit tests for inactive boot target selection (A vs B) and rollback without swap

## 4. Docs and operator notes

- [ ] 4.1 Rewrite `docs/ab-slot-misc.md` partition-naming / try-boot / rollback sections for U-Boot partition select; remove “vendor always loads boot” as the product contract
- [ ] 4.2 Update `docs/storage-layout.md` / upgrade acceptance notes for inactive-boot write and one-time new-U-Boot flash gate
- [ ] 4.3 Fix stray comments (`patch-uboot-bootcmd.sh`, `build-img.sh`, AGENTS rebuild notes if they still describe backup/swap)

## 5. Acceptance

- [ ] 5.1 Flash slot-aware U-Boot, then run staged OTA A→B: commit; confirm `/proc/cmdline` PARTLABEL and that U-Boot loaded `boot_b` (not a swapped `boot`)
- [ ] 5.2 Staged OTA B→A commit on the same unit
- [ ] 5.3 Force unhealthy try-boot rollback: misc returns to previous letter, no partition content swap, previous FIT still boots
- [ ] 5.4 Confirm RockUSB/`make flash` still writes both boot letters correctly and cold-boots letter A by default
