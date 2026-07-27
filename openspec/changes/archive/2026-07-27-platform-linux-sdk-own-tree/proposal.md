## Why

Daily builds still depend on an ~18 G vendor Rockchip SDK plus a ~900-line `apply-overlay` patch machine. Platform W3 needs a **trimmed, owned `linux-sdk/`** that can reproduce ynh960 images, with whitelist gates and import discipline — without committing the tree to git yet (avoids IDE index freezes).

## What Changes

- Add whitelist + `check-linux-sdk` gate and canonical vendor-import docs (copied into local `linux-sdk/` by trim/extract).
- Add `trim-linux-sdk` (optional `TRIM=1` after extract) to drop debian/ubuntu/yocto/docs/app, fat externals, and slim Mali / rknpu2 to product needs; preserve `dl/` / build `output/` unless asked.
- Squash **stable platform** overlay into the local owned tree: `overlay/kernel` DTS/config/patches and always-on device script patches.
- Thin `apply-overlay` for work already in the owned tree (kernel/device); **keep** third-party / custom BR package overlay sync, rootfs-overlay, chips, board/OEM inject unchanged.
- Document git/LFS strategy for a **future** commit; **do not** remove `linux-sdk/` from `.gitignore` or add the tree to the index.
- macOS: trim requires Docker volume re-init/sync so deleted blobs do not linger.

**Out of scope:** committing `linux-sdk` blobs; moving third-party BR packages off overlay; W4 UTM; renaming `linux-sdk/`; self-built U-Boot for production.

## Capabilities

### New Capabilities

- `linux-sdk-own-tree`: Whitelist, trim, vendor-import records, size/forbid gates, and owned-tree layout for the Rockchip platform SDK (still gitignored).

### Modified Capabilities

- `buildroot-lws-hmi-image`: Host workflow documents extract → trim → apply-overlay; apply-overlay no longer re-applies kernel/device platform patches once owned tree holds them; third-party packages remain overlay-injected.

## Impact

- **New:** `board/linux-sdk-whitelist.txt`, `scripts/check-linux-sdk-whitelist.sh`, `scripts/trim-linux-sdk.sh`, `docs/linux-sdk-vendor-import.md`, Make targets / help / README / AGENTS.
- **Scripts:** `extract-linux-sdk.sh` (`TRIM=1`), `apply-overlay.sh` (thin platform path).
- **Overlay policy:** `overlay/kernel` and squashed device diffs become delete-only; `overlay/buildroot/package/**` and `overlay/third-party/**` stay.
- **Local only:** trimmed `linux-sdk/` on host / Docker volume; not committed.
