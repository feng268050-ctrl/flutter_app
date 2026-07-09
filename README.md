# lws-hmi

Buildroot + **ynh960** (Innohi RK3568) on the Rockchip Linux 6.1 SDK.

- **Linux (Ubuntu x64):** native build in `sdk/` (no Docker).
- **macOS:** Docker `linux/amd64` builder + Docker volume for the SDK tree.

## Prerequisites

- Extracted SDK at `~/Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126` (override with `LINUX_SDK` in `.env`)
- **Linux:** Ubuntu 22.04+ on ext4; Rockchip build deps (see `docker/Dockerfile` package list)
- **macOS:** Docker Desktop (Apple Silicon: enable Rosetta for `linux/amd64`)

## Quick start — Linux (Ubuntu x64)

```bash
cd ~/Workspace/lws-hmi
make setup                 # link SDK + apply ynh960 overlay
make build-deps              # Flutter stack → prebuilt/ (sources in .cache/)
make lunch                 # rk3566_rk3568:ynh960 → lws_hmi Buildroot profile
make build-boot-logo       # splash_icon.png → logo.bmp
make build-flutter-app     # Hello World → fs-overlay /opt/hmi
make build-rootfs          # Buildroot rootfs only (first run: long, needs network)
# firmware: sdk/output/firmware/update.img
```

## Quick start — macOS

```bash
cd ~/Workspace/lws-hmi
make setup                 # link SDK + overlay + Docker image
make docker-volume-init    # copy SDK into Docker volume (once; ~10–30 min)
make build-deps              # Flutter stack → prebuilt/
make lunch
make build-boot-logo
make build-flutter-app
make build-rootfs
make devices               # USB flash (macOS only)
make bootloader            # adb reboot loader → RockUSB Loader
make loader
make upgrade               # auto-pulls output/ from volume before flash
make upgrade IMAGE=/path/to/custom.img
```

## Dependencies (build vs prebuilt)

**Philosophy:** Heavy or version-pinned artifacts live in git-tracked **`prebuilt/`**. Sources stay in gitignored **`.cache/`**. `make build-*` downloads sources and builds into `prebuilt/` when needed; **`make build-rootfs`** installs from `prebuilt/` when present (no Flutter recompile for normal clones).

### P1 — Flutter stack

| Target | Output | Buildroot |
|--------|--------|-----------|
| `make build-flutter-sdk` | `prebuilt/flutter-sdk/install/` | `host-flutter-sdk-bin` (copy only) |
| `make build-flutter-engine` | `.cache/flutter-engine/*.tar.gz` (compile fallback) | skipped when `prebuilt/flutter-engine/` exists |
| `make build-flutter-pi` | `.cache/flutter-pi/src/` (compile fallback) | skipped when `prebuilt/flutter-pi/` exists |
| `make build-deps` | all of the above | — |
| `make build-prebuilt` | `prebuilt/flutter-engine/` + `prebuilt/flutter-pi/` (+ SDK) | **After one `make build-rootfs`**; macOS reads Docker volume automatically |

When `prebuilt/flutter-engine/` and `prebuilt/flutter-pi/` are committed, **`build-rootfs` copies binaries only** (minutes, not hours).

Version pins: `overlay/buildroot/flutter-{engine,sdk,pi}.version`. Bump → `make rebuild-deps` → rebuild once → `make build-prebuilt` → commit `prebuilt/`.

### P1 — vendor SDK tree (no separate fetch)

| Component | Source | Notes |
|-----------|--------|-------|
| **RKNPU2 runtime** (`librknnrt.so`, `rknn_server`) | `sdk/external/rknpu2` | `SITE_METHOD=local`; ships with Rockchip SDK |
| Kernel / U-Boot / Mali | SDK tree | compiled, not downloaded |

### P1 — host-only (not Buildroot)

| Component | Command | Notes |
|-----------|---------|-------|
| **Hello World app** | `make build-flutter-app` | Host Flutter + `flutterpi_tool`; not in rootfs build |
| **Boot logo BMP** | `make build-boot-logo` | Generated from `board/logo/splash_icon.png` |

### P3 / P5 — host-side deps (not in P1 defconfig)

Version pins: `overlay/third-party/{opencv,rknn-toolkit,mediamtx}.version`.

| Target | Output | Stage | Notes |
|--------|--------|-------|-------|
| `make build-opencv` | `.cache/opencv/*.tar.gz` | P3 | OpenCV + opencv_contrib **source** (4.5.5) |
| `make build-opencv-ximgproc` | `.cache/opencv/ximgproc-ed/` | P3 | EdgeDrawing sources for libai |
| `make build-rknn-toolkit` | `.cache/rknn-toolkit/` | P3 | RKNN-Toolkit2 wheel + torch (ONNX→RKNN) |
| `make build-rknn-rt` | `prebuilt/rknn-rt/` | P3 | Linux **aarch64** `librknnrt.so` (dev libai) |
| `make build-mediamtx` | `prebuilt/mediamtx/linux-arm64/` | P5 | Source in `.cache/`; binary in `prebuilt/` |
| `make build-dev-deps` | all P3/P5 targets above | — | |
| `make build-all-deps` | `build-deps` + `build-dev-deps` | — | |

Board runtime `librknnrt.so` still comes from SDK `external/rknpu2` via Buildroot (`build-rknn-rt` is for **dev host** libai builds). MediaMTX defconfig line remains commented out until P5.

Force refresh after version bump: `make rebuild-dev-deps` or per-target `make rebuild-opencv`, etc.

### Git LFS (recommended)

Large binaries under `prebuilt/` are listed in `.gitattributes` for Git LFS. Before the first commit of prebuilt artifacts:

```bash
git lfs install
git add .gitattributes prebuilt/
```

Without LFS, `prebuilt/flutter-sdk/` (~1 GB) may be too heavy for plain git — prefer LFS or omit SDK from commits and let `make build-flutter-sdk` populate it locally.

### Buildroot `dl/` (generic packages)

Buildroot still downloads standard packages (gcc, systemd, wpa_supplicant, …) into `sdk/buildroot/dl/` on first build. That is the normal Buildroot cache — not version-pinned product deps. Share or preserve `buildroot/dl/` to avoid re-downloading on clean output trees.

---

After `make build` and flash: boot logo ≤2 s → Hello World auto-start → home frame ≤10 s. Confirm profile:

```bash
make config                # or: bash scripts/docker-run.sh bash -lc 'grep RK_BUILDROOT output/.config'
```

On **macOS**, builds use a Docker volume for the SDK (not a bind mount from APFS). Bind-mounting during Buildroot often **crashes Docker Desktop** (`BUILD_BIND_MOUNT=1` to force, not recommended).

On **Linux**, `make lunch` / `make build-rootfs` run `./build.sh` directly under `sdk/`; firmware lands in `sdk/output/`.

### `innohi_board` / WiFi-BT firmware errors

Rockchip Innohi scripts reference **`sdk/innohi_board/`** (not in git; only **`sdk/innohi/`** ships). `make apply-overlay` syncs firmware + binaries and patches `post-wifibt.sh` / `mk-rootfs.sh`. **lws_hmi** skips Innohi **MainServer** autostart (Plan A uses systemd + `hmi.service`). If `build-rootfs` fails on `innohi_board` or `MainServer`, run `make apply-overlay` again (macOS: auto before each Docker build).

### USB flash (macOS only)

Tool: vendored at `tools/upgrade_tool/` (macOS binary; v2.44).

```bash
make devices
SERIAL=... make bootloader   # adb reboot loader
make loader                      # upgrade_tool ul
make upgrade                     # upgrade_tool uf (IMAGE=... to override)
```

MaskROM: power off, hold Recovery, USB via hub. Multi-device: set `SERIAL=` from `make devices`.

### macOS Docker Desktop tips

- Run `make docker-volume-init` once before the first build.
- Init uses **tar** (not rsync) for the bulk copy; macOS APFS xattrs / vendor symlinks often make rsync exit 23 even at 99%.
- If a previous init copied ~99% then failed, re-run `make docker-volume-init` — it detects the existing tree and skips re-copy.
- Keep `BUILD_JOBS=4` (default on macOS) unless you know you have headroom.
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

1. **Buildroot fs-overlay** — `buildroot/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/system/etc/`:
   - `960_lcd_param_rk356x.txt`
   - `lcd_mipi_param.txt`
   - `LCD_PARAM_RK356X_V11_0.txt` (same content as 960 file; legacy name for ParamUpdate)

2. **post-rootfs hook** — `device/rockchip/common/post-hooks/05-lws-hmi-display.sh` (re-copy from `lws-hmi/board/` during `./build.sh rootfs`).

3. **BR2_ROOTFS_OVERLAY** line appended to `buildroot/configs/rockchip/chips/rk3566_rk3568.config`.

`MainServer` / `ParamUpdate` (from Innohi) expect paths under **`/system/etc/`**; the overlay creates that tree on Buildroot.

## What this repo adds

| Path | Purpose |
|------|---------|
| `board/ynh960_defconfig` | Innohi ynh960 board selection (DTS + FIT + LCD param) |
| `board/960_lcd_param_rk356x.txt` | From production ynh960 Android |
| `board/lcd_mipi_param.txt` | MIPI init table from production Android |
| `board/from-device/` | adb pull backups |
| `overlay/buildroot/chips/lws_hmi_*.config` | **方案 A** + flutter-pi Kconfig 片段 |
| `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig` | 瘦身 Buildroot defconfig（无 Weston/Chromium） |
| `board/logo/splash_icon.png` | Boot splash 源图 → `make build-boot-logo` |
| `app/lws_hmi_app/` | P1 Hello World Flutter 工程 |
| `scripts/build-{boot-logo,flutter-app}.sh` | Logo / App 构建脚本 |
| `overlay/.../lws-hmi-fs-overlay/etc/systemd/` | `hmi.service`、journald volatile 等 |
| `overlay/.../06-lws-hmi-systemd.sh` | 镜像构建时 enable hmi / disable mediamtx·sshd |
| `overlay/.../05-lws-hmi-display.sh` | Buildroot post-rootfs install hook |
| `overlay/.../check-sdk.sh` | Skip ext4/WSL guards when `LWS_HMI_DOCKER=1` |
| `docker/Dockerfile` | Ubuntu 22.04 + Rockchip build dependencies |

The upstream SDK ships **ynh962** defconfig but **ynh960.dts** in kernel; this overlay adds the missing `ynh960_defconfig`.

## Environment

```bash
export LINUX_SDK=~/Downloads/rk356x_linux6.1_20250730_1126/...   # ~ and $HOME both work
export BUILD_JOBS=4                                          # parallel make jobs (default 4 on macOS)
export SERIAL=10.0.0.239:5555                            # for pull-display-params (adb over network)
export REBUILD_IMAGE=1                                       # rebuild Docker image
make build                                                   # full firmware (kernel + rootfs + images)
```

## Notes

- First Buildroot build downloads packages; allow network and ~20GB+ free disk under SDK `output/` and `buildroot/dl/`.
- Rockchip’s pre-build check used to probe `sources.buildroot.net` with HTTP HEAD on the site root, which always returns **403** (not a VPN/GFW issue). `make setup` patches `check-buildroot.sh` to probe `buildroot.net/downloads/buildroot-<version>.tar.gz` instead. Package downloads during the build may still use `sources.buildroot.net` via `BR2_PRIMARY_SITE`; that is separate from this pre-flight check.
- Flutter-pi is enabled via `lws_hmi_flutter.config` (SDK in-tree `flutter-pi` + `flutter-engine` packages). See [`app/README.md`](app/README.md).
- **Flutter-pi HMI 规划**（组件裁剪、Hello World、RTSP 分阶段）：[`docs/flutter-pi-hmi-plan.md`](docs/flutter-pi-hmi-plan.md)
- `make clean-overlay` restores patched SDK files (`check-sdk.sh`, `rk3566_rk3568.config`, post-hook, fs-overlay).
