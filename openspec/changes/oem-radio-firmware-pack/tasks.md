## 0. Gate (do not skip)

- [ ] 0.1 Wait until `kernel-61-lts-rebase` is **archived** (or explicitly frozen with Wi‑Fi/BT smoke green on the new tip) before any implementation commits
- [ ] 0.2 Confirm no concurrent edits to `post-wifibt` / `overlay/kernel/rockchip/ynh960-wifibt.config` from other changes

## 1. OEM radio pack (ynh960)

- [ ] 1.1 Add `oem/boards/ynh960/radio/manifest.json` + `firmware/` keep-set (AIC8800D80 files from design D2)
- [ ] 1.2 Ensure `make build-oem` packs `radio/` into `oem.img`
- [ ] 1.3 Update `wifibt-bringup.sh` to prefer OEM radio firmware and symlink/bind into driver search paths; soft-fail if missing

## 2. Rootfs kitchen-sink removal

- [ ] 2.1 Stop Innohi/full multi-vendor firmware copy in `post-wifibt` (overlay-owned patch); do not require Broadcom `AP6256` chip path for FW
- [ ] 2.2 Stop shipping `bcmdhd*.ko` for this product line when no longer selected
- [ ] 2.3 Add post-build purge and/or `verify-rootfs-overlay` FAIL for `fw_bcm*` / agreed forbidden patterns
- [ ] 2.4 Adjust `env-verify` to check OEM radio keep-set (and stop expecting kitchen-sink `/lib/firmware/brcm` as success)

## 3. Validation

- [ ] 3.1 `OEM_ONLY=1 make upgrade` (or full path): Wi‑Fi scan/assoc + BT smoke on ynh960 with OEM radio only
- [ ] 3.2 Measure rootfs `/usr/lib/firmware` size drop (~40 MiB class)
- [ ] 3.3 Document rebuild lines in AGENTS/README only if new make targets appear

## 4. Explicit non-work (conflict avoidance)

- [ ] 4.1 Do **not** change `overlay/kernel/**` in this change unless LTS is finished and a follow-up slice is agreed
- [ ] 4.2 Do **not** move `aic8800_*.ko` into OEM
