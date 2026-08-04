## 1. Planning & docs lock-in

- [ ] 1.1 Confirm `docs/flutter-linux-hmi-plan.md` P4.8 unified-OTA wording matches this change (already drafted; adjust if review feedback)
- [ ] 1.2 Resolve open questions in `design.md` (auto-apply policy, verify toolchain, cloud manifest schema, archive format) before coding starts
- [ ] 1.3 Sketch device-side `progress.json` (or `/run/hmi/ota/progress`) schema, host-upload trigger file contract, and upload-byte → transferring mapping

## 2. Image signing toolchain

- [ ] 2.1 Add host signing helper script (Ed25519 detached `*.img.sig`) driven by `OTA_SIGNING_KEY` / documented env
- [ ] 2.2 Wire signing into `build-kernel` outputs (`boot.img` / `boot_b.img`)
- [ ] 2.3 Wire signing into `build-rootfs` output (`rootfs.img`)
- [ ] 2.4 Wire signing into `build-oem` output (`oem.img`)
- [ ] 2.5 Add overlay pubkey path `/etc/hmi/ota-ed25519.pub` (or documented path); ensure private key never enters rootfs/git
- [ ] 2.6 Document `make ota-dev-keys` (or equivalent) for lab keys vs release keys
- [ ] 2.7 Extend `verify-rootfs-overlay.sh` / firmware checks for pubkey presence

## 3. `make ota-package`

- [ ] 3.1 Add `make ota-package` that packs required signed `*.img` + `*.img.sig` (+ manifest) into one zip under documented `output/firmware/<APP>/` path
- [ ] 3.2 Support full-system (inactive FIT + rootfs [+ oem]) and `OEM_ONLY` package contents
- [ ] 3.3 Fail fast when any required image or signature is missing
- [ ] 3.4 Document that future `make publish` MUST depend on the same package artifact
- [ ] 3.5 Wire Makefile `help` / README / `AGENTS.md` for `ota-package`

## 4. Board staged apply + progress

- [ ] 4.1 Evolve `ab-upgrade-apply.sh` (and libs) to require Ed25519 per image before any `dd`
- [ ] 4.2 Support unzip of OTA package under `/userdata/ota/` before verify (or accept already-extracted staging)
- [ ] 4.3 Emit transfer/extract/burn progress status file consumable by HMI and optional host poll
- [ ] 4.4 Keep A/B safety invariants (inactive only, misc/mount agreement, no userdata wipe, no uboot write)
- [ ] 4.5 Support OEM-only signed apply + plain reboot path used by `OEM_ONLY=1`
- [ ] 4.6 Retire default stream-to-partition full-system path from board helpers / docs comments

## 5. `packages/cyber_ota`

- [ ] 5.1 Scaffold `packages/cyber_ota` path package (pubspec, analysis, minimal API surface)
- [ ] 5.2 Implement manifest fetch/parse + version compare
- [ ] 5.3 Implement network download ingress for OTA zip with transferring (download) progress → `/userdata/ota/`
- [ ] 5.4 Implement host-upload ingress: map host transfer bytes to the same transferring progress events
- [ ] 5.5 Implement extractPackage then verifyImages (Ed25519 against device pubkey)
- [ ] 5.6 Implement applyImages orchestration calling board helpers + write progress events
- [ ] 5.7 Unit tests for version compare, progress state machine, extract/verify failure paths

## 6. HMI UI + App wiring

- [ ] 6.1 Add `cyber_ota` path dependency to `app/lws_hmi`
- [ ] 6.2 Implement safe shutdown: stop laser/work session, navigate **directly** to dedicated upgrade page (no Home intermediate)
- [ ] 6.3 Implement dedicated OTA upgrade page (download/transfer, extract, verify, burn progress; no laser job controls; non-cancelable during write)
- [ ] 6.4 Watcher for host-upgrade start trigger (before/at upload start) → safe shutdown → upgrade page → transferring
- [ ] 6.5 Wire Settings Device Information Check for Updates / auto-check to `cyber_ota` + upgrade page flow
- [ ] 6.6 Extend firmware upgrade coordinator to mutex whole-device OTA vs control-board flash
- [ ] 6.7 l10n strings for check/update/download/burn/failure/safe-shutdown states (host upload uses download copy)

## 7. Host `make upgrade` unification

- [ ] 7.1 Make `make upgrade` automatically run `make ota-package` first
- [ ] 7.2 Rewrite `scripts/upgrade-remote.sh` to trigger upgrade-page session, upload the OTA zip with progress, then let on-device extract/verify/apply
- [ ] 7.3 Fail on missing package/signatures; preserve `OEM_IMG=` / `OEM_ONLY=1` / preflight slot checks under staged model
- [ ] 7.4 Update Makefile `help`, README, `AGENTS.md` rebuild notes for signed zip upgrade
- [ ] 7.5 Update `docs/storage-layout.md` to describe unified staged zip path (remove stream-as-default)

## 8. Cloud WebSocket OTA commands

- [ ] 8.1 Implement `command.check_update` via `cyber_ota` (replace `ota_not_supported`)
- [ ] 8.2 Implement `command.update_system` start/queue unified session (safe shutdown + upgrade page + zip download)
- [ ] 8.3 Emit `device.update_progress` from `cyber_ota` progress events (transferring = download for both ingresses)
- [ ] 8.4 Align ack payload shapes with lws-ui / network-api reference

## 9. Verification

- [ ] 9.1 Lab: signed `make upgrade` while on a work screen → upgrade page shows download progress during upload → try-boot commit
- [ ] 9.2 Lab: upgrade page cannot start laser/job; bad/missing `.sig` refuses write
- [ ] 9.3 Lab: Settings check-update + confirm download/apply on upgrade page
- [ ] 9.4 Lab: WS check_update / update_system / update_progress smoke
- [ ] 9.5 Confirm `make push-app` remains unsigned App hot-swap (out of whole-device gate)
- [ ] 9.6 Confirm `make ota-package` artifact is the documented prerequisite for future `make publish`
- [ ] 9.7 Archive change when acceptance complete (`/opsx:archive`)
