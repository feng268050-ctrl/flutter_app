## 1. S0 — Whitelist, gate, vendor docs

- [x] 1.1 Add `board/linux-sdk-whitelist.txt` (keep / forbid / external slim rules)
- [x] 1.2 Add `scripts/check-linux-sdk-whitelist.sh` and `make check-linux-sdk`
- [x] 1.3 Add `docs/linux-sdk-vendor-import.md` (blueprint, trim, Docker, git defer)
- [x] 1.4 Update `docs/platform-os-oem-sdk-plan.md` W3 status (in progress; 进仓 deferred)

## 2. S1 — Trim script

- [x] 2.1 Add `scripts/trim-linux-sdk.sh` + `make trim-linux-sdk` (preserve dl/output; install VENDOR_IMPORT + ownership marker)
- [x] 2.2 Wire `TRIM=1` on `extract-linux-sdk`
- [x] 2.3 Document macOS Docker volume re-init/sync after trim in README / vendor-import

## 3. S2 — Squash platform overlay into owned tree

- [x] 3.1 Add squash helper (or trim post-step) applying `overlay/kernel` + stable device script patches into local `linux-sdk/`
- [x] 3.2 Document delete-only policy for `overlay/kernel` / squashed device diffs; do not move third-party packages

## 4. S3 — Thin apply-overlay

- [x] 4.1 When ownership marker present, skip kernel DTS/config/patch and squashed device installs
- [x] 4.2 Keep third-party / custom BR package sync, fs-overlay, chips, board/OEM inject unchanged

## 5. S4 — Git / IDE without un-ignoring

- [x] 5.1 Confirm `.gitignore` still has `linux-sdk/`; add `.cursorignore` entry
- [x] 5.2 Document future LFS/prebuilt commit path in vendor-import docs (no git add of SDK)

## 6. Docs Make touchpoints

- [x] 6.1 Update Makefile `help`, README Make commands, AGENTS rebuild table for trim/check
- [x] 6.2 Mark OpenSpec tasks complete as work lands
