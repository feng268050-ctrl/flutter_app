## 1. GPT / storage / paired boot+rootfs selection

- [ ] 1.1 Update `board/parameter-buildroot-fit.txt` to `boot_a`/`boot_b` + `rootfs_a`/`rootfs_b`; shift oem/private*/userdata
- [ ] 1.2 Rewrite `docs/storage-layout.md` for paired A/B, upgrade-vs-flash matrix (boot+rootfs+optional oem vs uboot/GPT), prefs policy
- [ ] 1.3 Spike misc slot-letter format (active/try/previous); document offsets
- [ ] 1.4 Update boot chain / kernel root selection so letter picks matching `boot_*` + `rootfs_*` (PARTLABEL); remove sole single-boot/`p6` product assumption
- [ ] 1.5 If U-Boot cannot select `boot_a`/`boot_b` from misc with current binary, add smallest env/script overlay; escalate `build-uboot` only if required
- [ ] 1.6 Extend `verify-firmware-partitions.sh` + build-img/package-file so `boot.img`/`rootfs.img` are gated per slot and factory image populates both letters

## 2. Board apply / confirm / rollback

- [ ] 2.1 Add overlay helpers to resolve inactive letter `by-partlabel` nodes and read/write misc letter + try-boot state
- [ ] 2.2 Implement full-system apply: stage `/userdata/ota/` bundle → write inactive **boot then rootfs** (+ optional oem) → verify digests → arm try-boot → reboot; refuse userdata wipe and uboot writes
- [ ] 2.3 Add `lws-hmi-ab-boot-confirm` oneshot/unit: commit letter on healthy boot or revert letter pair and reboot
- [ ] 2.4 Reserve app-only apply path to `/oem/hmi` without letter switch (stub OK if documented)
- [ ] 2.5 Wire helpers into fs-overlay; extend `verify-rootfs-overlay.sh` for helper presence and upgrade-path safety checks

## 3. Host `make upgrade`

- [ ] 3.1 Add `scripts/upgrade-remote.sh` reusing push-app SSH/`SERIAL=`/`IP=`; transfer **boot.img + rootfs.img** (+ digests/manifest); invoke board apply; wait for SSH return
- [ ] 3.2 Add Makefile `upgrade` target + `help` stating full-system includes kernel/`boot.img`; must not call RockUSB `uf`
- [ ] 3.3 Support `UPGRADE_MODE=app` host path aligned with board stub
- [ ] 3.4 Fail fast when boot or rootfs artifacts missing; propagate board apply failures
- [ ] 3.5 Update README Make commands + AGENTS rebuild table for parameter/upgrade (boot+rootfs) paths

## 4. Docs / plan / acceptance

- [ ] 4.1 Keep `docs/flutter-pi-hmi-plan.md` P2.4 / §1.3 aligned with boot+rootfs remote upgrade (already updated in redesign; refresh status when done)
- [ ] 4.2 Device acceptance: one-time `make flash` with new GPT → boot letter A → change kernel and/or rootfs → `make upgrade` switches letter → HMI up → prefs intact
- [ ] 4.3 Negative acceptance: corrupt boot or rootfs payload rejected; active letter unchanged; prefs intact
