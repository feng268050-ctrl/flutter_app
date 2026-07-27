## Context

Platform plan §5 / W3: replace the vendor “full SDK + overlay patch machine” with a trimmed owned `linux-sdk/` (~3 G source). W0–W2 (OEM + rootfs thinning) are done. Host tree today is ~18 G and gitignored; macOS builds copy it into a Docker volume.

## Goals / Non-Goals

**Goals:**

- Whitelist + gate script + vendor-import docs
- Reproducible trim that still builds ynh960 rootfs/kernel
- Squash stable kernel + device platform patches into the local owned tree
- Thin `apply-overlay` for those platform steps only
- Document future git/LFS commit path; keep `linux-sdk/` gitignored

**Non-Goals:**

- Committing `linux-sdk/` into the monorepo index
- Moving third-party / custom Buildroot packages off `overlay/`
- W4 UTM; production self-built U-Boot

## Decisions

### D1 — Canonical docs in git; copy into local tree

`docs/linux-sdk-vendor-import.md` is the tracked source of truth. `trim-linux-sdk` / `extract` (when `TRIM=1`) install a copy as `linux-sdk/VENDOR_IMPORT.md` locally. Rationale: `linux-sdk/` stays ignored.

### D2 — Whitelist file drives trim + check

`board/linux-sdk-whitelist.txt` lists keep roots, forbid top-level dirs, and external keep/slim rules. `check-linux-sdk-whitelist.sh` fails if forbid dirs exist or known fat paths remain. `trim-linux-sdk.sh` deletes according to the same file.

### D3 — Preserve build caches by default

Trim MUST NOT delete `buildroot/dl/`, `buildroot/output/`, or `output/` unless `CLEAN_OUTPUT=1`. Developers keep incremental Buildroot state.

### D4 — Squash only platform overlay; third-party stays overlay

Into owned tree: `overlay/kernel/**` and stable device script patches (`mk-rootfs`, `post-wifibt`, check-*.sh, etc.).

Remain on overlay forever in this change: `overlay/buildroot/package/**`, `overlay/third-party/**`, all `sync_*_package` helpers, rootfs-overlay, chips, board/OEM params.

### D5 — Apply-overlay thinning via ownership marker

Owned tree gets `linux-sdk/.lws-owned-tree` (or equivalent) after squash/trim. When present, `apply-overlay` skips kernel DTS/patch and squashed device installs; package sync still runs. Migration: trees without the marker keep full apply behavior until trimmed/squashed once.

### D6 — Docker volume refresh after trim

macOS: after trim, operators MUST `make docker-volume-init` or `docker-volume-sync` so deleted trees do not remain in the volume.

### D7 — No `.gitignore` un-ignore

S4 documents LFS/`prebuilt/` for Mali/firmware and future track rules for `dl/`/`output/`. `.gitignore` keeps `linux-sdk/`. Optional `.cursorignore` mirrors that path.

## Risks / Trade-offs

- [Trim deletes needed external] → Whitelist review against defconfig; gap list in vendor-import docs; check script before build.
- [Volume retains fat dirs] → Document re-init/sync after trim.
- [Squash drifts from overlay copies] → Overlay kernel/device become delete-only; marker-gated skip in apply-overlay.
- [IDE still indexes ignored tree] → `.cursorignore` for `linux-sdk/`.

## Migration Plan

1. Existing full SDK: `make trim-linux-sdk` then volume sync; `make apply-overlay`; build as usual.
2. Fresh extract: `TRIM=1 make extract-linux-sdk SRC=…`.
3. Rollback: re-extract full vendor volumes without trim (`FORCE=1`); remove ownership marker if needed; full apply-overlay restores kernel from overlay.

## Open Questions

_(none for this slice — commit-to-git deferred by product decision)_
