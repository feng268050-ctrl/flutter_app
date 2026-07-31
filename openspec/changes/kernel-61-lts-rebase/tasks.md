## 1. Baseline and tip lock

- [ ] 1.1 Confirm current owned tree is `SUBLEVEL=99` and inventory Rockchip/Innohi-only paths vs vanilla 6.1.99
- [ ] 1.2 Re-read kernel.org 6.1 LTS tip; lock target `6.1.<tip>` with floor ≥ 6.1.180 (or adopt vendor SDK base if already ≥ floor)
- [ ] 1.3 Document the pin in `docs/linux-sdk-vendor-import.md` and/or `overlay/kernel/` pin file
- [ ] 1.4 List product overlay patches (`0001–0008`) and DTS/config fragments that must rebase

## 2. Stable merge into owned kernel-6.1

- [ ] 2.1 Add upstream stable 6.1.y reference (remote tag or patch series) for the locked tip
- [ ] 2.2 Merge/rebase `v6.1.<tip>` into `linux-sdk/kernel-6.1`; resolve conflicts (prefer upstream for generic code; keep vendor behavior in Rockchip/Innohi paths)
- [ ] 2.3 If conflicts block a single jump, land staged intermediates (document each) until tip is reached
- [ ] 2.4 Verify `Makefile` `SUBLEVEL` matches the locked tip and the tree builds `Image`/DTBs for ynh960

## 3. Rebase product overlay and squash

- [ ] 3.1 Refresh `overlay/kernel/patches/*` so they apply cleanly on the new baseline
- [ ] 3.2 Adjust `overlay/kernel/rockchip/*` DTS/config if bindings or defaults changed
- [ ] 3.3 Run `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or `make squash-linux-sdk-platform`) and confirm no reject piles
- [ ] 3.4 Rebuild: `make build-kernel`; rebuild rootfs if packaged modules must match (`make build-rootfs`)

## 4. Device verification and acceptance

- [ ] 4.1 Deploy via `make upgrade` (A/B FIT + rootfs as required); confirm try-boot and `uname -r` == pin
- [ ] 4.2 Smoke ynh960: HMI/Weston, Ethernet, Wi‑Fi and/or BT module load, USB gadget SSH, display/touch, NPU/VOP DT wiring as applicable
- [ ] 4.3 Record acceptance notes (pin version + date); spot-check that post-6.1.99 High examples are covered by the version floor (no cherry-pick CI required)
- [ ] 4.4 Optional follow-up only: trim unused kconfig attack surface via existing trim fragments (must not replace LTS merge)
