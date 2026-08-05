## 1. Planning & docs lock-in

- [ ] 1.1 Confirm `docs/flutter-linux-hmi-plan.md` P4.8 matches this change (`tar.gz`; cloud verify; host upgrade no verify; direct upgrade page)
- [ ] 1.2 Resolve remaining open questions in `design.md` (auto-apply, verify toolchain, cloud `.sig` discovery) before coding starts
- [ ] 1.3 Sketch device-side `progress.json` schema, host-upload trigger contract, upload-byte → transferring mapping

## 2. Package signing toolchain (cloud / publish)

- [ ] 2.1 Add host signing helper script (Ed25519 detached over a file) driven by `OTA_SIGNING_KEY`
- [ ] 2.2 Add overlay pubkey path `/etc/ota/ed25519.pub`; private key never in rootfs/git
- [ ] 2.3 Document `make ota-dev-keys` for lab vs release keys
- [ ] 2.4 Extend `verify-rootfs-overlay.sh` for pubkey presence

## 3. `make ota-package`

- [ ] 3.1 Add `make ota-package` that packs required `*.img` (+ manifest) into one `tar.gz`
- [ ] 3.2 When signing configured, emit sibling `*.tar.gz.sig`; publish/CI must fail without key; local upgrade may omit `.sig`
- [ ] 3.3 Support full-system (inactive FIT + rootfs [+ oem]) and `OEM_ONLY` contents
- [ ] 3.4 Fail fast when any required image is missing
- [ ] 3.5 Document that `make publish` needs archive + `.sig`; `make upgrade` needs archive only
- [ ] 3.6 Wire Makefile `help` / README / `AGENTS.md` for `ota-package`

## 4. Board staged apply + progress

- [ ] 4.1 Evolve `ab-upgrade-apply.sh` to support cloud mode (require archive Ed25519) and host-upgrade mode (skip verify)
- [ ] 4.2 Support extract of OTA `tar.gz` under `/userdata/ota/`
- [ ] 4.3 Emit transfer/verify(optional)/extract/burn progress status file
- [ ] 4.4 Keep A/B safety invariants
- [ ] 4.5 Support OEM-only apply + plain reboot for `OEM_ONLY=1`
- [ ] 4.6 Retire default stream-to-partition full-system path from helpers/docs comments

## 5. `packages/cyber_ota`

- [ ] 5.1 Scaffold `packages/cyber_ota` path package
- [ ] 5.2 Implement manifest fetch/parse + version compare
- [ ] 5.3 Implement CloudIngress: download `tar.gz` + `.sig`, transferring progress
- [ ] 5.4 Implement HostUploadIngress: map host bytes to transferring; **no verify**
- [ ] 5.5 Implement verifyPackage for cloud only; extractPackage; applyImages
- [ ] 5.6 Unit tests for version compare, progress machine, cloud verify failure, host skip-verify path

## 6. HMI UI + App wiring

- [ ] 6.1 Add `cyber_ota` path dependency to `app/lws_hmi`
- [ ] 6.2 Safe shutdown → dedicated upgrade page (no Home intermediate)
- [ ] 6.3 Upgrade page: download; cloud verify; extract; burn; no laser controls; non-cancelable during write
- [ ] 6.4 Host-upgrade trigger watcher → safe shutdown → transferring
- [ ] 6.5 Wire Settings Check for Updates / auto-check
- [ ] 6.6 Mutex whole-device OTA vs control-board flash
- [ ] 6.7 l10n for check/update/download/burn/failure states

## 7. Host `make upgrade` unification

- [ ] 7.1 Make `make upgrade` run `make ota-package` first (unless alternate package input)
- [ ] 7.2 Rewrite `upgrade-remote.sh`: trigger upgrade page, upload `tar.gz` only (no `.sig`), device extract/apply without verify
- [ ] 7.3 Fail on missing archive; preserve `OEM_IMG=` / `OEM_ONLY=1` / preflight
- [ ] 7.4 Update Makefile help / README / AGENTS for staged unsigned host upgrade
- [ ] 7.5 Update `docs/storage-layout.md` for staged path + cloud-vs-host trust split

## 8. Cloud WebSocket OTA commands

- [ ] 8.1 Implement `command.check_update` via `cyber_ota`
- [ ] 8.2 Implement `command.update_system` (safe shutdown + upgrade page + download + **verify** + apply)
- [ ] 8.3 Emit `device.update_progress` from `cyber_ota` events
- [ ] 8.4 Align ack shapes with lws-ui / network-api reference

## 9. Verification

- [ ] 9.1 Lab: `make upgrade` on work screen → upgrade page download during upload → apply without `.sig` → try-boot
- [ ] 9.2 Lab: cloud/Settings path with bad `.sig` refuses write; good `.sig` applies
- [ ] 9.3 Lab: upgrade page cannot start laser/job
- [ ] 9.4 Lab: WS check_update / update_system / update_progress smoke
- [ ] 9.5 Confirm `make push-app` remains hot-swap outside whole-device gate
- [ ] 9.6 Confirm `make ota-package` is prerequisite for `make publish` (with `.sig`)
- [ ] 9.7 Archive change when acceptance complete
