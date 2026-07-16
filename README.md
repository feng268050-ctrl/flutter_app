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
```

- Host Flutter SDK at repo-root `flutter-sdk/` (gitignored; run `make fetch-flutter-sdk`; override with `FLUTTER_SDK` in `.env`)
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
3. `make build-kernel` / `make build-rootfs` / `make build-img` — each publishes its own artifacts to host `output/firmware/` (`boot.img`+`boot_b.img`, `rootfs.img`, and factory `update.img`). Daily `make upgrade` only needs kernel/rootfs builds — not `build-img` or a manual export.

---

## Make commands

Run `make help` for the full target list. Stages below are **one command per line** — run in order.

### Setup (once per machine)

```bash
git lfs install
git lfs pull
make extract-linux-sdk SRC=/path/to/rk356x_linux6.1_…
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
make extract-linux-sdk SRC=/path/to/rk356x_linux6.1_…
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

Firmware stage outputs:

- `make build-kernel` builds two independently hashed FIT images containing the same Linux kernel: `boot.img` selects `rootfs_a`, while `boot_b.img` selects `rootfs_b`. Publishes both to `output/firmware/`.
- `make build-rootfs` builds `rootfs.img` and publishes it to `output/firmware/`.
- `make build-img` does **not** compile the kernel or rootfs. It packages the existing loader, U-Boot, misc, both FIT images, and rootfs into `output/firmware/update.img` for `make flash`.
- Full-system `make upgrade` does **not** transfer `update.img`. It transfers `boot.img`, `boot_b.img`, and `rootfs.img` plus the matching board apply helpers, writes the inactive A/B system, and returns when board apply reports `apply.status=ok` (reboot requested) or SSH disconnects. Staging the matching helpers lets safety fixes migrate without first modifying the active rootfs. The command then tells the operator to wait for the device to finish restarting before reconnecting.

### Daily iteration — by what you changed

The examples below prefer A/B OTA on a board already flashed with the P2.4 GPT and helpers. To use the factory/USB path instead, replace the final `make upgrade` with:

```bash
# Or: package update.img, enter Loader, and flash
make build-img
make reboot-loader
make flash
```

**Flutter app** (`app/hmi/`) — `/opt/hmi` is installed during rootfs build:

```bash
make build-app
make build-rootfs
make upgrade
```

**Boot splash** (`board/logo/`):

```bash
make build-boot-logo
make build-kernel
make upgrade
```

**Kernel / DTS / display DTS** (`overlay/kernel/`, related `board/`):

```bash
make apply-overlay
make build-kernel
make build-rootfs
make upgrade
```

**Rootfs overlay** — systemd units, `usr/lib/lws-hmi/*`, LCD params, anything under `overlay/.../lws-hmi-fs-overlay/` except the app bundle:

```bash
make apply-overlay
make build-rootfs
make upgrade
```

**Buildroot defconfig / Kconfig fragments** (`overlay/buildroot/`):

```bash
make apply-overlay
make check-prebuilt
make build-rootfs
make upgrade
```

After a major defconfig or toolchain change, you may need `make clean-buildroot-output` before `make build-rootfs` (see [`docs/build-optimization.md`](docs/build-optimization.md)).

**Runtime prebuilt only** (`prebuilt/`, flutter-engine, gstreamer, etc.):

```bash
make build-runtime-deps
make apply-overlay
make build-rootfs
make upgrade
```

### Release / factory image

A release or factory-flash artifact always requires `make build-img`, even if daily iteration used `make upgrade`. If the kernel and rootfs are already up to date:

```bash
make build-img
```

This produces `output/firmware/update.img`. To test the release image on hardware, then run `make reboot-loader` and `make flash`.

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

### App iteration (USB plug-ssh or remote SSH, no rootfs reflash)

After one firmware flash with USB plug-ssh support:

```bash
make shell                      # interactive root shell; SERIAL=... when multiple boards
make logs                       # live journal; optional UNIT= TAG= GREP= PRIORITY= KERNEL=1
make build-app
make push-app                   # SERIAL=... when multiple boards; hot-swap /opt/hmi (no rootfs rebuild)
```

Full-system A/B (kernel/rootfs, not app-only): `make upgrade` streams `boot.img` + `boot_b.img` + `rootfs.img`.

Remote SSH (board LAN/WLAN sshd on — Demo **LAN SSH debug** or `enable-ssh-debug.sh`):

```bash
# On device (serial / USB-SSH / Demo toggle):
#   /usr/lib/lws-hmi/enable-ssh-debug.sh
make connect 192.168.1.50       # or: make connect IP=192.168.1.50
make devices                    # MODE=SSH row
IP=192.168.1.50 make shell
IP=192.168.1.50 make push-app
IP=192.168.1.50 make upgrade    # both FIT variants + rootfs.img; not RockUSB
make disconnect 192.168.1.50
```

`IP=` selects **registered SSH only** (never USB-SSH). `SERIAL=` still selects by board serial for either mode. `make reboot` works over SSH; `make reboot-loader` remains USB-SSH / RockUSB / adb only.

Commands that intentionally restart the Linux board automatically remove its matching persistent `MODE=SSH` registration: full-system `make upgrade`, `make reboot`, and USB-SSH `make reboot-loader` (matched to a registered row by board serial). Ephemeral `MODE=USB-SSH` rows are not stored and disappear automatically when the USB network gadget goes down. Run `make connect <ip>` again after enabling LAN SSH in the new boot session.

`make shell` opens an interactive `root` terminal over USB ECM SSH or a registered remote SSH IP, similar to `adb shell`. VBUS loads the modular `g_ether` driver with stable per-device USB serial/MAC identity; unplug unloads it. The implementation does not create a configfs gadget or reset DWC3. The previous SDK/container shell command is now `make sdk-shell`. `make push-app` stages `libapp.so` + `flutter_assets` on the board, installs the complete payload while the current HMI keeps running, then restarts `hmi.service` with bounded recovery attempts. The flashed kernel must include the DRM GEM teardown fix. Host needs `sshpass` (password `rockchip`). `make devices` lists RockUSB, USB-SSH, and registered SSH rows in one table. **`make upgrade`** (P2.4) streams **`boot.img` (FIT for rootfs A) + `boot_b.img` (FIT for rootfs B) + `rootfs.img`** with single-line transfer progress, writes the inactive A/B system, and reboots — **not** RockUSB/`upgrade_tool uf` (use **`make flash`** for GPT / U-Boot). Once apply completes or the connection drops for reboot, the command exits with a clear prompt to wait for the device to finish restarting before reconnecting. Hardware prefs live on **userdata** (`/userdata/lws-hmi`): kept across reboot / push-app / **`make upgrade`**; **`make flash` must factory-reset them** — see [`docs/storage-layout.md`](docs/storage-layout.md) §Prefs and [`docs/ab-slot-misc.md`](docs/ab-slot-misc.md).

### Debug iteration (USB plug-ssh / remote SSH, P1.5)

First time on a host (pinned Flutter 3.24.4 + `sshpass`):

```bash
make debug-setup
```

After the board has a rootfs with the P1.5 debug overlay scripts (`hmi-launch.sh`, `debug-app-*`):

```bash
make debug-app                   # SERIAL=... or IP=... when multiple boards
```

Or open `app/hmi` in VS Code / Cursor and start **lws-hmi (USB-SSH / SSH debug)** from Run and Debug. Pre-launch runs `make debug-host-prepare`: for registered `IP=` / `MODE=SSH` it only checks reachability (no USB ECM); for USB-SSH it configures the host ECM interface (macOS may request `sudo`). Put `IP=` in `.env` so the IDE picks the SSH board. The non-interactive Flutter custom-device hooks never prompt for `sudo`.

`make debug-app` builds a debug bundle (`kernel_blob.bin`), uploads the matching **debug-runtime** engine on first use (cached under `/var/lib/lws-hmi/debug-runtime/`), replaces `/opt/hmi`, and starts flutter-pi with VM Service over SSH port forwarding (USB-SSH or registered IP). Stopping the IDE closes the tunnel but **leaves the debug app running** on the device. Replace it with a release build using `make build-app` + `make push-app`.

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

`make build-kernel` / `make build-rootfs` / `make build-img` each publish their matching files under `output/firmware/` from the Docker volume (macOS). Manual `make docker-export-artifacts` is legacy; prefer `SCOPE=boot|rootfs|update|firmware` only when debugging. `make docker-volume-pull` is a legacy alias for full `linux-sdk/output/` export.

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
| P2.1 | ALSA/音频（按需）、wlan0 DHCP；eth0 驱动已入镜像 | 音频包按需开；`BR2_PACKAGE_DHCPCD` | 喇叭 / Wi‑Fi / BT / **以太网 RJ45** / 触控 / 背光 **硬件 smoke**（🔄：喇叭/背光/旋转已通；Wi‑Fi/BT Demo 已落地待板验） |
| P2.2 | timedatectl / RTC（`hwclock`） | 按需 | Demo 日期/时间 + `DateTimeController` 抽象 |
| P2.3 | — | — | P2.1 硬件偏好 **重启后 restore** |
| P2.4 | A/B **boot+rootfs** 成对双槽 | `parameter` 改表 | `make upgrade`（SSH；**含双 FIT `boot.img` / `boot_b.img` + `rootfs.img`**，免 loader）；供 P5.8 OTA 复用 |
| P3 | OpenCV、yaml-cpp、RKNN | ✓ | **libai.so** 工程与 smoke |
| P3.5 | flutter SDK + engine + flutter-pi **三件套升级** | 重编 prebuilt | P4 前；见 [`docs/flutter-pi-hmi-plan.md` §6.5](docs/flutter-pi-hmi-plan.md#65-flutter-engine-版本策略与升级p35) |
| P4 | — | — | frost_ui / frost_ime 子模块 |
| P5 | GStreamer、MediaMTX、sqlite、Avahi | ✓ | 业务 UI、:5580、云；**P5.8 OTA**（复用 P2.4） |

Overlay 脚本（P1 启动链）：`boot-verify.sh`、`env-verify.sh`（§3.4 平台栈）、`ynh960-display-init.sh`、`set-performance-mode.sh`；P5 保留 `render-mediamtx-config.sh`（`mediamtx.service` ExecStartPre）。eth0 配网、SSH 调试、**mediamtx 启停**（**IPC ping 通后** `systemctl start`）由 Flutter App 内 `MediaMtxRelayCoordinator` / platform channel 触发，不再打包 shell stub。

仍待移植：**lensinspector 源码**、`probe-dual-stream.sh`、完整 mediamtx YAML 渲染逻辑、IPC 专链 eth0 配网（Dart/脚本移植 lws-ui `CameraEth0Configurator`，**P5.1**）。

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

The **host Flutter SDK** (~1 GB) is separate from Git LFS and lives in gitignored `flutter-sdk/` at the repo root; run `make fetch-flutter-sdk` to populate it (override path with `FLUTTER_SDK` in `.env`).

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

**ynh960 Wi‑Fi/BT chip:** board SDIO is **AIC8800D80** (`c8a1:0082`), not AP6256. Keep `RK_WIFIBT_MODULES` non-empty so `post-wifibt` copies kernel `*.ko` + Innohi firmware; runtime uses `wifibt-bringup.sh` / `rk_wifi_init` (`aic8800_bsp`/`fdrv`/`btlpm`). Kernel fragment: `lws-hmi-ynh960-wifibt.config`.

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
make push-app                  # SERIAL=... or IP=... when multiple devices
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
- **ynh960 串口 / GPIO / pinmux 台账**（P2.1）：[`docs/ynh960-io-pinmux-ledger.md`](docs/ynh960-io-pinmux-ledger.md)
- `make clean-overlay` restores patched SDK files (`check-sdk.sh`, `rk3566_rk3568.config`, post-hook, fs-overlay).
