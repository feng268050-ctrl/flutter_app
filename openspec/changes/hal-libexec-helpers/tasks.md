## 1. Overlay move and PATH links

- [ ] 1.1 Create `rootfs-overlay/usr/libexec/hal/` and move design D1 scripts (`read-product-identity.sh`, `write-product-identity.sh`, `vendor-storage-ids.txt`, `read-device-serial.sh`, `secrets-seal` / CA helper if present under hmi)
- [ ] 1.2 Update internal defaults inside moved scripts (e.g. `VENDOR_STORAGE_IDS` path, calls between read/write helpers) to `/usr/libexec/hal/…`
- [ ] 1.3 Update `post-build.sh` `/usr/bin` symlink targets for `read-serial`, `read-identity`, `write-identity`, and any secrets-related links
- [ ] 1.4 Grep overlay systemd units / other hmi scripts for absolute `/usr/libexec/hmi/` references to the moved basenames; retarget or leave compat only if justified

## 2. HAL, OEM, and host callers

- [ ] 2.1 Update `cyber_hal` defaults (`secrets-seal` path, comments) and package tests / board JSON that assert `/usr/libexec/hmi/…` for moved helpers
- [ ] 2.2 Update OEM `board_profile` / helpers and `packages/cyber_hal/boards/*.json` only where they point at moved scripts (do not relocate ssh-debug / usb-otg in this change unless required)
- [ ] 2.3 Fix host scripts that hardcode `/usr/libexec/hmi/` for identity/serial/secrets (prefer `/usr/bin` where already used)

## 3. Docs and sibling change hygiene

- [ ] 3.1 Update `AGENTS.md` libexec convention to include `/usr/libexec/hal/`
- [ ] 3.2 Patch any README / `docs/storage-layout.md` lines that place identity helpers under `hmi/`
- [ ] 3.3 Align active `vendor-storage-product-identity` artifacts (or post-archive notes) so helper paths say `/usr/libexec/hal/`

## 4. Verification

- [ ] 4.1 Confirm `readlink` of `/usr/bin/read-serial`, `read-identity`, `write-identity` → `/usr/libexec/hal/…` on a built rootfs or overlay staging
- [ ] 4.2 Run `cyber_hal` tests touching ProductInfo / secrets paths
- [ ] 4.3 Optional: add/extend `verify-rootfs-overlay` (or a small script check) that fails if canonical identity scripts exist only under `hmi/`
