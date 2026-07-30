# AGENTS.md

Instructions for coding agents working in **lws-hmi**. Human-oriented overview and long command lists live in [`README.md`](README.md); this file adds agent-specific rules agents should follow automatically.

## Project overview

- **What:** Buildroot-based **embedded appliance OS** for Innohi boards (benchmark: **ynh960/961/962**) + Flutter HMI (`app/lws_hmi/`). Direction: shared **CyberUI** + **`cyber_hal`** Dart package (submodule/packages), per-product Apps, board profiles for new motherboards/panels. **No** Rust `hald` Platform API.
- **Board SKUs (current line):** ynh960 → RK3566 (entry); ynh962 → RK3568B2 (mid); ynh961 → RK3568 (high). Same product line; **one firmware image is the near-term goal** for this line. **Validate on ynh960** — no per-SKU defconfig fork yet. Future products may use different boards/screens via packs + HAL package.
- **Phase roadmap:** See `docs/flutter-linux-hmi-plan.md` §1 (P1–P2.5 + **P3.1 HAL** done; **P3.2** W4 archived; **P3.0 CyberUI/IME** and **P4** in progress — IPC **MediaMTX App-owned** via `cyber_pm` + `/opt/hmi/bin`; next **P3.3 AI** reuses `cyber_pm`, remaining P4 slices, P5.0 Android App/APK — not `cyber_hal` Android backends, P5.1 engine). HAL design: `openspec/changes/archive/2026-07-18-dart-hal-package/`. `cyber_hal` is Linux (+ stub) only.
- **Hosts:** Linux builds natively in `linux-sdk/`; macOS uses Docker `linux/amd64` + a Docker volume for the SDK tree.
- **Outputs:** `output/firmware/boot.img` (FIT for `rootfs_a`), `boot_b.img` (same kernel, FIT for `rootfs_b`), `rootfs.img`, per-SKU `output/firmware/<sku>/factory.img` (oem+uboot+A/B), and migration symlink `update.img` → default sku `factory.img`; Linux also has artifacts under `linux-sdk/output/firmware/`.
- **Scope:** Active Buildroot packages follow `#include` lines in `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig`.

## Dev environment tips

- Run `make help` for the authoritative Makefile target list.
- First time: `make setup`, then `make build-deps`, then `make build` (macOS: `make docker-volume-init` before build).
- The Rockchip SDK is fixed at repo-root `linux-sdk/` (**gitignored** until S4). Override the Flutter SDK via repo-root `.env` or `FLUTTER_SDK` (default: `flutter-sdk/`). Other common settings are `BUILD_JOBS` and **`SN=`** (device selection). Use **`CHIPID=`** when selecting by chip ID only on multi-board. See README Make commands / `make devices`. macOS: prefer Docker volume over `BUILD_BIND_MOUNT=1` (bind-mount often crashes Docker Desktop during Buildroot).
- **Device tree / kernel fragments (until `linux-sdk` is committed):** git source of truth is **`overlay/kernel/`**, not the local SDK tree and **not** `oem/`. After editing overlay DTS, run `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or `make squash-linux-sdk-platform`) then `make build-kernel`. Boot DTBs stay in the FIT; OEM only has runtime LCD params / profile. Detail: [`docs/linux-sdk-vendor-import.md`](docs/linux-sdk-vendor-import.md).
- Flutter app work: host needs pinned `flutter` (`make fetch-flutter-sdk` / `make build-dev-deps`); packaging is `scripts/hmi-bundle-common.sh` via `make build-app`.
- Do not commit unless the user explicitly asks.

## Build commands

Full cookbook: **README.md → Make commands**. Quick reference:

```bash
make build
make show-config
```

First-time dependencies:

```bash
make build-deps
make check-prebuilt
```

Daily iteration examples (one command per line; run in order):

```bash
# Flutter app only (board already has a working rootfs)
make build-app
make push-app

# Kernel / DTS / boot logo
make build-boot-logo
make build-kernel
make build-rootfs
make upgrade

# Overlay / systemd / LCD params (not app bundle)
make apply-overlay
make build-rootfs
make upgrade

# Or, for factory/USB deployment after any sequence above:
make build-img
make reboot-loader
make flash
```

More detail: [`docs/build-optimization.md`](docs/build-optimization.md), [`app/README.md`](app/README.md).

**Pipeline rules (do not get wrong):**

- `make build-app` updates overlay `/opt/hmi` and runs `apply-overlay`; it does **not** rebuild rootfs.
- App-only daily iteration: `make build-app` then `make push-app` (SSH hot-swap `/opt/hmi`). Do **not** require `build-rootfs` / `upgrade` unless baking the app into a release image or the board lacks a pushable HMI.
- `make build-kernel` builds two hash-valid FITs containing the same Linux kernel: `boot.img` selects `rootfs_a`; `boot_b.img` selects `rootfs_b`. Publishes them to `output/firmware/` (macOS Docker volume auto-export).
- `make build-rootfs` bakes fs-overlay (including `/opt/hmi`) into rootfs and publishes `output/firmware/rootfs.img`.
- **Buildroot package incremental reuse (easy to miss):** Rockchip `./build.sh rootfs` / `make build-rootfs` **reuses already-built packages** in `buildroot/output/...` when their stamps look clean. Changing a Kconfig fragment under `overlay/buildroot/chips/*.config` (e.g. enabling `BR2_PACKAGE_WPA_SUPPLICANT_DBUS`) + `apply-overlay` updates the defconfig / may refresh output `.config`, but **does not rebuild** the package binary. Overlay-only script changes are fine with `apply-overlay` → `build-rootfs`; **option / recipe changes that alter how a package is compiled** need an explicit package rebuild first: `bash scripts/br-make-packages.sh <label> <pkg>…` (re-applies defconfig, **`*-dirclean` each pkg**, then `make <pkg>`), then `make build-rootfs`. Example: `bash scripts/br-make-packages.sh wpa wpa_supplicant`. Verify D-Bus wpa on **device** (`wpa_supplicant -h | grep -- -u`) or `strings` — do not run the aarch64 binary on the macOS/x86 host. This is **userspace Buildroot**, not `make build-kernel`. Nuclear option only when intentionally wiping: `make clean-buildroot-output` → `make lunch` → `make build-rootfs`.
- `make build-img` does **not** compile kernel or rootfs; it requires `make build-oem` first, then packages loader/U-Boot/misc/dual-FIT/rootfs/**oem** into `output/firmware/<FACTORY_SKU>/factory.img` (and refreshes `update.img` as a symlink).
- Full-system `make upgrade` does **not** send `factory.img`; it **streams** `rootfs.img` and the inactive letter’s FIT into partitions (helpers only under `/userdata/ota/`), and by default also streams resolved `oem.img` when present (`OEM_IMG= make upgrade` to skip). Env: `OEM_ONLY=1` (or in `.env`) for oem-only stream. Starts board `arm-reboot` and returns immediately (does not wait for SSH drop or post-reboot health). Online OTA stays download-then-staged-apply via `ab-upgrade-apply.sh`.
- **OEM-only iteration:** when changing only `oem/**` (board helpers, profile, screen pack, `product.ini` seed), run `make build-oem` then **`OEM_ONLY=1 make upgrade`** (or set `OEM_ONLY=1` in `.env`). This streams `oem.img` into `PARTLABEL=oem` and does a **plain reboot** (no A/B letter switch, no boot/rootfs write). Prefer this over a full `make upgrade` during OEM debug.
- Prefer `make upgrade` for rootfs/kernel daily iteration after the board has the P2.4 GPT/helpers. Always run `make build-oem` + `make build-img` when producing a release/factory artifact; use `make reboot-loader` then `make flash` when validating that artifact. Do **not** require a manual `make docker-export-artifacts` after kernel/rootfs builds.

## Rebuild instructions for the user (required)

After **any non-docs code change**, end your reply with a **「重新构建」** block. The user does not know which paths you touched — list exact `make` lines, **one per line**, in order. Omit `make flash` if they build on Linux and flash elsewhere.

| What changed | Commands |
|--------------|----------|
| `app/lws_hmi/**`, `scripts/build-app.sh`, `scripts/hmi-bundle-common.sh`, `scripts/push-app.sh` | `make build-app`, `make push-app` |
| `app/lws_hmi/assets/process-library/**`, `app/lws_hmi/assets/firmware/control-board/**`, `scripts/prepare-hmi-ship-assets.sh`, `scripts/convert-process-library.py` | `make build-app` (runs prepare); or host-only `make prepare-app-assets` before local flutter test/IDE |
| `app/lws_hmi/lib/l10n/*.arb` (parent ARBs) | `make l10n` (then `make build-app` / `make push-app` to ship) |
| `scripts/flutter/l10n*.sh`, `sync_l10n_child_arbs.py`, `zh_s2t.py` | none for firmware; exercise `make l10n` / `make l10n-verify` |
| Bake app into rootfs / A/B image (release or no push path) | `make build-app`, `make build-rootfs`, `make upgrade` |
| `board/logo/**` | `make build-boot-logo`, `make build-kernel`, `make upgrade` — also refreshes Weston `boot-splash.png` in overlay; follow with `make build-rootfs`, `make upgrade` |
| `overlay/kernel/**`, kernel DTS | Owned SDK: `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or `make squash-linux-sdk-platform`), then `make build-kernel`, `make build-rootfs`, `make upgrade`. Git SoT remains `overlay/kernel/` until linux-sdk is committed — do not sync DT via OEM |
| `overlay/.../rootfs-overlay/**` (not app) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| USB plug-ssh (`overlay/kernel/**` + fs-overlay scripts/units) | `make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade` |
| `scripts/device-logs.sh` only (host log streaming) | none |
| `scripts/debug-app*.sh`, `scripts/debug-host-prepare.sh`, `scripts/debug-custom-device/**`, `scripts/debug-setup.sh`, `scripts/build-debug-app.sh`, `scripts/hmi-bundle-common.sh` (host only; board already has P1.5 overlay) | `make debug-setup`, `make debug-app` |
| `overlay/.../rootfs-overlay/**` debug scripts (`hmi-launch.sh`, `debug-app-*`, `hmi.service`) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `overlay/buildroot/**` (overlay paths / docs only; no package compile flags) | `make apply-overlay`, `make check-prebuilt`, `make build-rootfs`, `make upgrade` |
| `overlay/buildroot/chips/*.config` (or other BR Kconfig that changes how an **existing** package is built, e.g. `BR2_PACKAGE_WPA_SUPPLICANT_DBUS`) | `make apply-overlay`, `bash scripts/br-make-packages.sh <label> <pkg>…`, `make check-prebuilt`, `make build-rootfs`, `make upgrade` — **not** kernel; `build-rootfs` alone will keep the old binary |
| Default Weston rootfs (`chips/lws_hmi_wayland.config`, eLinux prebuilt, splash/`desktop-shell`) | `make build-flutter-embedded-linux` (first time / refresh), `make build-rootfs`, `make upgrade` |
| `prebuilt/**`, runtime recipes | `make build-runtime-deps` (or specific target), `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `prebuilt/btop/**`, `scripts/fetch-btop.sh`, or overlay `usr/bin/btop` | `make fetch-btop` (if binary missing), `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `prebuilt/umtprd/**`, `scripts/build-umtprd.sh`, or overlay `usr/bin/umtprd` / `usb-mtp-*.sh` | `make build-umtprd` (if binary missing), `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `board/*.txt` LCD/MIPI params | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `oem/**`, `scripts/build-oem.sh`, `scripts/factory-sku.sh`, `board/factory-skus.tsv` | `make build-oem`, then **`OEM_ONLY=1 make upgrade`** (oem partition only); use full `make upgrade` / `make build-img` + `make flash` only when also shipping OS or factory |
| `board/virt/**`, `scripts/build-emulator.sh`, `scripts/run-emulator.sh`, `scripts/setup-emulator-qemu.sh`, `scripts/fetch-emulator-swgl.sh`, `scripts/emulator-devices.sh`, `overlay/.../20-emulator-*.link`, `overlay/kernel/**/emulator-virtio.config` | macOS: `make setup-emulator-qemu`, `make fetch-emulator-swgl` (guest Mesa via 9p, not rootfs); virtio-sound needs kernel fragment → `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `make build-kernel`, then `make apply-overlay`, `make build-rootfs`, `make build-emulator`, `make emulator`; see `docs/p32-emulator.md` |
| `oem/**` sim_virt only | included by `make build-emulator`; or `OEM_ID=sim_virt make build-oem` |
| `overlay/.../oem-compose*` | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `packages/cyber_hal` profile APIs / App OEM load path | `make build-app`, `make push-app` |
| `packages/cyber_pm` (process supervisor) | `make build-app`, `make push-app` (host: `dart test` in package) |
| `prebuilt/mediamtx/**`, `scripts/build-mediamtx.sh`, App MediaMTX relay / `/opt/hmi/bin` | `make build-mediamtx` (if prebuilt missing), `make build-app`, `make push-app`; purge old rootfs binary/unit: `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `board/parameter-buildroot-fit.txt` (GPT / A/B) | `make apply-overlay`, `make build-oem`, `make build-img`, `make flash` (repartition once) |
| A/B upgrade helpers (`overlay/.../ab-*.sh`, `ab-boot-confirm.service`) | First adoption: `make apply-overlay`, `make build-rootfs`, `make build-oem`, `make build-img`, `make flash`; existing P2.4 board: `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `scripts/upgrade-remote.sh`, `scripts/stream-file-progress.py`, or Makefile `upgrade` only (board already has P2.4 overlay + A/B GPT) | `make upgrade` (or `OEM_ONLY=1 make upgrade`); no firmware rebuild unless image inputs are stale |
| Control-board host upgrade helper (`scripts/upgrade-control-board.sh`, Makefile `upgrade-control-board`) | none (host SSH writes `/run/hmi/upgrade-control-board.cmd` and uploads one control-board `.bin`); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); exercise `make upgrade-control-board` |
| Process-library host upgrade helper (`scripts/upgrade-process-library.sh`, Makefile `upgrade-process-library`) | none (reads device `product.ini` `model`, converts matching Excel, uploads package, writes `/run/hmi/upgrade-process-library.cmd`); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); exercise `make upgrade-process-library` |
| Process-library host reset helper (`scripts/reset-process-library.sh`, Makefile `reset-process-library`) | none (host SSH writes `/run/hmi/reset-process-library.cmd`; HMI clears DB and force-reimports bundled — no restart); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); exercise `make reset-process-library` |
| Host device registry/reboot paths (`scripts/ssh-devices.sh`, `scripts/emulator-devices.sh`, `scripts/flash-usb.sh`, `scripts/usb-ssh-*.sh`, `scripts/device-target.sh`) | no firmware rebuild; exercise `make devices` (SN + ChipID + EMU) / `SN=` or `CHIPID=` / `IP=127.0.0.1:2222` selection / `make reboot` / `make reboot-loader` |
| `product.ini` host tooling (`scripts/set-product-prop.sh`, `scripts/del-product-prop.sh`, Makefile `set-prop` / `del-prop`) | none (host SSH mutate tunables only; brand/model/sn refused); exercise `make set-prop` / `make del-prop` (multi-board: `SN=` / `CHIPID=` / `IP=`) |
| Demo alarm host tooling (`scripts/trigger-alarm.sh`, Makefile `alarm` / `alarm-clean`) | none (host SSH writes `/run/hmi/demo-alarm.cmd`); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); exercise `make alarm CODE=L001` / `make alarm-clean` |
| Alarm history SQLite (`SqliteAlarmLogRepository`, `/var/lib/hmi/alarm-logs.db`) | none beyond shipping App (`make build-app` / `make push-app`); board needs rootfs `libsqlite3` (already via platform packages) |
| Overlay `read-device-serial.sh` (product.ini `sn` preference) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| Release / factory artifact | Build all changed inputs + `make build-oem`, then `make build-img`; for hardware validation: `make reboot-loader`, `make flash` (`FACTORY_SKU=` / `IMAGE=`) |
| `fetch-*`, `extract-linux-sdk`, `trim-linux-sdk`, `check-linux-sdk`, `squash-linux-sdk-platform`, `build-dev-deps` only | no firmware rebuild; name the fetch/extract/trim/check target; after trim on macOS also `make docker-volume-init` or `make docker-volume-sync` |
| Docs only | none |

Example:

```text
重新构建（本次改动了 app）：
make build-app
make push-app
```

When unsure or on a clean tree: `make build`.

## Code conventions

- **Minimize scope** — smallest correct diff; no drive-by refactors.
- **Match existing style** in touched files (shell, Dart, Buildroot `.mk`, overlay layout).
- **Flutter App API = 3.24.4** — write `app/lws_hmi/` (and Flutter packages) against the pinned SDK only; do **not** follow newer Flutter/Material docs (e.g. do not replace `DropdownButtonFormField(value: …)` with `initialValue`). Detail: `.cursor/rules/flutter-3.24-api.mdc`. Upgrade path is P5.1, not drive-by API churn.
- **Script / device-command naming** — prefer **verb + noun** (kebab-case), no product prefix on script basenames. Operator commands → `/usr/bin/<verb-noun>` via `post-build.sh`. Helpers → **`/usr/libexec/{wpa,network,bluetooth,hmi}/`**. State → **`/var/lib/{wpa_supplicant,network,bluetooth,hmi}/`**. systemd units use **functional** names (`wlan-wpa.service`, `settings-restore.service`); UI daemon only: `hmi.service`.
- **Paths:** app → `app/lws_hmi/`; rootfs overlay → `overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/`; Buildroot fragments → `overlay/buildroot/`.
- **Do not** run `make build-uboot` on ynh960 unless Innohi instructs.
- OpenSpec workflow: `.cursor/skills/openspec-*` when the user uses that flow.

## Verification

Before finishing implementation work:

- Docs-only: no build required.
- `app/lws_hmi/`: `flutter analyze` / tests under `app/lws_hmi/` when Dart changed.
- Overlay/rootfs: `make build-rootfs` should pass `scripts/verify-rootfs-overlay.sh`.
- After flash (device): `verify-boot` (Plan A boot KPI); `verify-env` (§3.4 platform stack).

## Documentation maintenance

When adding or renaming a `make` target, update **all** of:

1. `Makefile` `help` text
2. `README.md` → **Make commands**
3. Rebuild table in this file (if it affects post-change user commands)

Keep long command examples in **README.md**; keep agent-only rules (rebuild block, pipeline gotchas) here. Use **one command per line** in user-facing examples (no `&&` chains).

## Repository map

| Path | Role |
|------|------|
| `app/lws_hmi/` | Flutter HMI → `overlay/.../opt/hmi`（含产品 `bin/`，如 mediamtx） |
| `packages/cyber_hal/` | Dart HAL path 包 |
| `packages/cyber_pm/` | 子进程监护（MediaMTX、日后 AI） |
| `packages/cyber_ui/` / `cyber_ime/` / `cyber_alarm/` | UI / IME / 告警引擎 |
| `overlay/.../rootfs-overlay/` | Rootfs overlay (systemd, scripts, `/opt/hmi` staging) |
| `overlay/buildroot/` | Defconfig fragments, package pins |
| `overlay/kernel/` | DTS / kernel config |
| `board/` | ynh960 defconfig, LCD params, boot logo |
| `prebuilt/` | Runtime binaries for rootfs |
| `scripts/apply-overlay.sh` | Patches SDK, syncs overlay into Buildroot |
| `Makefile` | All `make` targets |
