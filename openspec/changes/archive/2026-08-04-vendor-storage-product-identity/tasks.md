## 1. GPT and flash non-overwrite gates

- [x] 1.1 Add frozen `vendor0`–`vendor3` (`0x80` each) to `board/parameter-buildroot-fit.txt` (prefer insert before userdata; document final LBAs in `docs/storage-layout.md`)
- [x] 1.2 Confirm `board/package-file-ynh960-linux-ab` has no vendor payload rows; keep it that way
- [x] 1.3 Add `build-img` / verify gate: fail if package-file lists `vendor[0-3]` or factory staging contains `vendor*.img`
- [x] 1.4 Add `board/vendor-storage-ids.txt` (or equivalent) documenting ID 1=SN, 20=BRAND, 21=MODEL

## 2. Rootfs Vendor Storage tooling

- [x] 2.1 Enable Rockchip userspace `vendor_storage` (confirm SDK package: `rktoolkit` vs other) in Buildroot overlay / defconfig fragments
- [x] 2.2 Add `/usr/libexec/hmi/` helpers to read/write brand/model/sn via the ID map; wire `post-build.sh` symlinks if needed
- [x] 2.3 Update `read-device-serial.sh`: product SN from Vendor Storage first, then chip-ID fallback; keep `--chip-id`
- [x] 2.4 Change `oem-compose.sh`: stop force-merge of `brand`/`model`/`sn`; ignore those keys in OEM seed merge/copy

## 3. HAL and OEM seed cleanup

- [x] 3.1 Update `cyber_hal` `ProductInfo` to load brand/model/sn from Vendor Storage (ignore ini identity keys); keep chipId path; add/adjust package tests
- [x] 3.2 Strip or stop relying on identity keys in `oem/boards/*/product.ini` (tunables only); update sim notes if needed
- [x] 3.3 Point `set-prop` / `del-prop` refusal messages at `make write-identity` instead of OEM seed

## 4. Host write-identity and docs

- [x] 4.1 Add `scripts/write-identity.sh` + Makefile `write-identity` (`BRAND=` `MODEL=` `PRODUCT_SN=` / `IDENTITY_SN=`; selection via `SN=`/`CHIPID=`/`IP=`; `FORCE=1` overwrite)
- [x] 4.2 Document factory order (flash → write-identity → verify), RockUSB `SN`/`RSN` SN-only caveat, and vendor geometry freeze in README / Makefile help / AGENTS.md rebuild table / `docs/storage-layout.md`
- [x] 4.3 Emulator: clear failure on write-identity; read path keeps chip-ID / stub fallback

## 5. Verification

- [x] 5.1 On hardware after GPT flash: confirm `/dev/vendor_storage`, write-identity, readback, `make devices` SN/ChipID
- [x] 5.2 Reflash with compliant `factory.img` (unchanged vendor geometry) and confirm SN preserved
- [x] 5.3 Confirm `oem-compose` + OEM seed no longer reset brand/model/sn; tunables fill-blank still works
- [x] 5.4 Confirm build-img fails when a vendor payload is intentionally introduced (gate smoke)
