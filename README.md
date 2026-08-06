# lws-hmi

Buildroot + **ynh960** (Innohi **RK3566**) on the Rockchip Linux 6.1 SDK.

**Product line:** ynh960 → RK3566 (entry), ynh962 → RK3568B2 (mid, cut-down 3568), ynh961 → RK3568 (high) — three tiers of the **same product line** (minor chip/interface differences, largely similar hardware). **One Linux firmware image** across the line is the design goal (aligned with lws-ui Android). **P1–P5 develop and validate on ynh960**; no per-SKU defconfig fork yet. SDK path `rk3566_rk3568` is Rockchip’s 3566/3568 family tooling profile.

- **Linux (Ubuntu x64):** native build in repo-root `linux-sdk/` (no Docker).
- **macOS:** Docker `linux/amd64` builder + Docker volume for the SDK tree.

## Prerequisites

- Rockchip Linux SDK under repo-root `linux-sdk/` (gitignored). From Innohi xz split volumes:

```bash
make extract-linux-sdk SRC=/path/to/rk356x_linux6.1_…
# or: make extract-linux-sdk /path/to/rk356x_linux6.1_…
# replace existing tree: FORCE=1 make extract-linux-sdk SRC=…
# owned trim + platform squash: TRIM=1 make extract-linux-sdk SRC=…
# or on an existing full tree:
make trim-linux-sdk
make check-linux-sdk
```

See [`docs/linux-sdk-vendor-import.md`](docs/linux-sdk-vendor-import.md). After trim on macOS, refresh the Docker volume (`make docker-volume-init` or `make docker-volume-sync`) so deleted vendor trees are not retained.
- Host Flutter SDK at repo-root `flutter-sdk/` (gitignored; run `make fetch-flutter-sdk`; override install path with `DEST=`; builds locate it via `FLUTTER_SDK` in `.env`)
- **Git LFS is required:** install it before cloning when possible (`brew install git-lfs` on macOS or `sudo apt install git-lfs` on Ubuntu), then run `git lfs install` and `git lfs pull` inside the repository
- **Linux:** Ubuntu 22.04+ on ext4; Rockchip build deps (see `docker/Dockerfile` package list)
- **macOS:** Docker Desktop (Apple Silicon: enable Rosetta for `linux/amd64`)

## Quick start — Linux (Ubuntu x64)

```bash
cd ~/Workspace/lws-hmi
git lfs install
git lfs pull
make setup
make build-deps
make build
make show-config
```

On macOS, add `make flash` after `make build` (see below).

## Quick start — macOS

```bash
cd ~/Workspace/lws-hmi
git lfs install
git lfs pull
make setup
make docker-volume-init
make build-deps
make build
make flash
```

**macOS Docker flow** (volume is ephemeral; host keeps inputs + exported outputs):

1. `make docker-volume-init` — copy host SDK → volume (once)
2. `make apply-overlay` / `make build-*` — repo bind-mounted into container; build in volume
3. `make build-kernel` / `make build-rootfs` / `make build-oem` / `make build-img` — each publishes artifacts to host `output/firmware/` (FITs, `rootfs.img`, `oem.img`, and per-SKU `factory.img` with `update.img` symlink). Daily `make upgrade` needs kernel/rootfs (+ optional oem) — not `build-img` or a manual export.

---

## Make commands

**Per-target reference** (怎么用 / 何时用 / 环境变量与参数): [`docs/make-commands.md`](docs/make-commands.md).

Run `make help` for the short target list. Workflow stages below are **one command per line** — run in order.

### Setup (once per machine)

```bash
git lfs install
git lfs pull
make extract-linux-sdk SRC=/path/to/rk356x_linux6.1_…
make trim-linux-sdk
make check-linux-sdk
make setup
make fetch-flutter-sdk
make apply-overlay
```

Or extract already trimmed: `TRIM=1 make extract-linux-sdk SRC=…`.

macOS only, before the first build (re-run `docker-volume-init` / `docker-volume-sync` **after** trim so deleted vendor dirs are not kept in the volume):

```bash
make docker-image
make docker-volume-init
```

Refresh SDK in the Docker volume after overlay or SDK tree changes:

```bash
make docker-volume-sync
```

### Dependencies (before first `make build-rootfs`)

```bash
make build-deps
make check-prebuilt
```

Individual buckets:

```bash
make extract-linux-sdk SRC=/path/to/rk356x_linux6.1_…
make build-dev-deps
make build-runtime-deps
make fetch-flutter-sdk
make build-flutter-engine
FLUTTER_ENGINE_RUNTIME_MODE=debug make build-flutter-engine
make build-flutter-embedded-linux
make build-gstreamer
make build-platform-packages
make build-mediamtx
make build-opencv
make build-ai
make build-umtprd
make build-extract-video-frame
make fetch-btop
```

`make build-runtime-deps` already builds **both** `arm64-release` and `arm64-debug` engine prebuilts (commit both under `prebuilt/flutter-engine/<ver>/`).
Force refresh a bucket: `make rebuild-deps`, `make rebuild-runtime-deps`, etc.

`make build-flutter-embedded-linux` is required for the **default** Weston image (`make build-rootfs`). The alternate `make build-rootfs` needs `make build-flutter-embedded-linux` instead.

### Full firmware

`make build` runs: `check-prebuilt` → `apply-overlay` → `lunch` → `build-boot-logo` → `build-app` → `build-kernel` → `build-rootfs` → `build-img`.

```bash
make build
make show-config
```

Firmware stage outputs:

- `make build-kernel` builds two independently hashed FIT images containing the same Linux kernel: `boot.img` selects `rootfs_a`, while `boot_b.img` selects `rootfs_b`. Publishes both to `output/firmware/`.
- `make build-rootfs` builds `rootfs.img` (Weston + `flutter-wayland-client` + Mali `wayland-gbm`) and publishes it to `output/firmware/<APP>/` (default `APP=lws_hmi`). Requires `make build-flutter-embedded-linux` first. Runtime: **desktop-shell** (not kiosk) with `/usr/share/hmi/boot-splash.png` bridging kernel splash → Flutter first frame; mouse prefs via `apply-mouse-settings` + `weston-hmi-config.sh`.
- `make prepare-rootfs` flips Buildroot stack prep (overlay defconfig + Mali + embedder packages) without packing `rootfs.img`. `build-rootfs` calls prepare first (skips when stamp + binaries already match).
- `make build-img` does **not** compile the kernel or rootfs. It requires `make build-oem`, then packages loader, U-Boot, misc, both FIT images, APP-scoped rootfs, and **oem** into `output/firmware/<APP>/<FACTORY_SKU>/factory.img` (default APP `lws_hmi`, sku `ynh960-p800`) and refreshes `output/firmware/update.img` as a symlink for `make flash`.
- Full-system `make upgrade` does **not** transfer `factory.img`. Two host transports (auto-selected; override with `UPGRADE_TRANSPORT=ssh|rockusb`):
  - **SSH** (USB-SSH / registered LAN): runs **`make ota-package`** (unless `UPGRADE_PACKAGE=` + sibling `.sig`), starts an ephemeral **host HTTP** server for `ota-package.tar.gz` + `.sig`, triggers the HMI to **download** into `/userdata/ota/`, then Ed25519-verify + staged extract/apply writes inactive boot+rootfs (+ optional oem). SSH is control-plane only. Host console shows HTTP send progress until transfer complete (does not wait for apply). Returns as soon as transfer is complete. Allow inbound TCP on the bind IP if the OS firewall prompts (USB-SSH default `192.168.55.2`).
  - **RockUSB Loader/Maskrom** (e.g. after `make reboot-loader`, or Maskrom): `upgrade_tool` **`di`** downloads the **OTA-equivalent** loose images — `boot.img` → `boot`, `boot_b.img` → `boot_b`, same `rootfs.img` → **both** `rootfs_a` and `rootfs_b`, optional `oem` — with Maskrom `ul` MiniLoader into RAM when needed. **Not** `uf factory.img` (no U-Boot / GPT / misc rewrite) and **not** product cloud OTA.
  Wait for the device to finish restarting before reconnecting.
- OEM-only (board helpers / profile / screen pack): `make build-oem` then `OEM_ONLY=1 make upgrade` — oem partition only (SSH: staged apply + plain reboot; RockUSB: `di` oem only). Set `OEM_ONLY=1` in `.env` for repeated OEM iteration.
- Cloud/publish + SSH upgrade packaging: `OTA_SIGNING_KEY=… REQUIRE_OTA_SIG=1 make ota-package` (archive + `.sig`). Release keys: `make ota-release-keys`.

### Daily iteration — by what you changed

The examples below prefer A/B OTA on a board already flashed with the P2.4 GPT and helpers. To use the factory/USB path instead, replace the final `make upgrade` with:

```bash
# Or: package factory.img, enter Loader, and flash
make build-oem
make build-img
make reboot-loader
make flash
```

**P3.2 emulator** — same kernel `Image` + same `rootfs.img` as the board, plus `sim_virt` OEM (not Rockchip flash). Detail: [`docs/p32-emulator.md`](docs/p32-emulator.md).

Colleague / new machine — run **in order** (one command per line). Skip steps already done on that host.

```bash
# --- A. Repo + SDK (once per machine; same as Quick start) ---
git lfs install
git lfs pull
make extract-linux-sdk SRC=/path/to/rk356x_linux6.1_…
make trim-linux-sdk
make check-linux-sdk
make setup
make fetch-flutter-sdk
# macOS only:
make docker-image
make docker-volume-init

# --- B. Build deps + OS artifacts (first emulator needs real Image + rootfs) ---
make build-deps
make check-prebuilt
make apply-overlay
make build-kernel
make build-rootfs

# --- C. Host emulator tools (once per machine) ---
# macOS: stock `brew install qemu` has no OpenGL — install qemu-virgl:
make setup-emulator-qemu
make fetch-emulator-swgl
# Host SSH helpers for make devices / shell / push-app (password rockchip):
#   brew install sshpass          # macOS
#   sudo apt install sshpass      # Ubuntu

# --- D. Assemble + start ---
make build-emulator
make emulator
```

`make emulator` may prompt for **sudo** (Apple `vmnet` for guest eth0 camera bridge / eth1 debug). Guest **wlan0** uses Android-like SLIRP (`10.0.2.16`) and does not need vmnet. No IP camera on this Mac:

```bash
EMULATOR_ETH0_BRIDGE=off make emulator
```

Daily (artifacts already built):

```bash
make emulator-stop
make emulator
```

After App-only changes (guest already booted, `make devices` shows **MODE=EMU**):

```bash
make build-app
make push-app
# Debug (VM Service) — SN=SIM-EMU is a stable alias; table SN may be SIM-0001:
SN=SIM-EMU make debug-app
# or: IP=127.0.0.1:2222 make debug-app
```

After kernel / rootfs / sim OEM changes:

```bash
make build-kernel
make build-rootfs
make build-emulator
make emulator-stop
make emulator
```

`make build-emulator` copies the 600M device `rootfs.img` and grows the **emulator-only** copy to **1536M** so `debug-app` / `push-app` have headroom (guest has no userdata partition).

Useful once the guest is up:

```bash
make devices
make shell
ssh -p 2222 root@127.0.0.1
# LAN HTTP API (HMI must be running): http://127.0.0.1:5580/  (hostfwd; EMULATOR_HTTP_PORT= to override)
```

Optional hardware on the host before `make emulator`: plug USB-LAN (IP camera) and/or USB-RS485 (auto-passthrough → guest `/dev/ttyUSB0`). See [`docs/p32-emulator.md`](docs/p32-emulator.md).

**Flutter app** (`app/lws_hmi/`) — `/opt/hmi` is installed during rootfs build:

```bash
make build-app
make build-rootfs
make upgrade
```

**App UI i18n** (edit `app/lws_hmi/lib/l10n/app_en.arb` + `app_zh.arb`, then):

```bash
make l10n
make l10n-verify
make check-typography
```

Checks bare `fontSize: N` and any `AppTypography.*Size` under `lib/features` / `lib/ui` (theme tokens only in `lib/app/theme`).

**Boot splash** (`board/logo/`):

```bash
make build-boot-logo
make build-kernel
make upgrade
```

**Kernel / DTS / display DTS** (`overlay/kernel/` is the **git source of truth** while `linux-sdk/` is gitignored; do **not** put boot DTBs in `oem/`):

```bash
# After editing overlay/kernel (required for colleague sync):
FORCE_PLATFORM_OVERLAY=1 make apply-overlay
# or: make squash-linux-sdk-platform
make build-kernel
make build-rootfs
make upgrade
```

**Rootfs overlay** — systemd units, `usr/lib/lws-hmi/*`, LCD params, anything under `overlay/.../rootfs-overlay/` except the app bundle:

```bash
make apply-overlay
make build-rootfs
make upgrade
```

**Default Weston + eLinux rootfs** (product image):

```bash
make build-flutter-embedded-linux
make build-rootfs
make upgrade
```

Weston notes (ynh960):

- `hmi-launch.sh` starts Weston then `flutter-wayland-client --fullscreen`.
- Shell is **desktop-shell** (`panel-position=none`) so `background-image` can show the product logo after DRM takeover (kiosk-shell only supports a solid color).
- `make build-boot-logo` also writes overlay `usr/share/hmi/boot-splash.png` as **logical landscape** (1280×800 upright) for Weston `transform=rotate-270` — not a copy of portrait `logo.bmp`.


```bash
make build-flutter-embedded-linux
make build-rootfs
make upgrade
```

`make build-rootfs` always runs `prepare-rootfs` first (idempotent). Force Mali/embedder rebuild: `FORCE=1 make prepare-rootfs`.
**Buildroot defconfig / Kconfig fragments** (`overlay/buildroot/`):

Overlay-only or new `#include` wiring (no change to how an already-built package is compiled):

```bash
make apply-overlay
make check-prebuilt
make build-rootfs
make upgrade
```

**Changing compile options on an existing package** (classic trap): Rockchip `./build.sh rootfs` / `make build-rootfs` **incrementally reuses** packages already present under `buildroot/output/…`. Updating a chip fragment (example: `BR2_PACKAGE_WPA_SUPPLICANT_DBUS=y` in `chips/lws_hmi_network.config`) + `apply-overlay` refreshes defconfig / `.config`, but **does not rebuild** that package — the staged binary can stay feature-incomplete (e.g. `wpa_supplicant` without `-u`). Force a package rebuild, then rootfs:

```bash
make apply-overlay
bash scripts/br-make-packages.sh wpa wpa_supplicant
make check-prebuilt
make build-rootfs
make upgrade
```

`br-make-packages.sh` re-applies `rockchip_rk3566_rk3568_lws_hmi_defconfig` then runs `make <pkg>` in the lws_hmi Buildroot output. This is **userspace only** — not `make build-kernel`. After a major defconfig or toolchain change you may still need `make clean-buildroot-output` before `make lunch` / `make build-rootfs` (see [`docs/build-optimization.md`](docs/build-optimization.md)).

**Runtime prebuilt only** (`prebuilt/`, flutter-engine, gstreamer, etc.):

```bash
make build-runtime-deps
make apply-overlay
make build-rootfs
make upgrade
```

### Release / factory image

A release or factory-flash artifact always requires `make build-oem` and `make build-img`, even if daily iteration used `make upgrade`. If the kernel and rootfs are already up to date:

```bash
make build-oem
make build-img
```

This produces `output/firmware/<FACTORY_SKU>/factory.img` (default `ynh960-p800`) and a migration `update.img` symlink. To test the release image on hardware, then run `make reboot-loader` and `make flash`.

Canonical host artifacts live under `output/firmware/` only. SDK `linux-sdk/output/firmware/` is a transient pack staging area (Linux moves files out on export; macOS Docker keeps them only inside the volume).

### Flash and device (macOS)

```bash
make audit
make devices
make shell
make flash
```

Loader path from Android:

```bash
make devices
SN=... make reboot-loader
make flash
```

Loader path from Linux board (USB plug-ssh, no adb):

```bash
make devices                    # auto-discovers USB-SSH, configures host 192.168.55.2
make reboot-loader                # USB-SSH → device reboot-loader (SN= optional)
make flash                      # host RockUSB (macOS / Linux / Windows Git Bash)
```

### App iteration (USB plug-ssh or remote SSH, no rootfs reflash)

After one firmware flash with USB plug-ssh support:

```bash
make shell                      # interactive root shell; SN=... when multiple boards
make logs                       # live journal; optional UNIT= TAG= GREP= PRIORITY= KERNEL_ONLY=1
make prepare-app-assets         # optional host-only: prune process-library + firmware → assets/.generated/
make build-app                  # *_hmi AOT → overlay /opt/hmi; APP=factory_test → /opt/factory_test
make push-app                   # SN=... when multiple boards; hot-swap selected APP
APP=…                           # app/ dir; *_hmi→/opt/hmi; rootfs→output/firmware/<APP>/; factory→…/<APP>/<sku>/
make version                    # print app/<APP> pubspec versionName+build (default APP=lws_hmi; host-only)
make version-bump VERSION=1.0.40  # bump pubspec (+ app_version.dart when present); 5-digit build encode
make build-rootfs               # → output/firmware/<APP>/rootfs.img (default APP=lws_hmi)
make ota-package                # pack imgs → output/firmware/<APP>/ota-package.tar.gz [+.sig]
make ota-release-keys           # release Ed25519 keys → keys/ota/ + overlay /etc/ota/ed25519.pub
make upgrade                    # ota-package + host HTTP; device downloads tar.gz+.sig → verify/apply; or RockUSB di
make build-img                  # → output/firmware/<APP>/<FACTORY_SKU>/factory.img
make flash                      # uf that factory (APP= + FACTORY_SKU=); IMAGE= override
make upgrade-control-board      # push latest control-board bin; force upgrade (HMI running)
make upgrade-process-library    # push process-library for device model; force import (HMI running)
make reset-process-library      # clear process-library DB via HMI watcher; re-import bundled (no restart)
make set-prop CAMERA_IP=192.168.1.50   # upsert tunables in /var/lib/hal/properties.ini (multi-key OK); restarts hmi
# brand / model / sn → Vendor Storage: make write-identity (not set-prop / del-prop / OEM seed)
make write-identity BRAND=LaserCyber MODEL='L1 Pro' PRODUCT_SN=LC-001   # hyphens stripped → LC001; SN=… FORCE=1 to overwrite
make set-prop CONTROL_CARD_COMM_ALARM_MODE=slide_window   # C001 window: slide_window (default) | immediate
make alarm CODE=L001            # demo warn dialog (USB-SSH/SSH; catalog code; HMI running)
make alarm-clean                # clear alarm restrictions; keep visible warn popup
make smoke-ai                   # upload stain demo JPG; offline RKNN via AI daemon sock (HMI running)
make del-prop CAMERA_IP         # remove one tunable key; restarts hmi if changed
make upgrade                    # auto: SSH host-HTTP + device pull if Linux up; else RockUSB di OTA images (Loader/Maskrom)
UPGRADE_TRANSPORT=rockusb make upgrade  # force RockUSB path after make reboot-loader / Maskrom
```

Device selection: use **`SN=`** (matches `make devices` **SN**). Put `SN=` / `IP=` / **`OEM_ONLY=`** / **`OEM_IMG=`** / **`UPGRADE_TRANSPORT=`** in `.env` for IDE / daily use.

Alarm history persists in SQLite **`/var/lib/hmi/alarm-logs.db`** (→ `/userdata/hmi/alarm-logs.db`, table `alarm_logs`) — kept across `push-app` / `make upgrade`.

Full-system A/B (kernel/rootfs, not app-only): `make upgrade` — SSH streams inactive FIT+rootfs, or RockUSB `di` of both FITs + both rootfs letters (OTA-equivalent; not userdata staging).

Remote SSH (board LAN/WLAN sshd on — Demo **LAN SSH debug** or `enable-ssh-debug.sh`):

```bash
# On device (serial / USB-SSH / Demo toggle):
#   /usr/libexec/ssh/enable-ssh-debug.sh
make connect 192.168.1.50       # or: make connect IP=192.168.1.50
make devices                    # MODE=SSH row
IP=192.168.1.50 make shell
IP=192.168.1.50 make push-app
IP=192.168.1.50 make upgrade    # SSH stream-to-partition; not RockUSB / not online OTA staging
make disconnect 192.168.1.50
```

`IP=` selects **registered SSH** or **EMU** (never USB-SSH). `SN=` selects by **SN** (`make devices` columns: MODE / SN / LocationID / …); **`SN=SIM-EMU`** / **`SN=EMU`** always select the QEMU guest even when the table SN is chip-ID fallback. USB-SSH/SSH/EMU **SN** prefers Vendor Storage SN, else chip serial. Android adb / RockUSB loader rows use the adb/SerialNo as SN. `make reboot` works over SSH/EMU; `make reboot-loader` remains USB-SSH / RockUSB / adb only. Android emulators (`emulator-*`) are omitted from `make devices` and rejected by `make upgrade` / `make reboot-loader` / `make flash` / `make flash-android`. **QEMU** (`make emulator`) appears as ephemeral **MODE=EMU** (`IP=127.0.0.1:2222`) when SSH hostfwd answers — usable with `make shell` / `make push-app` / `make debug-app`, not `make upgrade` / `make write-identity`. Product identity (`brand` / `model` / `sn`) lives in Rockchip **Vendor Storage** — provision with **`make write-identity BRAND=… MODEL=… PRODUCT_SN=…`** after flash (geometry frozen; `factory.img` must not package vendor payloads). Optional macOS RockUSB `upgrade_tool SN` / `RSN` is **SN-only**; brand/model still need `write-identity`. `make set-prop` / `del-prop` refuse identity keys.
Commands that intentionally restart the Linux board automatically remove its matching persistent `MODE=SSH` registration: full-system `make upgrade`, `make reboot`, and USB-SSH `make reboot-loader` (matched to a registered row by board serial). Ephemeral `MODE=USB-SSH` rows are not stored and disappear automatically when the USB network gadget goes down. Run `make connect <ip>` again after enabling LAN SSH in the new boot session.

`make shell` opens an interactive `root` terminal over USB ECM SSH or a registered remote SSH IP, similar to `adb shell`. VBUS loads the modular `g_ether` driver with stable per-device USB serial/MAC identity; unplug unloads it. The implementation does not create a configfs gadget or reset DWC3. The previous SDK/container shell command is now `make sdk-shell`. `make push-app` stages `libapp.so` + `flutter_assets` on the board, installs the complete payload while the current HMI keeps running, then restarts `hmi.service` with bounded recovery attempts. The flashed kernel must include the DRM GEM teardown fix. Host needs `sshpass` (password `rockchip`). `make devices` lists RockUSB, USB-SSH, and registered SSH rows in one table. **`make upgrade`** (P2.5) auto-selects **SSH stream** (inactive FIT + rootfs) when a Linux SSH target is up, or **RockUSB `di`** of OTA-equivalent images (`boot`/`boot_b`/both rootfs letters/optional oem) when the board is in Loader/Maskrom — **not** `upgrade_tool uf` / `factory.img` (use **`make flash`** for GPT / U-Boot / MiniLoader storage / misc) and **not** online OTA’s download-to-`/userdata/ota/` then staged apply. Force with `UPGRADE_TRANSPORT=ssh|rockusb`. Once apply completes or the connection drops for reboot, the command exits with a clear prompt to wait for the device to finish restarting before reconnecting. Hardware prefs live on **userdata** (`/userdata/lws-hmi`): kept across reboot / push-app / **`make upgrade`**; **`make flash` must factory-reset them** — see [`docs/storage-layout.md`](docs/storage-layout.md) §Prefs and [`docs/ab-slot-misc.md`](docs/ab-slot-misc.md).

### Debug iteration (USB plug-ssh / remote SSH, P1.5)

First time on a host (pinned Flutter 3.41.9 + `sshpass`):

```bash
make debug-setup
```

After the board has a rootfs with the P1.5 debug overlay scripts (`hmi-launch.sh`, `debug-app-*`):

```bash
make debug-app                   # SN=... or IP=... when multiple boards
# QEMU guest (make emulator): SN=SIM-EMU make debug-app
#                          or: IP=127.0.0.1:2222 make debug-app
```

Or open `app/lws_hmi` in VS Code / Cursor and start **lws-hmi (USB-SSH / SSH debug)** from Run and Debug. Pre-launch runs `make prepare-debug-host`: for registered `IP=` / `MODE=SSH` / **`MODE=EMU`** it only checks reachability (no USB ECM); for USB-SSH it configures the host ECM interface (macOS may request `sudo`). Put `IP=` in `.env` so the IDE picks the SSH board. The non-interactive Flutter custom-device hooks never prompt for `sudo`.

`make debug-app` builds a debug bundle (`kernel_blob.bin`), uploads the matching **debug-runtime** engine on first use (cached under `/var/lib/hmi/debug-runtime/`), replaces `/opt/hmi`, and starts the HMI with VM Service over SSH port forwarding (USB-SSH, registered IP, or **EMU** hostfwd). Stopping the IDE closes the tunnel but **leaves the debug app running** on the device. Replace it with a release build using `make build-app` + `make push-app`.

Host-only checks:

```bash
make test-debug-app
```

```bash
make show-config
make docker-volume-status
make check-prebuilt
```

On device after flash:

```bash
verify-boot          # Plan A boot chain / KPI
verify-env           # Platform stack
diagnose-hmi         # HMI service, journal, bundle, and engine
diagnose-usb-ssh     # DWC3, VBUS, g_ether, usb0, and sshd
read-serial          # Stable board serial
start-usb-ssh        # Manually start g_ether + usb0 sshd
stop-usb-ssh         # Stop usb0 sshd and unload g_ether
recover-usb-ssh      # Restart USB-SSH; may disconnect this shell
reboot-loader        # Enter RockUSB Loader mode
```

### Maintenance (infrequent)

```bash
make pull-display-params
make clean-overlay
make apply-overlay
make clean-buildroot-output
make migrate-buildroot-output
```

Agent-oriented rebuild mapping: [`AGENTS.md`](AGENTS.md).

`make build-kernel` / `make build-rootfs` / `make build-img` each publish matching files under `output/firmware/` (macOS: from the Docker volume; Linux: moved out of `linux-sdk/output/firmware/`). No second host copy under `linux-sdk/output/`. Manual `make docker-export-artifacts` is legacy; `make docker-volume-pull` is an alias for `SCOPE=firmware`.

---

## Dependencies (prebuilt-first)

**Two buckets:**

| Bucket | Command | What |
|--------|---------|------|
| **Runtime** (`build-runtime-deps`) | Board stack | Flutter、**GStreamer/MPP**、OpenCV、RKNN runtime（MediaMTX 走 `build-mediamtx` + **`build-app`** → `/opt/hmi/bin`） |
| **Dev host** (`build-dev-deps`) | x86 上编应用、转模型 | `FLUTTER_SDK`（交叉编 Dart）、RKNN-Toolkit（ONNX→`.rknn`） |

`make build-deps` = `build-dev-deps` + `build-runtime-deps`（engine 编译需要 host Flutter SDK）。

### Runtime — `make build-runtime-deps`

`make check-prebuilt` 在 `build-rootfs` 前校验下列项（缺一则失败）：

| 组件 | 产出位置 | 板上角色 |
|------|----------|----------|
| flutter-engine / eLinux | `prebuilt/flutter-*` | HMI 显示栈 |
| mediamtx | `prebuilt/mediamtx/` → **`/opt/hmi/bin/mediamtx`** (`make build-app`) | RTSP 中继（产品 App 子进程；**相机就绪后**由 HMI 拉起） |
| umtprd | `prebuilt/umtprd/` + fs-overlay `usr/bin/` | USB MTP gadget（`mode=mtp`；`make build-umtprd`） |
| extract-video-frame | `prebuilt/extract_video_frame/` + fs-overlay `usr/libexec/hmi/` | MP4→JPEG cover/AI sample（GStreamer；`make build-extract-video-frame`） |
| btop | `prebuilt/btop/` + fs-overlay `usr/bin/` | SSH 按需系统监视（官方 aarch64 musl 静态包；`make fetch-btop`） |
| **GStreamer + MPP** | Buildroot + `prebuilt/gstreamer/` | RTSP 预览/取帧 |
| OpenCV + ximgproc | `.cache/opencv/` sources → `make build-opencv` → `prebuilt/opencv/linux-arm64/` | 链进 `lws_ai_daemon` |
| AI daemon | `native/lws_ai` → `make build-ai` → `prebuilt/ai/` → **`build-app` → `/opt/hmi`** | App 经 `cyber_pm` 监护 |
| RKNN runtime | `prebuilt/rknn-rt/` + SDK rknpu2 | NPU 推理（rootfs + AI 链接） |
| **P2/P3/P5 平台库** | `prebuilt/platform-packages/` | libmodbus、yaml-cpp、sqlite、avahi |

另：P1 通过 `make fetch-rknn-rt` 将 SDK `external/rknpu2` 的 `librknnrt.so` + `rknn_server` 同步进 fs-overlay（本 SDK 无 `BR2_PACKAGE_RKNPU2` 包）。`prebuilt/rknn-rt` 供 `make build-ai` 交叉链接；daemon 本身不进 rootfs。

| Target | 作用 |
|--------|------|
| `make build-runtime-deps` | 上表全部（含 GStreamer、btop、opencv、ai） |
| `make build-platform-packages` | libmodbus + yaml-cpp + sqlite + avahi |
| `make fetch-opencv` / `fetch-opencv-ximgproc` | OpenCV 源码 |
| `make build-opencv` | aarch64 OpenCV → `prebuilt/opencv/linux-arm64` |
| `make build-ai` | `lws_ai_daemon` → `prebuilt/ai/linux-arm64`（需 opencv + rknn-rt） |
| `make fetch-rknn-rt` | aarch64 `librknnrt.so` |
| `make fetch-btop` | aarch64 musl `btop` → prebuilt + fs-overlay |
| `make build-umtprd` | aarch64 static `umtprd` → prebuilt + fs-overlay（MTP） |
| `make build-extract-video-frame` | aarch64 `extract-video-frame` → prebuilt + `/usr/libexec/hmi/`（GStreamer JPEG） |
| `make build-flutter-engine` / `build-eLinux` / `build-mediamtx` | 单项 |
| `make check-prebuilt` | 校验 runtime（`build-rootfs` 自动） |
| `make build-rootfs` | 装已接入 defconfig 的 prebuilt（Flutter 等） |

### Dev host — `make build-dev-deps`

**不上板**，`check-prebuilt` 不检查：

| Target | 产出 | 用途 |
|--------|------|------|
| `make fetch-flutter-sdk` | `flutter-sdk/` | `make build-app`、engine 编译辅助 |
| `make fetch-rknn-toolkit` | `.cache/rknn-toolkit/` | 开发机上 ONNX→RKNN 模型转换 |

Force refresh: `make rebuild-deps` / `rebuild-dev-deps` / `rebuild-runtime-deps`。

### 分阶段对照（P1 备好依赖 vs 分阶段开功能）

| 阶段 | 运行时依赖 | P1 `build-runtime-deps` | 仍在本阶段做的（不是装包） |
|------|------------|-----------------|----------------------------|
| P1 | flutter、RKNPU2、Wi‑Fi/BT、GPU | ✓ | Hello World、hmi 自启 ✅ |
| P2 | libmodbus、ALSA、wpa、BlueZ… | ✓ | 硬件设施准备（含原 P2.1～P2.3）✅ |
| P2.5 | A/B **boot+rootfs** | `parameter` 改表 | `make upgrade` ✅（开发流式）；供 **P4.8 整机 A/B + Ed25519** 复用 |
| P3.0 | — | — | **cyber_ui** / **cyber_ime** path 包 🔄（优化中） |
| P3.1 | systemd-networkd、wpa D-Bus | 开 networkd | **Dart HAL** + **网络栈切换**（L3=networkd）✅ |
| P3.2 | 同 Image + 同 rootfs + OEM 切换 | QEMU | 模拟器验证多板多屏 ✅ W4 主路径；[`docs/p32-emulator.md`](docs/p32-emulator.md)；`make build-emulator` / **`make emulator`** |
| P3.3 | OpenCV、yaml-cpp、RKNN、`native/lws_ai` | ✓（`build-opencv` / `build-ai`） | **`lws_ai_daemon` via `cyber_pm`**（OpenSpec `app-owned-ai-daemon`）🔄 |
| P4 | GStreamer、sqlite、Avahi；**MediaMTX → App `/opt/hmi/bin`** | GStreamer ✓ | 业务 UI、:5580、云 🔄；MediaMTX 已 App 化（`cyber_pm`）；**P4.8 整机 A/B + Ed25519**（一级；HMI 随 rootfs）另计 |
| P5.0 | — | — | Android 兼容 / APK（App + YNHAPI；非 `cyber_hal`） |
| P5.1 | flutter SDK + engine + eLinux **三件套升级** | 重编 prebuilt | **3.41.9** + eLinux **42d3d75a56**；见 [`docs/flutter-linux-hmi-plan.md` §6.5](docs/flutter-linux-hmi-plan.md#65-flutter-engine-版本策略与升级p51) |

权威阶段表与旧号映射：[`docs/flutter-linux-hmi-plan.md` §1](docs/flutter-linux-hmi-plan.md)。HAL 设计：[`openspec/changes/archive/2026-07-18-dart-hal-package/`](openspec/changes/archive/2026-07-18-dart-hal-package/)。

Overlay 脚本（P1 启动链）：`boot-verify.sh`、`env-verify.sh`（§3.4 平台栈）、`ynh960-display-init.sh`、`set-performance-mode.sh`。eth0 配网、SSH 调试、**mediamtx 启停**（**IPC ping 通后** App 经 `cyber_pm` 拉起 `/opt/hmi/bin/mediamtx`）由 Flutter 产品 session 触发。日志：`make logs GREP=mediamtx`。

仍待移植：lensinspector / AI daemon、`probe-dual-stream.sh`、IPC 专链 eth0 配网细节（**P4.1**）。

### Git LFS (required)

Large runtime binaries under `prebuilt/` are stored with Git LFS and are required to build a bootable HMI rootfs. Install Git LFS before cloning when possible:

```bash
brew install git-lfs
# Ubuntu: sudo apt install git-lfs
git lfs install
git lfs pull
```

For an existing clone, install Git LFS and run the same `git lfs install` / `git lfs pull` commands in the repository. Verify the checkout with:

```bash
git lfs ls-files
```

Each listed file must have `*` before its path. Files such as `libflutter_engine.so` that are only about 130 bytes are LFS pointer text, not usable binaries. A build made from pointer files can produce an abnormally small `rootfs.img` / `update.img` and a system with no HMI, even if `make check-prebuilt` reports success. After repairing an already-built checkout, discard the contaminated Buildroot output and rebuild only rootfs and the factory image:

```bash
make clean-buildroot-output
make apply-overlay
make lunch
make build-rootfs
make build-img
```

`make build-img` reuses existing `boot.img` and `boot_b.img`; if either is missing, run `make build-kernel` before `make build-img`.

The **host Flutter SDK** (~1 GB) is separate from Git LFS and lives in gitignored `flutter-sdk/` at the repo root; run `make fetch-flutter-sdk` to populate it (override install path with `DEST=…`, same as `extract-linux-sdk`). Builds/debug locate the SDK via `FLUTTER_SDK` (default `flutter-sdk/`).

### Buildroot `dl/` (generic packages)

Buildroot still downloads standard packages (gcc, systemd, wpa_supplicant, …) into `linux-sdk/buildroot/dl/` on first build. That is the normal Buildroot cache — not version-pinned product deps. Share or preserve `buildroot/dl/` to avoid re-downloading on clean output trees.

---

After `make build` and flash: boot logo ≤2 s → Hello World auto-start → home frame ≤10 s. Confirm profile:

```bash
make show-config           # or: bash scripts/docker-run.sh bash -lc 'grep RK_BUILDROOT output/.config'
```

On device (serial shell or ssh), after `make build-img` and `make flash`:

```bash
verify-boot                        # Plan A 启动链 / KPI
verify-env                         # §3.4 平台栈（不含 eLinux）
```

Boot KPI 优化阶段与状态表：[`docs/boot-kpi-optimization.md`](docs/boot-kpi-optimization.md).

On **macOS**, builds use a Docker volume for the SDK (not a bind mount from APFS). Bind-mounting during Buildroot often **crashes Docker Desktop** (`BUILD_BIND_MOUNT=1` to force, not recommended).

On **Linux**, `make lunch` / `make build-rootfs` run `./build.sh` directly under `linux-sdk/`; firmware is then moved to repo-root `output/firmware/`.

### `innohi/` / WiFi-BT firmware errors

Rockchip Innohi board binaries and Wi‑Fi/BT firmware live under **`linux-sdk/innohi/`** (vendor drop; not in git). `make apply-overlay` runs `normalize-innohi-sdk` to drop any legacy `innohi_board/` mirror and retarget scripts to `innohi/rootfs`. **lws_hmi** skips Innohi **MainServer** autostart (Plan A uses systemd + `hmi.service`). If `build-rootfs` fails on missing `rk_wifi_init` / firmware, re-extract the SDK (ensure `linux-sdk/innohi/rootfs` exists) and run `make apply-overlay` again (macOS: auto before each Docker build).

**ynh960 Wi‑Fi/BT chip:** board SDIO is **AIC8800D80** (`c8a1:0082`). `RK_WIFIBT_CHIP="AIC8800D80"` keeps `post-wifibt` running for kernel `*.ko` → `/vendor/lib/modules` without Broadcom `AP6256`/`bcmdhd`/`fw_bcm*` dumps. Combo firmware ships in the OEM radio pack (`oem/boards/ynh960/radio/`); runtime uses `wifibt-bringup.sh` / `rk_wifi_init` (`aic8800_bsp`/`fdrv`/`btlpm`). Kernel fragment: `ynh960-wifibt.config`.

### Serial console & board login

**Serial console (host USB adapter):**

| `MODE` | Backend | Default baud | Quit | Typical use |
|--------|---------|--------------|------|-------------|
| `TTL` (default) | pyserial miniterm | `1500000` | `Ctrl+]` | USB-TTL → board UART2 / `ttyFIQ0` |
| `RS485` | pyserial curses hex console | `115200` | `Esc` or `:q` | USB-RS485; RX hex + bottom TX bar |
| `RS232` | pyserial curses hex console | `115200` | `Esc` or `:q` | USB-RS232; RX hex + bottom TX bar |

```bash
make serial-console
MODE=TTL make serial-console
MODE=RS485 make serial-console
MODE=RS232 BAUD=9600 make serial-console
MODE=RS485 LOG_FILE=/tmp/uart.log make serial-console
make serial-ports
```

`PORT=` auto-picks `/dev/cu.usb*` when unset; `BAUD=` overrides baud in all modes. RS485/RS232 open a **split UI**: scrolling RX hex (one line per idle gap, default `TIMESTAMP_TIMEOUT=5` ms) and a fixed bottom **`TX>`** bar — type hex (`01 03 …` or `0103`) and press Enter to send. Optional `LOG_FILE=` (+ `LOG_APPEND=1`). No host `tio` required. Electrical RS-485 vs RS-232 is the adapter. TTL wiring: GND + TX↔RX cross (3.3V only). Self-test: short TTL TX–RX, type keys — should echo.

**Login (Buildroot):**

| User | Password |
|------|----------|
| `root` | `rockchip` |

From `buildroot/configs/rockchip/base/common.config` (`BR2_TARGET_GENERIC_ROOT_PASSWD`). Not empty.

**Do not** `make build-uboot` on ynh960 unless Innohi instructs — wrong uboot bricks MaskROM recovery.

### USB flash (macOS / Linux / Windows)

Tool: vendored at `tools/upgrade_tool/{macos,linux,windows}/` (see [`tools/upgrade_tool/README.md`](tools/upgrade_tool/README.md)). `make flash` picks the host binary automatically.

- **Linux (x86_64):** udev access to USB vendor `2207` (or run as root).
- **Windows:** Rockchip DriverAssistant + run Make from **Git Bash** or **MSYS2** (not PowerShell/`cmd`).

### USB-SSH (macOS / Linux / Windows)

Host side of board `g_ether` plug-ssh (`192.168.55.1` ↔ host `192.168.55.2`):

```bash
make setup-usb-ssh          # find RNDIS/ECM gadget NIC + set host IP (Windows may need Admin)
make devices                # expect MODE=USB-SSH
make shell                  # or push-app / reboot-loader
```

- **Windows:** install Rockchip USB / Remote NDIS drivers so a new Ethernet adapter appears; use Git Bash/MSYS2; install `sshpass` (`pacman -S sshpass` on MSYS2) for password SSH used by Make helpers. Discovery/IP uses [`scripts/usb-ssh-windows.ps1`](scripts/usb-ssh-windows.ps1).
- **Linux / macOS:** same Make targets; Linux host USB-SSH is implemented but should be verified on your PC (`lsusb` → `2207:0019`, new netdev, then `make setup-usb-ssh`).

MaskROM recovery (device not visible after loader upload — loader reboot drops USB briefly):

```bash
make devices               # re-enter MaskROM if empty: power off, hold Recovery, USB via hub
make flash                 # auto: ul if Maskrom, uf if Loader
```

Normal flash from Android:

```bash
make devices
SN=... make reboot-loader   # adb reboot loader (Android)
make flash                     # uf only when already in Loader mode (IMAGE=... to override)
```

Normal flash from Linux HMI (USB plug-ssh):

```bash
make devices
make reboot-loader               # USB-SSH → device reboot-loader
make flash                     # host RockUSB uf (any supported OS)
```

App deploy without reflash:

```bash
make build-app
make push-app                  # SN=... or IP=... when multiple devices
make upgrade-control-board    # push latest control-board bin and trigger upgrade (no version gate)
make upgrade-process-library  # push process-library for device Vendor Storage model; force import
make reset-process-library    # clear process-library DB via HMI watcher; re-import bundled (no restart)
make set-prop CAMERA_IP=192.168.1.50   # optional: product tunables over SSH (not brand/model/sn)
make write-identity BRAND=LaserCyber MODEL='L1 Pro' PRODUCT_SN=LC-001  # Vendor Storage; "-" stripped
```

### macOS Docker Desktop tips

- Run `make docker-volume-init` once before the first build.
- Init uses **tar** (not rsync) for the bulk copy; macOS APFS xattrs / vendor symlinks often make rsync exit 23 even at 99%.
- If a previous init copied ~99% then failed, re-run `make docker-volume-init` — it detects the existing tree and skips re-copy.
- Default `BUILD_JOBS=8`; lower to `4` if Docker OOM / Desktop becomes unstable.
- Enable **Settings → General → Use Rosetta for x86_64/amd64 emulation** (Apple Silicon).
- If builds still crash, use a native Linux VM instead of Docker Desktop.
- Force the old bind-mount path (not recommended): `BUILD_BIND_MOUNT=1 make build-rootfs`

## Display parameters (ynh960 @ 10.0.0.239)

Production Android stores **two** files (not the Ubuntu-style `LCD_PARAM_RK356X_V11_0.txt` name alone):

| File on device | Role |
|----------------|------|
| `/system/etc/960_lcd_param_rk356x.txt` | Timing, rotation, backlight, `mipi_lcd_index=-1` |
| `/system/etc/lcd_mipi_param.txt` | MIPI panel init command table (`###lcd_mipi_param_start###`) |

`ParamUpdate` reads `/system/etc/` and mirrors to `/mnt/private1/` (`/dev/block/by-name/private1`).

When `mipi_lcd_index = -1`, the kernel **does not** use built-in tables from `mipi_lcd_sequence.h`; it uses **`lcd_mipi_param.txt`** instead.

### Refresh from a live device

```bash
make pull-display-params    # adb pull → board/ → re-apply SDK overlay
```

### What lws-hmi installs into Buildroot

Upstream SDK **only** copies LCD params for Ubuntu/Debian rootfs, **not** for Buildroot. We add:

1. **Buildroot fs-overlay** — `buildroot/board/rockchip/rk3566_rk3568/rootfs-overlay/system/etc/`:
   - `960_lcd_param_rk356x.txt`
   - `lcd_mipi_param.txt`
   - `LCD_PARAM_RK356X_V11_0.txt` (same content as 960 file; legacy name for ParamUpdate)

2. **post-rootfs hook** — `device/rockchip/common/post-hooks/05-display.sh` (re-copy from `lws-hmi/board/` during `./build.sh rootfs`).

3. **BR2_ROOTFS_OVERLAY** line appended to `buildroot/configs/rockchip/chips/rk3566_rk3568.config`.

`MainServer` / `ParamUpdate` (from Innohi) expect paths under **`/system/etc/`**; the overlay creates that tree on Buildroot. **P1** also installs `MountAll` + `param-update.service` to apply MIPI params before `hmi.service` (ynh960 DTS leaves `lcd0_x/y=0` until ParamUpdate runs).

## What this repo adds

| Path | Purpose |
|------|---------|
| `board/ynh960_defconfig` | Innohi ynh960 board selection (DTS + FIT + LCD param) |
| `board/960_lcd_param_rk356x.txt` | From production ynh960 Android |
| `board/lcd_mipi_param.txt` | MIPI init table from production Android |
| `board/from-device/` | adb pull backups |
| `overlay/buildroot/chips/lws_hmi_*.config` | **方案 A** + eLinux Kconfig 片段 |
| `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig` | 瘦身 Buildroot defconfig（无 Weston/Chromium） |
| `board/logo/splash_icon.png` | Boot splash 源图 → `make build-boot-logo` |
| `app/lws_hmi/` | P1 Hello World Flutter 工程 |
| `AGENTS.md` | AI agent 工作流 + 改动后的重新构建指引 |
| `scripts/build-{boot-logo,flutter-app}.sh` | Logo / App 构建脚本 |
| `overlay/.../rootfs-overlay/etc/systemd/` | `hmi.service`、journald volatile 等 |
| `overlay/.../06-systemd.sh` | 镜像构建时 enable hmi / disable sshd 等 |
| `overlay/.../05-display.sh` | Buildroot post-rootfs install hook |
| `overlay/.../check-sdk.sh` | Skip ext4/WSL guards when `LWS_HMI_DOCKER=1` |
| `docker/Dockerfile` | Ubuntu 22.04 + Rockchip build dependencies |

The upstream SDK ships **ynh962** board defconfig but **ynh960.dts** in kernel; this overlay adds the missing **`ynh960_defconfig`** for our RK3566 target. (SDK `ynh962` naming ≠ product ynh962 / RK3568B2 SKU — see [`docs/flutter-linux-hmi-plan.md`](docs/flutter-linux-hmi-plan.md) §3.0.)

## Environment

```bash
export FLUTTER_SDK=flutter-sdk                                        # locate host Flutter for build-app/debug (install: make fetch-flutter-sdk; DEST= overrides install dir)
export BUILD_JOBS=8                                          # parallel make jobs (default 8; lower if OOM)
export SN=10.0.0.239:5555                            # for pull-display-params (adb over network)
export REBUILD_IMAGE=1                                       # rebuild Docker image
make build                 # full firmware → output/firmware/update.img
```

## Notes

- First Buildroot build downloads packages; allow network and ~20GB+ free disk under SDK `output/` and `buildroot/dl/`.
- Rockchip’s pre-build check used to probe `sources.buildroot.net` with HTTP HEAD on the site root, which always returns **403** (not a VPN/GFW issue). `make setup` patches `check-buildroot.sh` to probe `buildroot.net/downloads/buildroot-<version>.tar.gz` instead. Package downloads during the build may still use `sources.buildroot.net` via `BR2_PRIMARY_SITE`; that is separate from this pre-flight check.
- Weston + eLinux is enabled via `lws_hmi_wayland.config` + `lws_hmi_flutter_weston.config`. See [`app/README.md`](app/README.md).
- **Linux Flutter HMI 规划**（组件裁剪、Hello World、RTSP 分阶段）：[`docs/flutter-linux-hmi-plan.md`](docs/flutter-linux-hmi-plan.md)
- **ynh960 串口 / GPIO / pinmux 台账**（P2.1）：[`docs/ynh960-io-pinmux-ledger.md`](docs/ynh960-io-pinmux-ledger.md)
- `make clean-overlay` restores patched SDK files (`check-sdk.sh`, `rk3566_rk3568.config`, post-hook, fs-overlay).
