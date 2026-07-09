# lws-hmi

Buildroot + **ynh960** (Innohi RK3568) on the Rockchip Linux 6.1 SDK.

- **Linux (Ubuntu x64):** native build in `sdk/` (no Docker).
- **macOS:** Docker `linux/amd64` builder + Docker volume for the SDK tree.

## Prerequisites

- Extracted SDK at `~/Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126` (override with `LINUX_SDK` in `.env`)
- Host Flutter SDK at `~/Downloads/flutter-sdk-3.24.4/` (override with `FLUTTER_SDK` in `.env`; run `make fetch-flutter-sdk` to populate)
- **Linux:** Ubuntu 22.04+ on ext4; Rockchip build deps (see `docker/Dockerfile` package list)
- **macOS:** Docker Desktop (Apple Silicon: enable Rosetta for `linux/amd64`)

## Quick start — Linux (Ubuntu x64)

```bash
cd ~/Workspace/lws-hmi
make setup                 # link SDK + apply ynh960 overlay
make build-deps            # once: build-dev-deps + runtime prebuilt
make build                 # overlay → lunch → logo → app → kernel → rootfs → update.img
# macOS only: make flash
```

Granular stages (daily iteration):

```bash
make lunch && make build-rootfs    # rootfs only
make build-kernel                  # kernel-only
make build-flutter-app             # app-only (+ re-apply overlay)
make build-img && make flash       # repack after kernel/rootfs change
```

## Quick start — macOS

```bash
cd ~/Workspace/lws-hmi
make setup                 # link SDK + overlay + Docker image
make docker-volume-init    # copy SDK into Docker volume (once; ~10–30 min)
make build-deps            # once: build-dev-deps + runtime prebuilt
make build                 # same pipeline as Linux (Docker volume)
make docker-volume-pull    # if update.img missing on host after build
make flash                 # USB flash (macOS only)
```

## Dependencies (prebuilt-first)

**Two buckets:**

| Bucket | Command | What |
|--------|---------|------|
| **Runtime** (`build-runtime-deps`) | Board / `libai.so` stack | Flutter、**GStreamer/MPP**、MediaMTX、OpenCV、RKNN runtime |
| **Dev host** (`build-dev-deps`) | x86 上编应用、转模型 | `FLUTTER_SDK`（交叉编 Dart）、RKNN-Toolkit（ONNX→`.rknn`） |

`make build-deps` = `build-dev-deps` + `build-runtime-deps`（engine 编译需要 host Flutter SDK）。

### Runtime — `make build-runtime-deps`

`make check-prebuilt` 在 `build-rootfs` 前校验下列项（缺一则失败）：

| 组件 | 产出位置 | 板上角色 |
|------|----------|----------|
| flutter-engine / flutter-pi | `prebuilt/flutter-*` | HMI 显示栈 |
| mediamtx | `prebuilt/mediamtx/` + fs-overlay `usr/bin/` | RTSP 中继（服务默认 disable） |
| **GStreamer + MPP** | Buildroot + `prebuilt/gstreamer/` | RTSP 预览/取帧 |
| OpenCV + ximgproc | `.cache/opencv/` | 编进 `libai.so` |
| RKNN runtime | `prebuilt/rknn-rt/` + SDK rknpu2 | NPU 推理 |
| **P2/P3/P5 平台库** | `prebuilt/platform-packages/` | libmodbus、yaml-cpp、sqlite、avahi |

另：rootfs 还通过 Buildroot `BR2_PACKAGE_RKNPU2` 从 SDK `external/rknpu2` 安装系统级 `librknnrt.so` + `rknn_server`（P1 已开）。`prebuilt/rknn-rt` 与 libai 构建版本对齐。

| Target | 作用 |
|--------|------|
| `make build-runtime-deps` | 上表全部（含 GStreamer） |
| `make build-platform-packages` | libmodbus + yaml-cpp + sqlite + avahi |
| `make fetch-opencv` / `fetch-opencv-ximgproc` | OpenCV 源码 |
| `make fetch-rknn-rt` | aarch64 `librknnrt.so` |
| `make build-flutter-engine` / `build-flutter-pi` / `build-mediamtx` | 单项 |
| `make check-prebuilt` | 校验 runtime（`build-rootfs` 自动） |
| `make build-rootfs` | 装已接入 defconfig 的 prebuilt（Flutter 等） |

### Dev host — `make build-dev-deps`

**不上板**，`check-prebuilt` 不检查：

| Target | 产出 | 用途 |
|--------|------|------|
| `make fetch-flutter-sdk` | `FLUTTER_SDK/install/` | `make build-flutter-app`、engine 编译辅助 |
| `make fetch-rknn-toolkit` | `.cache/rknn-toolkit/` | 开发机上 ONNX→RKNN 模型转换 |

Force refresh: `make rebuild-deps` / `rebuild-dev-deps` / `rebuild-runtime-deps`。

### 分阶段对照（P1 备好依赖 vs 分阶段开功能）

| 阶段 | 运行时依赖 | P1 `build-runtime-deps` | 仍在本阶段做的（不是装包） |
|------|------------|-----------------|----------------------------|
| P1 | flutter、RKNPU2、Wi‑Fi/BT、GPU | ✓ | Hello World、hmi 自启 |
| P2 | libmodbus | ✓ platform-packages | Modbus/GPIO App demo |
| P3 | OpenCV、yaml-cpp、RKNN | ✓ | **libai.so** 工程与 smoke |
| P4 | — | — | frost_ui / frost_ime 子模块 |
| P5 | GStreamer、MediaMTX、sqlite、Avahi | ✓ | 业务 UI、:5580、云、OTA |

Overlay 脚本 stub（可执行，待 P5 实装逻辑）：`render-mediamtx-config.sh`、`configure-camera-eth0.sh`、`enable-ssh-debug.sh`。

仍待移植：**lensinspector 源码**、`probe-dual-stream.sh`、完整 mediamtx/eth0 渲染逻辑。

### Git LFS (recommended)

Large binaries under `prebuilt/` are listed in `.gitattributes` for Git LFS. Before the first commit of prebuilt artifacts:

```bash
git lfs install
git add .gitattributes prebuilt/
```

Without LFS, large binaries under `prebuilt/` may be too heavy for plain git. The **host Flutter SDK** (~1 GB) is kept **outside the repo** via `FLUTTER_SDK` (like `LINUX_SDK`); run `make fetch-flutter-sdk` to populate it locally.

### Buildroot `dl/` (generic packages)

Buildroot still downloads standard packages (gcc, systemd, wpa_supplicant, …) into `sdk/buildroot/dl/` on first build. That is the normal Buildroot cache — not version-pinned product deps. Share or preserve `buildroot/dl/` to avoid re-downloading on clean output trees.

---

After `make build` and flash: boot logo ≤2 s → Hello World auto-start → home frame ≤10 s. Confirm profile:

```bash
make show-config           # or: bash scripts/docker-run.sh bash -lc 'grep RK_BUILDROOT output/.config'
```

On **macOS**, builds use a Docker volume for the SDK (not a bind mount from APFS). Bind-mounting during Buildroot often **crashes Docker Desktop** (`BUILD_BIND_MOUNT=1` to force, not recommended).

On **Linux**, `make lunch` / `make build-rootfs` run `./build.sh` directly under `sdk/`; firmware lands in `sdk/output/`.

### `innohi_board` / WiFi-BT firmware errors

Rockchip Innohi scripts reference **`sdk/innohi_board/`** (not in git; only **`sdk/innohi/`** ships). `make apply-overlay` syncs firmware + binaries and patches `post-wifibt.sh` / `mk-rootfs.sh`. **lws_hmi** skips Innohi **MainServer** autostart (Plan A uses systemd + `hmi.service`). If `build-rootfs` fails on `innohi_board` or `MainServer`, run `make apply-overlay` again (macOS: auto before each Docker build).

### Innohi SDK-native Linux (`make build-sdk-native`)

Innohi-confirmed path: SDK **`boot.its`** FIT (not `boot-slim.its`), prebuilt loader/uboot, `rockchip_rk3566_rk3568` Buildroot + MainServer.

```bash
make build-sdk-native      # first time (hours)
make repack-sdk-native     # kernel + update.img only
make audit-sdk-native
make flash-sdk-native      # MaskROM
```

**Serial (UART2 / ttyFIQ0, 1500000):** GND + TX↔RX cross. `make serial-miniterm` (quit `Ctrl+]`). Self-test: short TTL TX–RX, type keys — should echo.

**Login (SDK `rockchip_rk3566_rk3568` Buildroot):**

| User | Password |
|------|----------|
| `root` | `rockchip` |

From `buildroot/configs/rockchip/base/common.config` (`BR2_TARGET_GENERIC_ROOT_PASSWD`). Not empty.

**Do not** `make build-uboot` on ynh960 unless Innohi instructs — wrong uboot bricks MaskROM recovery.

### USB flash (macOS only)

Tool: vendored at `tools/upgrade_tool/` (macOS binary; v2.44).

MaskROM recovery (device not visible after loader upload — loader reboot drops USB briefly):

```bash
make devices               # re-enter MaskROM if empty: power off, hold Recovery, USB via hub
make flash                 # auto: ul if Maskrom, uf if Loader
```

Normal flash from Android:

```bash
make devices
SERIAL=... make bootloader   # adb reboot loader
make flash                     # uf only when already in Loader mode (IMAGE=... to override)
```

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

`MainServer` / `ParamUpdate` (from Innohi) expect paths under **`/system/etc/`**; the overlay creates that tree on Buildroot. **P1** also installs `MountAll` + `param-update.service` to apply MIPI params before `hmi.service` (ynh960 DTS leaves `lcd0_x/y=0` until ParamUpdate runs).

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
export FLUTTER_SDK=~/Downloads/flutter-sdk-3.24.4                # host Flutter SDK (outside git)
export BUILD_JOBS=4                                          # parallel make jobs (default 4 on macOS)
export SERIAL=10.0.0.239:5555                            # for pull-display-params (adb over network)
export REBUILD_IMAGE=1                                       # rebuild Docker image
make build                 # full firmware → output/firmware/update.img
```

## Notes

- First Buildroot build downloads packages; allow network and ~20GB+ free disk under SDK `output/` and `buildroot/dl/`.
- Rockchip’s pre-build check used to probe `sources.buildroot.net` with HTTP HEAD on the site root, which always returns **403** (not a VPN/GFW issue). `make setup` patches `check-buildroot.sh` to probe `buildroot.net/downloads/buildroot-<version>.tar.gz` instead. Package downloads during the build may still use `sources.buildroot.net` via `BR2_PRIMARY_SITE`; that is separate from this pre-flight check.
- Flutter-pi is enabled via `lws_hmi_flutter.config` (SDK in-tree `flutter-pi` + `flutter-engine` packages). See [`app/README.md`](app/README.md).
- **Flutter-pi HMI 规划**（组件裁剪、Hello World、RTSP 分阶段）：[`docs/flutter-pi-hmi-plan.md`](docs/flutter-pi-hmi-plan.md)
- `make clean-overlay` restores patched SDK files (`check-sdk.sh`, `rk3566_rk3568.config`, post-hook, fs-overlay).
