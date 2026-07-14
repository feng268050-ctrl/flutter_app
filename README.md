# lws-hmi

Buildroot + **ynh960** (Innohi **RK3566**) on the Rockchip Linux 6.1 SDK.

**Product line:** ynh960 → RK3566 (entry), ynh962 → RK3568B2 (mid, cut-down 3568), ynh961 → RK3568 (high) — three tiers of the **same product line** (minor chip/interface differences, largely similar hardware). **One Linux firmware image** across the line is the design goal (aligned with lws-ui Android). **P1–P5 develop and validate on ynh960**; no per-SKU defconfig fork yet. SDK path `rk3566_rk3568` is Rockchip’s 3566/3568 family tooling profile.

- **Linux (Ubuntu x64):** native build in repo-root `linux-sdk/` (no Docker).
- **macOS:** Docker `linux/amd64` builder + Docker volume for the SDK tree.

## Prerequisites

- Rockchip Linux SDK copied to repo-root `linux-sdk/` (gitignored)
- Host Flutter SDK at repo-root `flutter-sdk/` (gitignored; run `make fetch-flutter-sdk`; override with `FLUTTER_SDK` in `.env`)
- **Linux:** Ubuntu 22.04+ on ext4; Rockchip build deps (see `docker/Dockerfile` package list)
- **macOS:** Docker Desktop (Apple Silicon: enable Rosetta for `linux/amd64`)

## Quick start — Linux (Ubuntu x64)

```bash
cd ~/Workspace/lws-hmi
make setup
make build-deps
make build
make show-config
```

On macOS, add `make flash` after `make build` (see below).

## Quick start — macOS

```bash
cd ~/Workspace/lws-hmi
make setup
make docker-volume-init
make build-deps
make build
make flash
```

**macOS Docker flow** (volume is ephemeral; host keeps inputs + exported outputs):

1. `make docker-volume-init` — copy host SDK → volume (once)
2. `make apply-overlay` / `make build-*` — repo bind-mounted into container; build in volume
3. `make build-img` / `make build-kernel` — auto-export `output/firmware/` to host (`output/firmware/update.img` for `make flash`)

---

## Make commands

Run `make help` for the full target list. Stages below are **one command per line** — run in order.

### Setup (once per machine)

```bash
make setup
make fetch-flutter-sdk
make apply-overlay
```

macOS only, before the first build:

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
make build-dev-deps
make build-runtime-deps
make fetch-flutter-sdk
make build-flutter-engine
make build-flutter-pi
make build-gstreamer
make build-platform-packages
make build-mediamtx
```

Force refresh a bucket: `make rebuild-deps`, `make rebuild-runtime-deps`, etc.

### Full firmware

`make build` runs: `check-prebuilt` → `apply-overlay` → `lunch` → `build-boot-logo` → `build-app` → `build-kernel` → `build-rootfs` → `build-img`.

```bash
make build
make show-config
```

### Daily iteration — by what you changed

**Flutter app** (`app/hmi/`) — `/opt/hmi` is installed during rootfs build:

```bash
make build-app
make build-rootfs
make build-img
make flash
```

**Boot splash** (`board/logo/`):

```bash
make build-boot-logo
make build-kernel
make build-img
make flash
```

**Kernel / DTS / display DTS** (`overlay/kernel/`, related `board/`):

```bash
make apply-overlay
make build-kernel
make build-img
make flash
```

**Rootfs overlay** — systemd units, `usr/lib/lws-hmi/*`, LCD params, anything under `overlay/.../lws-hmi-fs-overlay/` except the app bundle:

```bash
make apply-overlay
make build-rootfs
make build-img
make flash
```

**Buildroot defconfig / Kconfig fragments** (`overlay/buildroot/`):

```bash
make apply-overlay
make check-prebuilt
make build-rootfs
make build-img
make flash
```

After a major defconfig or toolchain change, you may need `make clean-buildroot-output` before `make build-rootfs` (see [`docs/build-optimization.md`](docs/build-optimization.md)).

**Runtime prebuilt only** (`prebuilt/`, flutter-engine, gstreamer, etc.):

```bash
make build-runtime-deps
make apply-overlay
make build-rootfs
make build-img
make flash
```

**Repack only** — rootfs and kernel already up to date; only rebundle `update.img`:

```bash
make build-img
make flash
```

Linux hosts: firmware is under `linux-sdk/output/firmware/` as well as `output/firmware/` after export steps.

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
SERIAL=... make reboot-loader
make flash
```

Loader path from Linux board (USB plug-ssh, no adb):

```bash
make devices                    # auto-discovers USB-SSH, configures host 192.168.55.2
make reboot-loader                # USB-SSH → device reboot-loader (SERIAL= optional)
make flash                      # macOS only
```

### App iteration (USB plug-ssh, no rootfs reflash)

After one firmware flash with USB plug-ssh support:

```bash
make shell                      # interactive root shell; SERIAL=... when multiple boards
make logs                       # live journal; optional UNIT= TAG= GREP= PRIORITY= KERNEL=1
make build-app
make push-app                   # SERIAL=... when multiple boards
```

`make shell` opens an interactive `root` terminal over USB ECM SSH, similar to `adb shell`. VBUS loads the modular `g_ether` driver with stable per-device USB serial/MAC identity; unplug unloads it. The implementation does not create a configfs gadget or reset DWC3. The previous SDK/container shell command is now `make sdk-shell`. `make push-app` stages `libapp.so` + `flutter_assets` on the board, installs the complete payload while the current HMI keeps running, then restarts `hmi.service` with bounded recovery attempts. The flashed kernel must include the DRM GEM teardown fix. Host needs `sshpass` (password `rockchip`). `make devices` lists RockUSB and USB-SSH rows in one table.

### Debug iteration (USB plug-ssh, P1.5)

First time on a host (pinned Flutter 3.24.4 + `sshpass`):

```bash
make debug-setup
```

After the board has a rootfs with the P1.5 debug overlay scripts (`hmi-launch.sh`, `debug-app-*`):

```bash
make debug-app                   # SERIAL=... when multiple boards
```

Or open `app/hmi` in VS Code / Cursor and start **lws-hmi (USB-SSH debug)** from Run and Debug. Its pre-launch terminal configures the host USB interface first (macOS may request the `sudo` password), then builds and runs `flutter run -d lws-hmi`. The non-interactive Flutter custom-device hooks never prompt for `sudo`.

`make debug-app` builds a debug bundle (`kernel_blob.bin`), uploads the matching **debug-runtime** engine on first use (cached under `/var/lib/lws-hmi/debug-runtime/`), replaces `/opt/hmi`, and starts flutter-pi with VM Service over USB-SSH port forwarding. Stopping the IDE closes the tunnel but **leaves the debug app running** on the device. Replace it with a release build using `make build-app` + `make push-app`.

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

`make build-img` / `make build-kernel` export `output/firmware/` from the Docker volume to the host automatically (macOS). `make docker-volume-pull` is a legacy alias for full `linux-sdk/output/` export.

---

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
| mediamtx | `prebuilt/mediamtx/` + fs-overlay `usr/bin/` | RTSP 中继（**相机 ping 通后** App 启动；默认不在 wants） |
| **GStreamer + MPP** | Buildroot + `prebuilt/gstreamer/` | RTSP 预览/取帧 |
| OpenCV + ximgproc | `.cache/opencv/` | 编进 `libai.so` |
| RKNN runtime | `prebuilt/rknn-rt/` + SDK rknpu2 | NPU 推理 |
| **P2/P3/P5 平台库** | `prebuilt/platform-packages/` | libmodbus、yaml-cpp、sqlite、avahi |

另：P1 通过 `make fetch-rknn-rt` 将 SDK `external/rknpu2` 的 `librknnrt.so` + `rknn_server` 同步进 fs-overlay（本 SDK 无 `BR2_PACKAGE_RKNPU2` 包）。`prebuilt/rknn-rt` 供 P3 `libai.so` 交叉链接。

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
| `make fetch-flutter-sdk` | `flutter-sdk/` | `make build-app`、engine 编译辅助 |
| `make fetch-rknn-toolkit` | `.cache/rknn-toolkit/` | 开发机上 ONNX→RKNN 模型转换 |

Force refresh: `make rebuild-deps` / `rebuild-dev-deps` / `rebuild-runtime-deps`。

### 分阶段对照（P1 备好依赖 vs 分阶段开功能）

| 阶段 | 运行时依赖 | P1 `build-runtime-deps` | 仍在本阶段做的（不是装包） |
|------|------------|-----------------|----------------------------|
| P1 | flutter、RKNPU2、Wi‑Fi/BT、GPU | ✓ | Hello World、hmi 自启 |
| P2 | libmodbus | ✓ platform-packages | Modbus/GPIO App demo（✅ 已完成） |
| P2.1 | ALSA/音频（按需）、eth0 脚本 | 音频包按需开 | 喇叭 / Wi‑Fi / BT / IPC / 触控 / 背光 **硬件 smoke** |
| P3 | OpenCV、yaml-cpp、RKNN | ✓ | **libai.so** 工程与 smoke |
| P3.5 | flutter SDK + engine + flutter-pi **三件套升级** | 重编 prebuilt | P4 前；见 [`docs/flutter-pi-hmi-plan.md` §6.5](docs/flutter-pi-hmi-plan.md#65-flutter-engine-版本策略与升级p35) |
| P4 | — | — | frost_ui / frost_ime 子模块 |
| P5 | GStreamer、MediaMTX、sqlite、Avahi | ✓ | 业务 UI、:5580、云、OTA |

Overlay 脚本（P1 启动链）：`boot-verify.sh`、`env-verify.sh`（§3.4 平台栈）、`ynh960-display-init.sh`、`set-performance-mode.sh`；P5 保留 `render-mediamtx-config.sh`（`mediamtx.service` ExecStartPre）。eth0 配网、SSH 调试、**mediamtx 启停**（**IPC ping 通后** `systemctl start`）由 Flutter App 内 `MediaMtxRelayCoordinator` / platform channel 触发，不再打包 shell stub。

仍待移植：**lensinspector 源码**、`probe-dual-stream.sh`、完整 mediamtx YAML 渲染逻辑、eth0 配网（Dart/脚本移植 lws-ui `CameraEth0Configurator`，**P2.1** 优先脚本联调）。

### Git LFS (recommended)

Large binaries under `prebuilt/` are listed in `.gitattributes` for Git LFS. Before the first commit of prebuilt artifacts:

```bash
git lfs install
git add .gitattributes prebuilt/
```

Without LFS, large binaries under `prebuilt/` may be too heavy for plain git. The **host Flutter SDK** (~1 GB) lives in gitignored `flutter-sdk/` at the repo root; run `make fetch-flutter-sdk` to populate it (override path with `FLUTTER_SDK` in `.env`).

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
verify-env                         # §3.4 平台栈（不含 flutter-pi）
```

Boot KPI 优化阶段与状态表：[`docs/boot-kpi-optimization.md`](docs/boot-kpi-optimization.md).

On **macOS**, builds use a Docker volume for the SDK (not a bind mount from APFS). Bind-mounting during Buildroot often **crashes Docker Desktop** (`BUILD_BIND_MOUNT=1` to force, not recommended).

On **Linux**, `make lunch` / `make build-rootfs` run `./build.sh` directly under `linux-sdk/`; firmware lands in `linux-sdk/output/`.

### `innohi_board` / WiFi-BT firmware errors

Rockchip Innohi scripts reference **`linux-sdk/innohi_board/`** (not in git; only **`linux-sdk/innohi/`** ships). `make apply-overlay` syncs firmware + binaries and patches `post-wifibt.sh` / `mk-rootfs.sh`. **lws_hmi** skips Innohi **MainServer** autostart (Plan A uses systemd + `hmi.service`). If `build-rootfs` fails on `innohi_board` or `MainServer`, run `make apply-overlay` again (macOS: auto before each Docker build).

### Innohi SDK-native Linux (`make build-sdk-native`)

Innohi-confirmed path: SDK **`boot.its`** FIT (not `boot-slim.its`), prebuilt loader/uboot, `rockchip_rk3566_rk3568` Buildroot + MainServer.

```bash
make build-sdk-native      # first time (hours)
make repack-sdk-native     # kernel + update.img only
make audit-sdk-native
make flash-sdk-native      # MaskROM
```

**Serial (UART2 / ttyFIQ0, 1500000):** GND + TX↔RX cross. `make serial-console` (quit `Ctrl+]`). Self-test: short TTL TX–RX, type keys — should echo.

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
SERIAL=... make reboot-loader   # adb reboot loader (Android)
make flash                     # uf only when already in Loader mode (IMAGE=... to override)
```

Normal flash from Linux HMI (USB plug-ssh):

```bash
make devices
make reboot-loader               # USB-SSH → device reboot-loader
make flash                     # macOS host
```

App deploy without reflash:

```bash
make build-app
make push-app                  # SERIAL=... when multiple USB-SSH devices
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
| `app/hmi/` | P1 Hello World Flutter 工程 |
| `AGENTS.md` | AI agent 工作流 + 改动后的重新构建指引 |
| `scripts/build-{boot-logo,flutter-app}.sh` | Logo / App 构建脚本 |
| `overlay/.../lws-hmi-fs-overlay/etc/systemd/` | `hmi.service`、journald volatile 等 |
| `overlay/.../06-lws-hmi-systemd.sh` | 镜像构建时 enable hmi / disable mediamtx·sshd |
| `overlay/.../05-lws-hmi-display.sh` | Buildroot post-rootfs install hook |
| `overlay/.../check-sdk.sh` | Skip ext4/WSL guards when `LWS_HMI_DOCKER=1` |
| `docker/Dockerfile` | Ubuntu 22.04 + Rockchip build dependencies |

The upstream SDK ships **ynh962** board defconfig but **ynh960.dts** in kernel; this overlay adds the missing **`ynh960_defconfig`** for our RK3566 target. (SDK `ynh962` naming ≠ product ynh962 / RK3568B2 SKU — see [`docs/flutter-pi-hmi-plan.md`](docs/flutter-pi-hmi-plan.md) §3.0.)

## Environment

```bash
export FLUTTER_SDK=flutter-sdk                                        # host Flutter SDK (gitignored at repo root)
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
