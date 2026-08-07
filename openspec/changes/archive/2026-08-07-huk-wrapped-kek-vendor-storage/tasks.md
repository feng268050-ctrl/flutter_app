## 1. Spike (blocking)

- [x] 1.1 On ynh960: probe whether seal TA can open system PTA and call `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` (or document equivalent Rockchip HUK API)
- [x] 1.2 Record spike result in `openspec/changes/huk-wrapped-kek-vendor-storage/notes.md` (PASS/FAIL + error codes); if FAIL, stop implementation and revise design — do not store plaintext KEK in VS

## 2. Vendor Storage ID + helpers

- [x] 2.1 Add ID **23** / `VENDOR_SEAL_KEK_WRAPPED_*` to `board/vendor-storage-ids.txt` and overlay copy
- [x] 2.2 Add `/usr/libexec/board/read-seal-kek-wrapped` + `write-seal-kek-wrapped` (mirror cloud Ed25519 sealed helpers; size cap)
- [x] 2.3 Wire helpers into rootfs overlay / post-build as needed; document in `docs` / AGENTS if new make targets appear

## 3. Seal TA / CA

- [x] 3.1 Implement HUK-bound wrap/unwrap of the 32-byte seal KEK in the TA (format per design D6; freeze AAD)
- [x] 3.2 Extend CA with import/export (or bootstrap) of the wrapped blob; keep `probe`/`seal`/`unseal` behavior for callers
- [x] 3.3 TA KEK load order: VS wrap → else REE FS migrate → else generate+wrap; never write plaintext KEK to VS
- [x] 3.4 `FORCE=1 make build-secrets-seal` with `keys/oem/vendor_ta.pem`; sync prebuilt + overlay

## 4. Migrate / App / HAL

- [x] 4.1 Extend `migrate-secrets` (or add `migrate-seal-kek`) to: read REE KEK via CA export, write VS ID 23, verify unwrap + unseal of existing ID 22 seed unchanged
- [x] 4.2 Ensure migrator never regenerates cloud Ed25519 when KEK migrate succeeds
- [x] 4.3 Host `make` target / docs for field units that already have OP-TEE REE KEK

## 5. Docs + policy demotion

- [x] 5.1 Update `docs/hal-secrets-kek.md`: VS-wrapped KEK as persistence story; RPMB remains future; demote `/userdata/tee` to cache/migration
- [x] 5.2 Update AGENTS rebuild row for seal TA + VS helpers + migrate

## 6. Verification

- [x] 6.1 Device smoke: seal → write wrap to VS → wipe `/userdata/tee` → restart tee-supplicant → unseal OK
- [x] 6.2 Device smoke: cloud ID 22 seed identical before/after KEK migrate
- [x] 6.3 Negative: wrong/missing wrap blob fails closed; no plaintext KEK in VS dump
