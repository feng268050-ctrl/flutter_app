## 1. GPT / storage / paired boot+rootfs selection

- [x] 1.1 Update `board/parameter-buildroot-fit.txt` to vendor-compatible `boot`/`boot_b` + `rootfs_a`/`rootfs_b`; shift oem/private*/userdata
- [x] 1.2 Rewrite `docs/storage-layout.md` for paired A/B, upgrade-vs-flash matrix (boot+rootfs+optional oem vs uboot/GPT), prefs policy
- [x] 1.3 Spike misc slot-letter format (active/try/previous); document offsets
- [x] 1.4 Update boot chain / kernel root selection so each hash-valid FIT selects matching `rootfs_*` (PARTLABEL); keep the loaded partition named `boot` for vendor U-Boot
- [x] 1.5 Confirm vendor U-Boot cannot select `boot_a`/`boot_b`; implement `boot` backup/staging via `boot_b` without rebuilding U-Boot
- [x] 1.6 Extend `verify-firmware-partitions.sh` + build-img/package-file so `boot.img`/`rootfs.img` are gated per slot and factory image populates both letters

## 2. Board apply / confirm / rollback

- [x] 2.1 Add overlay helpers to resolve inactive letter `by-partlabel` nodes and read/write misc letter + try-boot state
- [x] 2.2 Implement full-system apply: stage `/userdata/ota/` bundle → write inactive **boot then rootfs** (+ optional oem) → verify digests → arm try-boot → reboot; refuse userdata wipe and uboot writes
- [x] 2.3 Add `lws-hmi-ab-boot-confirm` oneshot/unit: commit letter on healthy boot or revert letter pair and reboot
- [x] 2.5 Wire helpers into fs-overlay; extend `verify-rootfs-overlay.sh` for helper presence and upgrade-path safety checks
- [x] 2.6 Derive the active letter from the block device mounted as `/`; reject pending/stale misc state and hard-refuse any write to the mounted root device

## 3. Host `make upgrade`

- [x] 3.1 Add `scripts/upgrade-remote.sh` reusing push-app SSH/`SERIAL=`/`IP=`; transfer **boot.img + rootfs.img** (+ digests/manifest); invoke board apply; return when reboot starts/SSH drops (do not wait for post-reboot SSH)
- [x] 3.2 Add Makefile `upgrade` target + `help` stating full-system includes kernel/`boot.img`; must not call RockUSB `uf`
- [x] 3.4 Fail fast when boot or rootfs artifacts missing; propagate board apply failures
- [x] 3.5 Update README Make commands + AGENTS rebuild table for parameter/upgrade (boot+rootfs) paths

## 4. Docs / plan / acceptance

- [x] 4.1 Keep `docs/flutter-pi-hmi-plan.md` P2.4 / §1.3 aligned with boot+rootfs remote upgrade (already updated in redesign; refresh status when done)
- [x] 4.2 Device acceptance: one-time `make flash` with new GPT → boot letter A → change kernel and/or rootfs → `make upgrade` switches letter → HMI up → prefs intact
- [x] 4.3 Negative acceptance: corrupt boot or rootfs payload rejected; active letter unchanged; prefs intact
