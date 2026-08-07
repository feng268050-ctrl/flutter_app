## 1. Baseline lock and inventory

- [ ] 1.1 Re-check https://buildroot.org/download.html and lock the target **2025.02.x** tip (must be ≥ **2025.02.16**); note tag in the PR description
- [ ] 1.2 Inventory Rockchip/Innohi deltas in owned `linux-sdk/buildroot` vs vanilla 2024.02 (board/rockchip, package/rockchip, toolchain fragments, patches, Config.in hooks)
- [ ] 1.3 Confirm whether an Innohi SDK drop already on ≥ tip floor exists; if yes, evaluate design approach C vs merge A before coding

## 2. Owned Buildroot rebase

- [ ] 2.1 Merge or re-base owned `linux-sdk/buildroot` onto locked upstream tag `2025.02.<n>` (prefer design approach A; fall back to B only if conflicts are unmaintainable)
- [ ] 2.2 Resolve conflicts: prefer upstream LTS for generic packages/infra; preserve Rockchip board/package/toolchain behavior required for RK356x rootfs
- [ ] 2.3 Verify `BR2_VERSION` / localversion reflects the locked 2025.02.x tip (not 2024.02)
- [ ] 2.4 Smoke `make lunch` / olddefconfig against `rockchip_rk3566_rk3568_lws_hmi` and fix any immediate Kconfig breakage in SDK board configs

## 3. Overlay and pin files

- [ ] 3.1 Add git-tracked `overlay/buildroot/BUILDROOT_VERSION` with the locked `2025.02.<n>` line
- [ ] 3.2 Update `docs/linux-sdk-vendor-import.md` with a Buildroot LTS pin section (mirror kernel `KERNEL_6_1_SUBLEVEL` pattern) and colleague sync/runbook notes
- [ ] 3.3 Run `make apply-overlay`; fix `scripts/apply-overlay.sh` sync helpers and `overlay/buildroot/chips/*.config` for any renamed/moved Kconfig symbols
- [ ] 3.4 Confirm overlay still injects libopenssl, GStreamer (+ rockchip), BlueZ, Meson, Flutter packages and continues stashing Rockchip BlueZ/OpenSSL/GST patches as required

## 4. Clean rebuild and package pins

- [ ] 4.1 `make clean-buildroot-output` (or equivalent) so 2024.02 stamps are not reused; refresh macOS Docker volume if needed (`docker-volume-init` / `docker-volume-sync`)
- [ ] 4.2 `make lunch` then rebuild overlay-critical packages via `scripts/br-make-packages.sh` (at least `libopenssl`, BlueZ set, and any other pins broken by the bump)
- [ ] 4.3 Force GStreamer prebuilt + eLinux refresh when staging changes (`FORCE=1 make build-gstreamer`, `FORCE=1 make rebuild-flutter-embedded-linux` as applicable)
- [ ] 4.4 `make build-rootfs` and ensure `scripts/verify-rootfs-overlay.sh` PASS
- [ ] 4.5 Optional: add a cheap check that `BR2_VERSION` matches `overlay/buildroot/BUILDROOT_VERSION` (e.g. extend `check-linux-sdk` / small script)

## 5. Device acceptance

- [ ] 5.1 `make upgrade` (A/B) to ynh960; confirm try-boot on new rootfs letter
- [ ] 5.2 Smoke: Weston/HMI up; eth ping; Wi‑Fi or BT as applicable; USB gadget SSH
- [ ] 5.3 Verify overlay pins on device/rootfs: OpenSSL not 3.2.1; GStreamer ≥ 1.28.5; `bluetoothd` ≥ 5.87; Rockchip BlueZ Connect(s) patch still inactive
- [ ] 5.4 Spot-check OTA verify path still works with system OpenSSL; note any emulator swgl glibc comment updates if libc story changed

## 6. Docs and handoff

- [ ] 6.1 Update AGENTS.md rebuild table / README / `docs/make-commands.md` only if new Make targets or mandatory clean steps were added
- [ ] 6.2 Record locked tip + merge approach (A/B/C) and residual risks in the implementing PR / change notes
- [ ] 6.3 Document colleague procedure to obtain the rebased gitignored `linux-sdk/buildroot` (runbook and/or shared artifact)
