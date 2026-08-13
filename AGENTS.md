# AGENTS.md

Instructions for coding agents working in **lws-hmi**. Human-oriented overview and long command lists live in [`README.md`](README.md); this file adds agent-specific rules agents should follow automatically.

## Project overview

- **What:** Buildroot-based **embedded appliance OS** for Innohi boards (benchmark: **ynh960/961/962**) + Flutter HMI (`app/lws_hmi/`). Direction: shared **CyberUI** + **`cyber_hal`** Dart package (submodule/packages), per-product Apps, board profiles for new motherboards/panels. **No** Rust `hald` Platform API.
- **Board SKUs (current line):** ynh960 → RK3566 (entry); ynh962 → RK3568B2 (mid); ynh961 → RK3568 (high). Same product line; **one firmware image is the near-term goal** for this line. **Validate on ynh960** — no per-SKU defconfig fork yet. Future products may use different boards/screens via packs + HAL package.
- **Phase roadmap:** See `docs/flutter-linux-hmi-plan.md` §1 (P1–P2.5 + **P3.1 HAL** + **P3.2** W4 + **P3.3** AI daemon + **P4** business/UI/OTA done; **P5.1** Flutter **3.41.9** + eLinux **42d3d75a56**; **P3.0 CyberUI/IME** still optimizing; **P5.0** Android App/APK — not `cyber_hal` Android backends). HAL design: `openspec/changes/archive/2026-07-18-dart-hal-package/`. `cyber_hal` is Linux (+ stub) only. MediaMTX / AI via `cyber_pm` + `/opt/hmi/bin`; OTA: `archive/2026-08-06-unified-ota-cyber-ota`.
- **Hosts:** Linux builds natively in `linux-sdk/`; macOS uses Docker `linux/amd64` + a Docker volume for the SDK tree.
- **Outputs:** `output/firmware/boot.img` (FIT for `rootfs_a`), `boot_b.img` (same kernel, FIT for `rootfs_b`), `output/firmware/<APP>/rootfs.img` (default `APP=lws_hmi`), per-SKU `output/firmware/<APP>/<sku>/factory.img` (oem+uboot+A/B), and migration symlink `update.img` → default APP+sku `factory.img`; Linux also has artifacts under `linux-sdk/output/firmware/`.
- **Scope:** Active Buildroot packages follow `#include` lines in `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig`.

## Dev environment tips

- Run `make help` for the authoritative Makefile target list.
- First time: `make setup`, then `make build-deps`, then `make build` (macOS: `make docker-volume-init` before build).
- The Rockchip SDK is fixed at repo-root `linux-sdk/` (**gitignored** until S4). Host Flutter for builds: `.env` / `FLUTTER_SDK` (default `flutter-sdk/`). Install that tree with `make fetch-flutter-sdk` (`DEST=` override, like `extract-linux-sdk`). Other common settings are `BUILD_JOBS` and **`SN=`** (device selection). See README Make commands / `make devices`. macOS: prefer Docker volume over `BUILD_BIND_MOUNT=1` (bind-mount often crashes Docker Desktop during Buildroot).
- **Device tree / kernel fragments (until `linux-sdk` is committed):** git source of truth is **`overlay/kernel/`**, not the local SDK tree and **not** `oem/`. After editing overlay DTS, run `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or `make squash-linux-sdk-platform`) then `make build-kernel`. Boot DTBs stay in the FIT; OEM only has runtime LCD params / profile. Detail: [`docs/linux-sdk-vendor-import.md`](docs/linux-sdk-vendor-import.md).
- Flutter app work: host needs pinned `flutter` (`make fetch-flutter-sdk` / `make build-dev-deps`); packaging is `scripts/hmi-bundle-common.sh` via `make build-app`.
- Do not commit unless the user explicitly asks.

## Build commands

Full cookbook: **README.md → Make commands**. Per-target usage / env vars: **[`docs/make-commands.md`](docs/make-commands.md)**. Quick reference:

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
make push-app                   # Debug unsigned hot-swap
# make upgrade-app              # signed ship (needs OTA_SIGNING_KEY)

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

- `make build-app` updates the selected app’s overlay install tree and runs `apply-overlay`; it does **not** rebuild rootfs. Default `APP=lws_hmi`. **Convention:** Flutter dirs ending in `_hmi` install to `/opt/hmi` (for `hmi.service`); one rootfs has at most one HMI app plus optional `os_settings` at `/opt/os_settings`.
- App-only daily iteration: `make build-app` then **`make push-app`** (unsigned Debug hot-swap into `/opt/hmi`) or **`make upgrade-app`** (signed HTTP + device download). Do **not** require `build-rootfs` / `upgrade` unless baking the app into a release image or the board lacks a pushable HMI.
- `make build-rootfs` ensures the selected `APP` is in overlay; if `app/os_settings` exists it also ensures `/opt/os_settings` (no `APP=` needed for that auto-include). Selecting `APP=cnc_hmi` (etc.) replaces `/opt/hmi` with that product. **Does not** run `apply-overlay` (except `ensure-rootfs-apps` when it had to build a missing app). After overlay/DTS/fs-overlay changes: `make apply-overlay` then `make build-rootfs`. macOS `docker-run` defaults to `SKIP_OVERLAY=1` (no auto-apply on every build).
- `make build-kernel` builds two hash-valid FITs containing the same Linux kernel: `boot.img` selects `rootfs_a`; `boot_b.img` selects `rootfs_b`. FITs are **multi-configuration** (W5): conf name = `board_id` from `board/rk356x-fit-boards.txt` (default `ynh960`). Publishes bare `Image` alongside for P3.2 emulator. Artifacts go to `output/firmware/` (macOS Docker volume auto-export). Inspect: `bash scripts/verify-boot-fit.sh output/firmware`.
- **`make build-kernel` = Image (optional) + DTB/FIT (always).** `scripts/build-kernel-ab.sh` runs two phases:
  1. **Shared `Image` + `resource.img`** — `./build.sh kernel` inside the SDK. **Skipped** when `linux-sdk/kernel/arch/arm64/boot/Image` already exists and `FORCE_KERNEL_IMAGE` is unset. Log: `kernel Image present — skip ./build.sh kernel`.
  2. **Per-slot DTB + FIT** — always runs: force-rebuild inventory DTBs (bootargs `PARTLABEL=rootfs_a|b`), stage DTBs, repack `boot.img` / `boot_b.img`. A+B slots run **in parallel**; either failure kills the other. Targets: `make build-kernel` (both), `make build-kernel-a`, `make build-kernel-b`.
- **When plain `make build-kernel` is enough** (no `FORCE_KERNEL_IMAGE=1`): changes that affect **DTBs / FIT packaging only** — `overlay/kernel/**/*.dts*` (panel, pinmux, regulators, *not* Kconfig fragments), `ynh960-linux-root.dtsi` bootargs edits, `board/rk356x-fit-boards.txt`, `board/boot-multi.its`, FIT verify/pack scripts. After `apply-overlay`, one `make build-kernel` rebuilds DTBs and both FITs while reusing the existing `Image` (fast daily path).
- **When you must set `FORCE_KERNEL_IMAGE=1`** (full `./build.sh kernel`):
  - First kernel build, or `Image` was deleted / clean SDK tree.
  - `overlay/kernel/**/*.config` Kconfig fragments (drivers, `CONFIG_*`, emulator virtio, SELinux, hardening, OP-TEE, USB gadget, …). `apply-overlay` may drop stale `.config`, but **Image skip still applies** until `FORCE_KERNEL_IMAGE=1`.
  - Kernel **patches** or **driver/C source** under `overlay/kernel/` (not device-tree-only).
  - **`board/logo/**`** (boot logo baked into kernel `resource.img`).
  - Any change that must ship new **built-in code or `.ko` modules** in the boot FIT, not just DTB strings.
  - Command: `FORCE_KERNEL_IMAGE=1 make build-kernel` (passed into Docker via `scripts/docker-run.sh`).
- **Rule of thumb:** DTS / FIT inventory → `make build-kernel`; Kconfig / drivers / logo / modules → `FORCE_KERNEL_IMAGE=1 make build-kernel`. When unsure after a kernel fragment change, use `FORCE_KERNEL_IMAGE=1` once, then return to plain `make build-kernel` for DTB-only edits. Git SoT for kernel/DTS: `overlay/kernel/` (not OEM); apply with `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` before build.
- `make build-rootfs` bakes fs-overlay (including `/opt/hmi`) into rootfs and publishes `output/firmware/<APP>/rootfs.img` (boot FITs remain shared under `output/firmware/`). Packs **ext2 only** (cpio/squashfs/tar unset in `chips/lws_hmi_rootfs.config`); after changing those Kconfig bits run `make apply-overlay` + `make lunch` before the next rootfs.
- **Buildroot package incremental reuse (easy to miss):** Rockchip `./build.sh rootfs` / `make build-rootfs` **reuses already-built packages** in `buildroot/output/...` when their stamps look clean. Changing a Kconfig fragment under `overlay/buildroot/chips/*.config` (e.g. enabling `BR2_PACKAGE_WPA_SUPPLICANT_DBUS`) + `apply-overlay` updates the defconfig / may refresh output `.config`, but **does not rebuild** the package binary. Overlay-only script changes are fine with `apply-overlay` → `build-rootfs`; **option / recipe changes that alter how a package is compiled** need an explicit package rebuild first: `bash scripts/br-make-packages.sh <label> <pkg>…` (re-applies defconfig, **`*-dirclean` each pkg**, then `make <pkg>`), then `make build-rootfs`. Example: `bash scripts/br-make-packages.sh wpa wpa_supplicant`. Verify D-Bus wpa on **device** (`wpa_supplicant -h | grep -- -u`) or `strings` — do not run the aarch64 binary on the macOS/x86 host. This is **userspace Buildroot**, not `make build-kernel`. Nuclear option only when intentionally wiping: `make clean-buildroot-output` → `make lunch` → `make build-rootfs`.
- `make build-img` does **not** compile kernel or rootfs; it requires `make build-oem` first, then packages loader/U-Boot/misc/dual-FIT/APP rootfs/**oem** into `output/firmware/<APP>/<FACTORY_SKU>/factory.img` (and refreshes `update.img` as a symlink).
- Full-system `make upgrade` does **not** send `factory.img`. **SSH:** runs `make pack-ota` (unless `UPGRADE_PACKAGE=` + sibling `.sig`), starts an ephemeral host HTTP server for the archive+`.sig`, triggers the HMI to **HTTP download** into `/userdata/ota/` (`download <url>` on `/run/hmi/upgrade-ota.cmd`), then device Ed25519-verify + staged extract/apply writes inactive boot+rootfs (+ optional oem). SSH is control-plane only (not bulk transfer). Bind defaults: USB-SSH `192.168.55.2`; LAN = local source IP toward the board (`OTA_HTTP_HOST=` / `OTA_HTTP_PORT=` override). **RockUSB Loader/Maskrom:** `upgrade_tool di` of OTA-equivalent images (`boot`/`boot_b`/both rootfs letters/optional oem); with `UPGRADE_PACKAGE=` host extracts then `di` (`.sig` not required); Maskrom may `ul` MiniLoader into RAM only — not `uf` / not uboot/GPT/misc. Env: `OEM_ONLY=1` (or in `.env`) for oem-only (no auto-detect from archive members); `UPGRADE_TRANSPORT=auto|ssh|rockusb`. SSH path returns as soon as reboot-after-arm is requested (does not wait for SSH drop or post-reboot health). Cloud/Settings OTA uses the same staging + verify shape. Use the same `APP=` as `build-rootfs` for `upgrade` / `flash` / `build-img`.
- **OEM-only iteration:** when changing only `oem/**` (board helpers, profile, screen pack), run `make build-oem` then **`OEM_ONLY=1 make upgrade`** (or set `OEM_ONLY=1` in `.env`). This packages/serves/applies `oem.img` only (SSH: staged apply + plain reboot; RockUSB: `di` oem). Prefer this over a full `make upgrade` during OEM debug.
- Prefer `make upgrade` for rootfs/kernel daily iteration after the board has the P2.4 GPT/helpers (SSH when up; RockUSB when in Loader/Maskrom). Always run `make build-oem` + `make build-img` when producing a release/factory artifact; use `make reboot-loader` then `make flash` when validating that artifact. Do **not** require a manual `make docker-export-artifacts` after kernel/rootfs builds.

## Rebuild instructions for the user (required)

After **any non-docs code change**, end your reply with a **「重新构建」** block. The user does not know which paths you touched — list exact `make` lines, **one per line**, in order. Omit `make flash` if they build on Linux and flash elsewhere.

| What changed | Commands |
|--------------|----------|
| `app/lws_hmi/**`, `scripts/build-app.sh`, `scripts/hmi-bundle-common.sh`, `scripts/upgrade-app.sh`, `scripts/pack-app.sh`, `scripts/push-app.sh`, `scripts/app-select.sh` | `make build-app`, then `make push-app` (Debug unsigned) or `make upgrade-app` (signed). Other apps: `APP=<id> make build-app` / `push-app` / `upgrade-app` (`APP=os_settings` → `os-settings.service`) |
| `overlay/.../usr/libexec/hmi/push-app-apply-and-restart.sh` | `make apply-overlay`, `make build-rootfs`, `make upgrade` (push-app also refreshes the helper from overlay each push) |
| `app/os_settings/**` | `APP=os_settings make build-app`, then `APP=os_settings make push-app` (restarts `os-settings.service`); rootfs auto-includes when source exists: `make build-rootfs` |
| `app/lws_hmi/assets/process-library/**`, `app/lws_hmi/assets/firmware/control-board/**`, `app/lws_hmi/assets/firmware/camera/**`, `scripts/prepare-hmi-ship-assets.sh`, `scripts/convert-process-library.py` | `make build-app` (runs prepare); or host-only `make prepare-app-assets` before local flutter test/IDE |
| `app/lws_hmi/lib/l10n/*.arb` (parent ARBs) | `make l10n` (then `make build-app` / `make upgrade-app` to ship) |
| `scripts/flutter/l10n*.sh`, `sync_l10n_child_arbs.py`, `zh_s2t.py` | none for firmware; exercise `make l10n` / `make l10n-verify` |
| `scripts/flutter/check_no_bare_font_size.sh` | none for firmware; exercise `make check-typography` (bare `fontSize: N` + business `AppTypography.*Size`) |
| Bake app into rootfs / A/B image (release or no push path) | `make build-app`, `make build-rootfs`, `make upgrade` (same `APP=`) |
| `scripts/upgrade-remote.sh`, `scripts/flash-usb.sh`, `scripts/docker-export-artifacts.sh`, `scripts/factory-sku.sh` (APP-scoped rootfs/factory paths) | `make build-rootfs`, then `make upgrade` or `make build-img` + `make flash` (same `APP=`) |
| `tools/upgrade_tool/**` (host RockUSB CLI only) | none for firmware; exercise `make devices` / `make flash` on the host OS |
| `board/logo/**` | `make build-boot-logo`, `make build-kernel`, `make upgrade` — also refreshes Weston `boot-splash.png` in overlay; follow with `make build-rootfs`, `make upgrade` |
| `board/rk356x-fit-boards.txt`, `board/boot-multi.its`, `scripts/generate-boot-fit-its.sh`, `scripts/pack-boot-fit-multi.sh`, `scripts/verify-boot-fit.sh`, `scripts/build-kernel-ab.sh` (W5 multi-DT FIT) | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `make build-kernel` (or `make build-kernel-a` / `make build-kernel-b`), `make upgrade` |
| `overlay/kernel/**` DTS / `.dtsi` only (no `*.config` fragment change) | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or `make squash-linux-sdk-platform`), then `make build-kernel`, `make upgrade` |
| `overlay/kernel/**/*.config`, kernel patches, or driver recompile | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, then **`FORCE_KERNEL_IMAGE=1 make build-kernel`**, `make upgrade` |
| `overlay/.../rootfs-overlay/**` provision mount/bind (`provision-mount.sh`, `bind-prefs.sh`, `factory-reset.sh`, `read/write-product-identity.sh`) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `scripts/verify-no-vendor-payload.sh`, `scripts/verify-firmware-partitions.sh` (provision gate) | none for board until `build-img` / `flash`; exercise `make build-img` |
| `overlay/.../rootfs-overlay/**` (not app) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| USB plug-ssh (`overlay/kernel/**` + fs-overlay scripts/units) | `make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade` |
| `scripts/device-logs.sh` only (host log streaming) | none |
| `scripts/debug-app*.sh`, `scripts/prepare-debug-host.sh`, `scripts/debug-custom-device/**`, `scripts/debug-setup.sh`, `scripts/build-debug-app.sh`, `scripts/hmi-bundle-common.sh` (host only; board already has P1.5 overlay) | `make debug-setup`, `make debug-app` |
| `overlay/.../rootfs-overlay/**` debug scripts (`hmi-launch.sh`, `debug-app-*`, `hmi.service`) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `overlay/buildroot/**` (overlay paths / docs only; no package compile flags) | `make apply-overlay`, `make check-prebuilt`, `make build-rootfs`, `make upgrade` |
| `overlay/buildroot/chips/*.config` (or other BR Kconfig that changes how an **existing** package is built, e.g. `BR2_PACKAGE_WPA_SUPPLICANT_DBUS`) | `make apply-overlay`, `bash scripts/br-make-packages.sh <label> <pkg>…`, `make check-prebuilt`, `make build-rootfs`, `make upgrade` — **not** kernel; `build-rootfs` alone will keep the old binary |
| `overlay/buildroot/chips/lws_hmi_font.config` / `package/source-han-sans-cn` / apply-overlay wiring of `package/source-han-sans` into `package/Config.in` (CJK fonts) | `make apply-overlay`, `bash scripts/br-make-packages.sh fonts source-han-sans-cn`, `make build-rootfs`, `make upgrade` — without Config.in `source`, `BR2_PACKAGE_SOURCE_HAN_SANS_CN=y` is dropped and rootfs has DejaVu only (中文方框) |
| Owned `linux-sdk/buildroot` LTS tip bump (`overlay/buildroot/BUILDROOT_VERSION`, major series e.g. 2024.02 → 2025.02.x) | `make clean-buildroot-output` (macOS cleans Docker volume), sync rebased tree into volume if needed, `make apply-overlay`, `make lunch`, then `make build-rootfs`, `make upgrade` — **do not** reuse old-series `buildroot/output` stamps; optional `FORCE=1 make build-gstreamer` / `FORCE=1 make rebuild-flutter-embedded-linux` when staging ABI changes |
| `overlay/buildroot/package/gstreamer1/**`, `overlay/buildroot/package/meson/**`, `overlay/third-party/gstreamer.version`, `scripts/build-gstreamer.sh`, `scripts/export-runtime-prebuilt.sh` (GStreamer pin) | `make apply-overlay`, `FORCE=1 make build-gstreamer`, `FORCE=1 make rebuild-flutter-embedded-linux`, `make apply-overlay`, `make build-rootfs`, `make upgrade` — **not** rootfs alone (prebuilt stamp reuse) |
| `overlay/buildroot/flutter-*.version`, `overlay/buildroot/package/flutter-engine/**`, or engine prebuilt refresh | `FORCE=1 make build-flutter-engine`, `FLUTTER_ENGINE_RUNTIME_MODE=debug FORCE=1 make build-flutter-engine`, `FORCE=1 make build-flutter-embedded-linux`, then commit both `prebuilt/flutter-engine/<ver>/arm64-{release,debug}/` (+ eLinux); ship rootfs: `make build-app`, `make build-rootfs`, `make upgrade` |
| `overlay/buildroot/package/bluez5_utils/**`, `overlay/buildroot/package/bluez5_utils-headers/**`, or `chips/lws_hmi_bt.config` BlueZ options | `make apply-overlay`, `bash scripts/br-make-packages.sh bluez bluez5_utils bluez5_utils-headers bluez-alsa`, `make build-rootfs`, `make upgrade` — **not** rootfs alone (stamp reuse) |
| Default Weston rootfs (`chips/lws_hmi_wayland.config`, eLinux prebuilt, splash/`desktop-shell`) | `make build-flutter-embedded-linux` (first time / refresh), `make build-rootfs`, `make upgrade` |
| `prebuilt/**`, runtime recipes | `make build-runtime-deps` (or specific target), `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `prebuilt/btop/**`, `scripts/fetch-btop.sh`, or overlay `usr/bin/btop` | `make fetch-btop` (if binary missing), `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `prebuilt/umtprd/**`, `scripts/build-umtprd.sh`, or overlay `usr/bin/umtprd` / `usb-mtp-*.sh` | `make build-umtprd` (if binary missing), `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `native/reboot_loader/**`, `native/extract_video_frame/**`, `native/hmi_capture/**`, `native/emulator_tablet_to_touch/**`, `scripts/build-libexec-binaries.sh`, `scripts/build-hmi-capture.sh`, `prebuilt/{reboot_loader,extract_video_frame,hmi_capture,emulator_tablet_to_touch}/**`, or overlay libexec/lib copies | `make build-libexec-binaries`（`TOOL=hmi-capture` 或 `make build-hmi-capture`；`extract-video-frame`/`hmi-capture` 需先 `make build-gstreamer`），`make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `overlay/.../surface_gl.cc`（eLinux present-hook）或 `scripts/build-flutter-embedded-linux.sh` capture stamp | `FORCE=1 make rebuild-flutter-embedded-linux`, `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `packages/cyber_capture` / App capture watcher | `make build-app`, `make push-app`（native `.so` + patched `flutter-wayland-client` 需已在 rootfs） |
| `scripts/screenshot.sh`, `scripts/record-screen.sh`（host only; board has watcher + lib） | none for firmware; exercise `make screenshot` / `make record-screen` |
| `native/secrets_seal/**`, `scripts/build-secrets-seal.sh`, `prebuilt/secrets_seal/**`, overlay `usr/lib/optee_armtz/*.ta` / `usr/libexec/board/secrets-seal*` | `make build-secrets-seal`, `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `board/*.txt` LCD/MIPI params | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `oem/**`, `scripts/build-oem.sh`, `scripts/factory-sku.sh`, `board/factory-skus.tsv` | `make build-oem`, then **`OEM_ONLY=1 make upgrade`** (oem partition only); use full `make upgrade` / `make build-img` + `make flash` only when also shipping OS or factory |
| `board/virt/**`, `scripts/build-emulator.sh`, `scripts/run-emulator.sh`, `scripts/setup-emulator-qemu.sh`, `scripts/fetch-emulator-swgl.sh`, `scripts/emulator-devices.sh`, `overlay/.../20-emulator-*.link`, `overlay/kernel/**/emulator-virtio.config`, `overlay/.../provision-mount.sh`, `overlay/.../emulator-storage-init.*` | macOS: `make setup-emulator-qemu`, `make fetch-emulator-swgl` (guest Mesa via 9p, not rootfs); virtio-sound needs kernel fragment → `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `make build-kernel`, then `make apply-overlay`, `make build-rootfs`, `make build-emulator`, `make emulator`; see `docs/p32-emulator.md` |
| `oem/**` sim_virt only | included by `make build-emulator`; or `OEM_ID=sim_virt make build-oem` |
| `overlay/.../oem-compose*` | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `packages/cyber_hal` profile APIs / App OEM load path | `make build-app`, `make push-app` |
| `packages/cyber_hal` Secrets/KEK (`lib/secrets.dart`, software fallback) | `make build-app`, `make push-app` (host: `flutter test` in package); OP-TEE image path also needs overlay/kernel below |
| `packages/cyber_hal` cloud Ed25519 (`lib/src/secrets/cloud_ed25519_identity.dart`) + App `device_cloud_ed25519` / `cloud_local_runtime` | `make build-app`, `make push-app` (host: package + App unit tests); first ship of VS ID 22 helpers also needs overlay below |
| Board VS cloud-key helpers (`read/write-cloud-ed25519-sealed.sh`, `board/vendor-storage-ids.txt` ID 22) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `overlay/kernel/**/ynh960-optee.dtsi` + `chips/lws_hmi_optee.config` / `tee-supplicant.service` / `secrets-seal` | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `bash scripts/br-make-packages.sh optee optee-client`, `make build-kernel`, `make build-rootfs`, `make upgrade` |
| `overlay/kernel/**/ynh960-selinux.config` + `chips/lws_hmi_selinux.config` (SELinux permissive + auditd) | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `bash scripts/br-make-packages.sh selinux libselinux libsepol refpolicy policycoreutils libsemanage audit systemd`, force-rebuild AIC `.ko` if `CONFIG_SECURITY` just flipped (see [`docs/selinux.md`](docs/selinux.md) Wi‑Fi note), `make build-kernel`, `make build-rootfs`, `make upgrade` — **not** `make build-uboot` |
| Appliance Lynis hardening (`etc/modprobe.d/99-appliance-hardening.conf`, `etc/sysctl.d/99-appliance-hardening.conf`, `resolved.conf.d/10-appliance.conf`, `etc/audit/*`, `ynh960-hardening.config`) | `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `bash scripts/br-make-packages.sh selinux audit` (first auditd ship only), `make build-kernel`, `make build-rootfs`, `make upgrade` |
| `chips/lws_hmi_platform.config` rng-tools + jitterentropy (`rngd.service` preset) | `make apply-overlay`, `bash scripts/br-make-packages.sh rng rng-tools jitterentropy-library`, `make build-rootfs`, `make upgrade` — **not** rootfs alone (new BR packages) |
| `packages/cyber_pm` (process supervisor) | `make build-app`, `make push-app` (host: `dart test` in package) |
| `prebuilt/mediamtx/**`, `scripts/build-mediamtx.sh`, App MediaMTX relay / `/opt/hmi/bin` | `make build-mediamtx` (if prebuilt missing), `make build-app`, `make push-app`; purge old rootfs binary/unit: `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `native/lws_ai/**`, `scripts/build-opencv.sh`, `scripts/build-ai.sh`, `prebuilt/opencv/**`, `prebuilt/ai/**`, App `AiDaemonSupervisor` | Daily AI edits: `make build-ai` (incremental; keeps `.cache/lws_ai` cmake), then `make build-app`, `make push-app`. Force clean: `make rebuild-ai` / `FORCE=1 make build-ai`. First-time OpenCV/RKNN: `make fetch-opencv`, `make fetch-opencv-ximgproc`, `make fetch-rknn-rt`, `make build-opencv`, then `make build-ai`. Release gate: `REQUIRE_AI=1 make build-app` |
| `board/parameter-buildroot-fit.txt` (GPT / A/B / vendor0–3 / **provision**) | `make apply-overlay`, `make build-oem`, `make build-img`, `make flash` (one-time repartition for provision adoption; then `make write-identity`) |
| A/B helpers (`ab-slot-lib`, `ab-preflight`, `ab-boot-confirm`, `/etc/ota/ed25519.pub`) + `cyber_ota` App | First adoption: `make apply-overlay`, `make build-rootfs`, `make build-oem`, `make build-img`, `make flash`; existing P2.4 board: `make apply-overlay`, `make build-rootfs`, `make upgrade` (App: `make build-app`, `make push-app`) |
| `scripts/pack-ota.sh`, `scripts/ota-sign.sh`, `scripts/sign-keys.sh`, `scripts/ota-http-serve.py`, Makefile `pack-ota` / `sign-keys` | none for board until upgrade; exercise `make sign-keys`, `make pack-ota` (publish: `REQUIRE_OTA_SIG=1 OTA_SIGNING_KEY=…`); `make upgrade` runs packaging unless `UPGRADE_PACKAGE=` |
| `scripts/upgrade-remote.sh` (SSH host-HTTP + device pull / RockUSB di / `UPGRADE_PACKAGE=` extract), Makefile `upgrade` only (board already has P2.4 overlay + A/B GPT + OTA HMI) | `make upgrade` (or `OEM_ONLY=1 make upgrade` / `UPGRADE_PACKAGE=… make upgrade`); no firmware rebuild unless image inputs are stale; App must understand `download <url>` (`make build-app` / `push-app` if watcher is old) |
| `packages/cyber_ota` / App system OTA UI (`app/lws_hmi/lib/features/system_ota/**`) | `make build-app`, `make push-app` |
| `packages/cyber_upgrade_ui` (shared update check / multi-phase progress UX) + App OTA / control-board / camera-channel adapters | `make build-app`, `make push-app` (host: `flutter test` in package) |
| `packages/cyber_alarm_ui` (shared warn frost chrome) + App `WarnPresentation` / safety-ground frost adapters | `make build-app`, `make push-app` (host: `flutter test` in package) |
| `overlay/buildroot/chips/lws_hmi_platform.config` (openssl for OTA verify) | `make apply-overlay`, `bash scripts/br-make-packages.sh openssl libopenssl`, `make build-rootfs`, `make upgrade` |
| `scripts/upgrade-remote.sh` / `scripts/flash-usb.sh` RockUSB OTA-images path (`upgrade-ota` / `di`) | none for firmware; exercise `make upgrade` on Loader/Maskrom (or `UPGRADE_TRANSPORT=rockusb make upgrade`); no rebuild unless `boot.img` / `boot_b.img` / `rootfs.img` / oem are stale |
| Control-board host upgrade helper (`scripts/upgrade-control-board.sh`, Makefile `upgrade-control-board`) | none (host signs + HTTP serves `.bin`+`.sig`, SSH writes `download <url>` to `/run/hmi/upgrade-control-board.cmd`); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); needs `OTA_SIGNING_KEY`; exercise `make upgrade-control-board` |
| Camera host upgrade helper (`scripts/upgrade-camera.sh`, Makefile `upgrade-camera`) | none (host signs + HTTP serves `.zip`+`.sig`, SSH writes `download <url>` to `/run/hmi/upgrade-camera.cmd`); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); needs `OTA_SIGNING_KEY`; exercise `make upgrade-camera` |
| Peripheral firmware cloud publish (`scripts/publish-peripheral-firmware.sh`, `publish-control-board-firmware` / `publish-camera-firmware`) | none (host-only); signs + uploads to `lws-hmi/control-board/` or `lws-hmi/camera/` + `release.json`; needs token + `OTA_SIGNING_KEY`; exercise after `make login` |
| Process-library host upgrade helper (`scripts/upgrade-process-library.sh`, Makefile `upgrade-process-library`) | none (reads device Vendor Storage `model`, converts matching Excel, uploads package, writes `/run/hmi/upgrade-process-library.cmd`); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); exercise `make upgrade-process-library` |
| Process-library host reset helper (`scripts/reset-process-library.sh`, Makefile `reset-process-library`) | none (host SSH writes `/run/hmi/reset-process-library.cmd`; HMI clears DB and force-reimports bundled — no restart); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); exercise `make reset-process-library` |
| Secrets software→OP-TEE migrate (`scripts/migrate-secrets.sh`, Makefile `migrate-secrets`, App `MigrateSecretsCommandWatcher`) | none (host SSH writes `/run/hmi/migrate-secrets.cmd`; HMI re-seals Wi‑Fi vault + cloud Ed25519); board needs signed seal TA + HMI watcher (`make build-app` + `make push-app` once if stale); exercise `make migrate-secrets` / `SCOPE=wifi|cloud make migrate-secrets` |
| Host device registry/reboot paths (`scripts/ssh-devices.sh`, `scripts/emulator-devices.sh`, `scripts/flash-usb.sh`, `scripts/usb-ssh-*.sh`, `scripts/device-target.sh`) | no firmware rebuild; exercise `make devices` / `make setup-usb-ssh` / `make reboot` / `make reboot-loader` (Windows: Git Bash + Rockchip RNDIS drivers + `keys/ssh/id_ed25519`) |
| Team SSH key + rootfs pubkey auth (`keys/ssh/**`, `scripts/ssh-keys.sh`, overlay `/root/.ssh/authorized_keys`, `etc/ssh/sshd_config.d/50-ssh-auth.conf`, `scripts/usb-ssh-common.sh`) | host: obtain `id_ed25519` internally or `make ssh-keys`; ship: `make apply-overlay`, `make build-rootfs`, `make upgrade` (lost key: TTL serial → rewrite authorized_keys; no field recovery) |
| Host serial console (`scripts/serial-console.sh`, `scripts/serial-hex-console.py`, Makefile `serial-console` / `serial-ports`; `MODE=TTL\|RS485\|RS232`) | none (host-only; TTL=miniterm, RS485/RS232=curses hex+TX bar via pyserial venv); exercise `make serial-console` / `make serial-ports` |
| `properties.ini` host tooling (`scripts/set-product-prop.sh`, `scripts/del-product-prop.sh`, Makefile `set-prop` / `del-prop`) | none (host SSH mutate `/var/lib/hal/properties.ini` tunables only; brand/model/sn refused → `make write-identity`); exercise `make set-prop` / `make del-prop` (multi-board: `SN=` / `IP=`) |
| Vendor Storage identity (`scripts/write-identity.sh`, Makefile `write-identity`, board helpers `read/write-product-identity`, `board/vendor-storage-ids.txt`, `board/parameter-buildroot-fit.txt` vendor0–3) | GPT adopt: `make build-oem`, `make build-img`, `make flash`; rootfs tool: `make apply-overlay`, `bash scripts/br-make-packages.sh rktoolkit rktoolkit`, `make build-rootfs`, `make upgrade`; then `make write-identity BRAND=… MODEL=… PRODUCT_SN=…` |
| Host cloud login / device register (`scripts/cloud-login.sh`, `scripts/register-device.sh`, `scripts/cloud-credentials.sh`, Makefile `login` / `register-device`) | none (host-only); exercise `make login` then `SN=… make register-device` (selection only; identity from board `read-identity`); token at `output/cloud/credentials.json` |
| Host cloud OTA publish (`scripts/publish-ota.sh`, `scripts/publish_ota.py`, Makefile `publish` / `publish-only`) | none (host-only); needs signed `pack-ota` + token; exercise `make login` (or `PUBLISH_API_TOKEN=`), then `OTA_SIGNING_KEY=… make publish` / `make publish-only` (always `release.json`; `APP=`, `CLOUD_API_BASE=` optional; do not set `RELEASE=`) |
| Host app/OS version (`scripts/app-version.sh`, Makefile `version` / `version-bump`, overlay `etc/os-release`) | none for Flutter bump; OS stamp bake: `make apply-overlay`, `make build-rootfs`, `make upgrade`. Default `make version` / `version-bump` → OS `VERSION=`; `APP=<id> make version` / `version-bump VERSION=…` → Flutter HMI (`kHmiVersion`). Ship HMI via `make build-app` / `upgrade-app` when needed |
| Host HMI app OTA (`scripts/upgrade-app.sh`, `pack-app.sh`, `publish-app.sh`, App `hmi_app_ota/**`) | signed: `make build-app`, `make upgrade-app`; CDN: `make publish-app`; debug hot-swap: `make push-app` |
| `packages/cyber_ota` / App system OTA UI (`app/lws_hmi/lib/features/system_ota/**`) | `make build-app`, `make upgrade-app` (whole-device channel gates on OS Version) |
| Demo alarm host tooling (`scripts/trigger-alarm.sh`, Makefile `alarm` / `alarm-clean`) | none (host SSH writes `/run/hmi/demo-alarm.cmd`); board needs HMI with watcher (`make build-app` + `make push-app` once if app is stale); exercise `make alarm CODE=L001` / `make alarm-clean` |
| AI offline RKNN smoke (`scripts/smoke-ai-offline-infer.sh`, Makefile `smoke-ai`, `native/lws_ai/assets/img/stain_demo*.jpg`, `native/lws_ai/tools/smoke/`) | none (host uploads demo JPG + talks to `/run/hmi/ai/cmd.sock`); board needs AI daemon (`make build-app` + `make push-app` once if stale); exercise `make smoke-ai` |
| Host security audit (`scripts/audit-lynis.sh`, `scripts/audit-cve.sh`, `scripts/fetch-cve-db.sh`, `scripts/lynis-custom.prf`, Makefile `audit` / `audit-cve` / `fetch-cve-db`) | none for firmware; exercise `make audit` (ephemeral Lynis upload) / `make fetch-cve-db` then `make audit-cve` (needs prior `make build-rootfs`; host syft/grype/cve-bin-tool) |
| Alarm history SQLite (`SqliteAlarmLogRepository`, `/var/lib/hmi/alarm-logs.db`) | none beyond shipping App (`make build-app` / `make push-app`); board needs rootfs `libsqlite3` (already via platform packages) |
| Overlay `read-device-serial.sh` / identity helpers (Vendor Storage SN) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `tee-supplicant.service` / `tee-supplicant-start.sh` / seal KEK (REE cache `/userdata/tee`; SoT = VS ID 23 HUK wrap) | `make build-secrets-seal`, `make apply-overlay`, `make build-rootfs`, `make upgrade`; field: `make migrate-seal-kek` |
| `board/vendor-storage-ids.txt` ID 23 + `read/write-seal-kek-wrapped` | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| Release / factory artifact | Build all changed inputs + `make build-oem`, then `make build-img`; for hardware validation: `make reboot-loader`, `make flash` (`APP=` / `FACTORY_SKU=` / `IMAGE=`) |
| `fetch-*`, `extract-linux-sdk`, `trim-linux-sdk`, `check-linux-sdk`, `squash-linux-sdk-platform`, `build-dev-deps` only | no firmware rebuild; name the fetch/extract/trim/check target; after trim on macOS also `make docker-volume-init` or `make docker-volume-sync` |
| Docs only | none |

Example:

```text
重新构建（本次改动了 app）：
make build-app
make push-app
```

（签名发布用 `make upgrade-app`；Debug 热更用 `make push-app`。）

When unsure or on a clean tree: `make build`.

## Code conventions

- **Minimize scope** — smallest correct diff; no drive-by refactors.
- **Match existing style** in touched files (shell, Dart, Buildroot `.mk`, overlay layout).
- **Flutter App API = 3.41.9** — write `app/lws_hmi/` (and Flutter packages) against the pinned SDK only; do **not** follow newer Flutter/Material docs beyond that pin (e.g. use `DropdownButtonFormField(initialValue: …)` on 3.41.x, not the removed 3.24-era `value:`). Detail: `.cursor/rules/flutter-3.41-api.mdc`.
- **Script / device-command naming** — prefer **verb + noun** (kebab-case), no product prefix on script basenames. Operator commands → `/usr/bin/<verb-noun>` via `post-build.sh`. Helpers → **`/usr/libexec/{wpa,network,bluetooth,board,usb,ab,oem,display,power,ssh,hmi}/`**. State → **`/var/lib/{wpa_supplicant,network,bluetooth,hmi}/`**. systemd units use **functional** names (`wlan-wpa.service`, `settings-restore.service`); UI daemon only: `hmi.service`.
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
2. `README.md` → **Make commands** (workflow examples if needed)
3. [`docs/make-commands.md`](docs/make-commands.md) (怎么用 / 何时用 / 参数)
4. Rebuild table in this file (if it affects post-change user commands)

Keep long command examples in **README.md**; keep agent-only rules (rebuild block, pipeline gotchas) here. Use **one command per line** in user-facing examples (no `&&` chains).

## Repository map

| Path | Role |
|------|------|
| `app/lws_hmi/` | Flutter HMI → `overlay/.../opt/hmi`（含产品 `bin/`，如 mediamtx）；HMI Settings = 简化+定制子集 |
| `app/os_settings/` | Cyber OS 系统设置 App → `/opt/os_settings`（平台核心；按需 seat） |
| `docs/settings-apps-roles.md` | OS Settings vs HMI Settings 角色与功能归属（canonical） |
| `packages/cyber_hal/` | Dart HAL path 包 |
| `packages/cyber_pm/` | 子进程监护（MediaMTX、AI daemon） |
| `packages/cyber_capture/` | HMI 截屏/录屏（present-hook + GStreamer/MPP） |
| `native/lws_ai/` | AI C++（`lws_ai_daemon`）；产物经 `make build-ai` → `/opt/hmi` |
| `packages/cyber_ui/` / `cyber_ime/` / `cyber_alarm/` / `cyber_alarm_ui/` / `cyber_upgrade_ui/` | UI / IME / 告警引擎 / 告警 frost UX / 升级 UX |
| `overlay/.../rootfs-overlay/` | Rootfs overlay (systemd, scripts, `/opt/hmi` staging) |
| `overlay/buildroot/` | Defconfig fragments, package pins |
| `overlay/kernel/` | DTS / kernel config |
| `board/` | ynh960 defconfig, LCD params, boot logo |
| `prebuilt/` | Runtime binaries for rootfs |
| `scripts/apply-overlay.sh` | Patches SDK, syncs overlay into Buildroot |
| `Makefile` | All `make` targets |
