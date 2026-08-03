## 1. Planning & docs lock-in

- [ ] 1.1 Confirm `docs/flutter-linux-hmi-plan.md` P4.8 unified-OTA wording matches this change (already drafted; adjust if review feedback)
- [ ] 1.2 Resolve open questions in `design.md` (auto-apply policy, verify toolchain, cloud manifest schema) before coding starts
- [ ] 1.3 Sketch device-side `progress.json` (or `/run/hmi/ota/progress`) schema and host-upload trigger file contract

## 2. Image signing toolchain

- [ ] 2.1 Add host signing helper script (Ed25519 detached `*.img.sig`) driven by `OTA_SIGNING_KEY` / documented env
- [ ] 2.2 Wire signing into `build-kernel` outputs (`boot.img` / `boot_b.img`)
- [ ] 2.3 Wire signing into `build-rootfs` output (`rootfs.img`)
- [ ] 2.4 Wire signing into `build-oem` output (`oem.img`)
- [ ] 2.5 Add overlay pubkey path `/etc/hmi/ota-ed25519.pub` (or documented path); ensure private key never enters rootfs/git
- [ ] 2.6 Document `make ota-dev-keys` (or equivalent) for lab keys vs release keys
- [ ] 2.7 Extend `verify-rootfs-overlay.sh` / firmware checks for pubkey presence

## 3. Board staged apply + progress

- [ ] 3.1 Evolve `ab-upgrade-apply.sh` (and libs) to require Ed25519 per image before any `dd`
- [ ] 3.2 Emit burn/write progress status file consumable by HMI and optional host poll
- [ ] 3.3 Keep A/B safety invariants (inactive only, misc/mount agreement, no userdata wipe, no uboot write)
- [ ] 3.4 Support OEM-only signed apply + plain reboot path used by `OEM_ONLY=1`
- [ ] 3.5 Retire default stream-to-partition full-system path from board helpers / docs comments

## 4. `packages/cyber_ota`

- [ ] 4.1 Scaffold `packages/cyber_ota` path package (pubspec, analysis, minimal API surface)
- [ ] 4.2 Implement manifest fetch/parse + version compare
- [ ] 4.3 Implement network download ingress with transfer progress callbacks → `/userdata/ota/`
- [ ] 4.4 Implement host-upload / local staging ingress (verify+apply only)
- [ ] 4.5 Implement verifyImages (Ed25519 against device pubkey)
- [ ] 4.6 Implement applyImages orchestration calling board helpers + write progress events
- [ ] 4.7 Unit tests for version compare, progress state machine, and verify failure paths

## 5. HMI UI + App wiring

- [ ] 5.1 Add `cyber_ota` path dependency to `app/lws_hmi`
- [ ] 5.2 Implement safe shutdown: stop laser/work session, pop to Home before apply
- [ ] 5.3 Implement dedicated OTA upgrade page (transfer/verify/burn progress; no laser job controls; non-cancelable during write)
- [ ] 5.4 Watcher for host-upload completion trigger (align with `/run/hmi/*.cmd` pattern) → safe shutdown → upgrade page
- [ ] 5.5 Wire Settings Device Information Check for Updates / auto-check to `cyber_ota` + upgrade page flow
- [ ] 5.6 Extend firmware upgrade coordinator to mutex whole-device OTA vs control-board flash
- [ ] 5.7 l10n strings for check/update/burn/failure/safe-shutdown states

## 6. Host `make upgrade` unification

- [ ] 6.1 Rewrite `scripts/upgrade-remote.sh` to upload signed `*.img` + `*.sig` with upload progress
- [ ] 6.2 Trigger on-device `cyber_ota`/apply after upload; fail on missing signatures
- [ ] 6.3 Preserve `OEM_IMG=` / `OEM_ONLY=1` / preflight slot checks under staged model
- [ ] 6.4 Update Makefile `help`, README, `AGENTS.md` rebuild notes for signed upgrade
- [ ] 6.5 Update `docs/storage-layout.md` to describe unified staged path (remove stream-as-default)

## 7. Cloud WebSocket OTA commands

- [ ] 7.1 Implement `command.check_update` via `cyber_ota` (replace `ota_not_supported`)
- [ ] 7.2 Implement `command.update_system` start/queue unified session (safe shutdown + upgrade page)
- [ ] 7.3 Emit `device.update_progress` from `cyber_ota` progress events
- [ ] 7.4 Align ack payload shapes with lws-ui / network-api reference

## 8. Verification

- [ ] 8.1 Lab: signed `make upgrade` while on a work screen → Home → upgrade page → try-boot commit
- [ ] 8.2 Lab: upgrade page cannot start laser/job; bad/missing `.sig` refuses write
- [ ] 8.3 Lab: Settings check-update + confirm download/apply on upgrade page
- [ ] 8.4 Lab: WS check_update / update_system / update_progress smoke
- [ ] 8.5 Confirm `make push-app` remains unsigned App hot-swap (out of whole-device gate)
- [ ] 8.6 Archive change when acceptance complete (`/opsx:archive`)
