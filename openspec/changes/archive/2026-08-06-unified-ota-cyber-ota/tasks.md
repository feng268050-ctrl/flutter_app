## 1. Planning & docs lock-in

- [x] 1.1 Confirm `docs/flutter-linux-hmi-plan.md` P4.8 matches this change (`tar.gz`; cloud **and** SSH host verify; direct upgrade page)
- [x] 1.2 Resolve remaining open questions in `design.md` (auto-apply, verify toolchain, cloud `.sig` discovery, **SSH also verifies**) before coding starts
- [x] 1.3 Document device contracts: `OtaSession.progress` / `ota.log` (no `progress.json`), host HTTP download trigger, download-byte → transferring mapping (`UPGRADE_PACKAGE` sibling `.sig`) — see `contracts.md`

## 2. Package signing toolchain (cloud / publish / SSH upgrade)

- [x] 2.1 Add host signing helper script (Ed25519 detached over a file) driven by `OTA_SIGNING_KEY`
- [x] 2.2 Add overlay pubkey path `/etc/ota/ed25519.pub`; private key never in rootfs/git
- [x] 2.3 Document `make ota-release-keys` for the release Ed25519 keypair (no separate lab/dev keys)
- [x] 2.4 Extend `verify-rootfs-overlay.sh` for pubkey presence

## 3. `make ota-package`

- [x] 3.1 Add `make ota-package` that packs required `*.img` (+ manifest) into one `tar.gz`
- [x] 3.2 Emit sibling `*.tar.gz.sig` with `OTA_SIGNING_KEY`; **fail without key** (SSH upgrade and publish both need `.sig`)
- [x] 3.3 Support full-system (inactive FIT + rootfs [+ oem]) and `OEM_ONLY` contents
- [x] 3.4 Fail fast when any required image is missing
- [x] 3.5 Document that `make publish` **and** SSH `make upgrade` need archive + `.sig`
- [x] 3.6 Wire Makefile `help` / README / `AGENTS.md` for `ota-package`

## 4. Board staged apply + progress

- [x] 4.1 **Dart closed loop:** `cyber_ota` owns verify/extract/apply; retired board `ab-upgrade-*.sh` / `ab-ota-verify.sh`; keep `ab-preflight` + `ab-boot-confirm`
- [x] 4.2 Support extract of OTA `tar.gz` under `/userdata/ota/` (Dart `tar`)
- [x] 4.3 Emit write progress like host `stream-file-progress.py` (per-image chunked file→`dd` stdin; extract archive-byte progress; debug → `ota.log`; **no** `progress.json`)
- [x] 4.4 Keep A/B safety invariants (Dart `AbSlot`)
- [x] 4.5 Support OEM-only apply + plain reboot for `OEM_ONLY=1` (still verify on SSH)
- [x] 4.6 Retire default stream-to-partition full-system path from helpers/docs comments

## 5. `packages/cyber_ota`

- [x] 5.1 Scaffold `packages/cyber_ota` path package
- [x] 5.2 Implement manifest fetch/parse + version compare
- [x] 5.3 Implement CloudIngress: download `tar.gz` + `.sig`, transferring progress
- [x] 5.4 Implement HostHttpIngress: HTTP pull from host ephemeral server; **require verify** (same gate as cloud)
- [x] 5.5 Implement verifyPackage for cloud **and** host; extractPackage; applyImages
- [x] 5.6 Unit tests: version compare, progress machine, verify failure refuses apply (cloud + host)

## 6. HMI UI + App wiring

- [x] 6.1 Add `cyber_ota` path dependency to `app/lws_hmi`
- [x] 6.2 Safe shutdown → dedicated upgrade page (no Home intermediate)
- [x] 6.3 Upgrade page: download; **verify (cloud + host)**; extract; burn (rootfs/kernel/oem labels); no laser controls; non-cancelable during write
- [x] 6.4 Host-upgrade trigger watcher → safe shutdown → transferring
- [x] 6.5 Wire Settings Check for Updates / auto-check
- [x] 6.6 Mutex whole-device OTA vs control-board flash
- [x] 6.7 l10n for check/update/download/burn/failure states

## 7. Host `make upgrade` unification

- [x] 7.1 Make `make upgrade` run `make ota-package` first (unless alternate package input)
- [x] 7.2 Rewrite `upgrade-remote.sh`: host HTTP serve `tar.gz`+`.sig`, trigger device download, verify+extract/apply
- [x] 7.3 Fail on missing archive **or `.sig`**; `UPGRADE_PACKAGE` → default sibling `<path>.sig`; preserve `OEM_IMG=` / `OEM_ONLY=1` / preflight
- [x] 7.4 Update Makefile help / README / AGENTS for staged **signed** SSH upgrade (host HTTP + device pull)
- [x] 7.5 Update `docs/storage-layout.md` for staged path + SSH/cloud both verify (RockUSB/`flash` unsigned)

## 8. Cloud WebSocket OTA commands

- [x] 8.1 Implement `command.check_update` via `cyber_ota`
- [x] 8.2 Implement `command.update_system` (safe shutdown + upgrade page + download + **verify** + apply)
- [x] 8.3 Emit `device.update_progress` from `cyber_ota` events
- [x] 8.4 Align ack shapes with lws-ui / network-api reference

## 9. Verification

- [ ] 9.1 Lab: `make upgrade` on work screen → upgrade page download → **verify with `.sig`** → try-boot
- [ ] 9.2 Lab: cloud/Settings **and** host SSH with bad `.sig` refuses write; good `.sig` applies
- [ ] 9.3 Lab: upgrade page cannot start laser/job
- [ ] 9.4 Lab: WS check_update / update_system / update_progress smoke
- [x] 9.5 Confirm `make push-app` remains hot-swap outside whole-device gate
- [x] 9.6 Confirm `make ota-package` is prerequisite for `make publish` (with `.sig`)
- [x] 9.7 Archive change when acceptance complete
