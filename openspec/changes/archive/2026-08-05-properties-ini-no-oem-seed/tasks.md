## 1. OEM and compose

- [x] 1.1 Delete `oem/boards/ynh960/product.ini` and `oem/boards/sim/product.ini`
- [x] 1.2 Remove `merge_product_ini` (and callers) from `oem-compose.sh`; compose MUST NOT touch properties/product ini
- [x] 1.3 Strip `helpers.camera_ip` from App and OEM/sim `board_profile.json` copies (and any other profiles that still carry it)

## 2. Runtime path and migrate

- [x] 2.1 Update `bind-prefs.sh` HAL basename list: `properties.ini`; rename legacy `product.ini` → `properties.ini` when destination absent
- [x] 2.2 Grep overlay for `product.ini` path strings and update (prefs bind, comments, verify scripts)

## 3. HAL

- [x] 3.1 Change default path constant to `/var/lib/hal/properties.ini` (`kPropertiesIniPath` or equivalent); update `ProductInfo` / reader / tests
- [x] 3.2 Keep ignoring stale `brand`/`model`/`sn` lines in the file
- [x] 3.3 Update `packages/cyber_hal` README / stub defaults as needed (stub may still inject test camera_ip explicitly)

## 4. Host set-prop / del-prop

- [x] 4.1 Retarget `scripts/product-ini-common.sh` (rename file optional) and `set-product-prop.sh` / `del-product-prop.sh` to `properties.ini`
- [x] 4.2 Apply same `product.ini` → `properties.ini` rename before mutate when needed
- [x] 4.3 Keep refusing identity keys with `write-identity` guidance (no OEM seed mention)
- [x] 4.4 Fix `upgrade-process-library` to read model from Vendor Storage (not ini); update any device scripts still citing `product.ini` for tunables

## 5. App camera unconfigured

- [x] 5.1 Remove `kDefaultIpCameraHost` soft fallback; blank `camera_ip` skips session/MediaMTX/invented probe host
- [x] 5.2 Update OSD / Camera settings / AI paths that fell back to `192.168.1.100`
- [x] 5.3 Update `OsPaths` comments and App docs that say `product.ini`

## 6. Docs

- [x] 6.1 Update AGENTS.md rebuild table / set-prop notes, README, `docs/make-commands.md`, `docs/storage-layout.md`
- [x] 6.2 Close or amend `docs/platform-os-oem-sdk-plan.md` §3.5 (no OEM seed; runtime `properties.ini`)
- [x] 6.3 Grep docs for `product.ini` and fix remaining operator-facing references

## 7. Verify

- [x] 7.1 `flutter test` / analyze in `packages/cyber_hal` for path + migrate behavior
- [x] 7.2 Host dry-check: script paths reference `properties.ini`; OEM tree has no seed files
- [x] 7.3 On device (or after rootfs): bind-prefs renames legacy file; `set-prop CAMERA_IP=…` writes new basename; compose does not recreate file
