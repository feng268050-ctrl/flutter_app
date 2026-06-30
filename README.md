# lws-hmi

Buildroot + **ynh960** (Innohi RK3568) using the Rockchip Linux 6.1 SDK inside Docker (`linux/amd64`), similar to `lws-ui`’s RKNN Docker workflow.

## Prerequisites

- Docker Desktop (Apple Silicon: runs as `linux/amd64` via emulation)
- Extracted SDK at `~/Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126`

## Quick start

```bash
cd ~/Workspace/lws-hmi
make setup                 # link SDK, apply ynh960 overlay, build Docker image
make docker-volume-init    # macOS: copy SDK into Docker volume (once; ~10–30 min)
make lunch                 # rk3566_rk3568:ynh960 → lws_hmi Buildroot profile
make build-boot-logo       # splash_icon.png → logo.bmp
make build-flutter-app     # Hello World → fs-overlay /opt/hmi
make build-rootfs          # Buildroot rootfs only (first run: long, needs network)
make docker-volume-pull    # copy firmware output/ back to host SDK path
make devices               # list adb + RockUSB targets
make bootloader            # adb reboot loader → RockUSB Loader
make loader                # USB: flash MiniLoaderAll.bin
make upgrade               # default: output/firmware/update.img
make upgrade IMAGE=/path/to/custom.img
```

### P1 acceptance (ynh960)

After `make build` and flash: boot logo ≤2 s → Hello World auto-start → home frame ≤10 s. Confirm profile:

```bash
bash scripts/docker-run.sh bash -lc 'grep RK_BUILDROOT output/.config'
```

On **macOS**, builds use a Docker volume for `/work/sdk` by default (not a bind mount from APFS). Bind-mounting the SDK during Buildroot triggers massive small-file I/O over virtiofs and often **crashes Docker Desktop** even with 20GB RAM allocated.

Inside the container the SDK lives at `/work/sdk`. On Linux, it bind-mounts from `lws-hmi/sdk`; on macOS, from the `lws-hmi-sdk` Docker volume.

### USB flash (ynh960)

Tool: `~/Downloads/upgrade_tool_v2.44_for_mac` (`命令行开发工具使用文档.pdf`: `ld` / `ul` / `uf`, multi-device `-s LocationID`).

```bash
make devices
SERIAL=... make bootloader   # adb reboot loader
make loader                      # upgrade_tool ul
make upgrade                     # upgrade_tool uf (IMAGE=... to override)
```

MaskROM: power off, hold Recovery, USB via hub. Multi-device: `SERIAL=` or `USB_LOCATION=` from `make devices`.

### macOS Docker Desktop tips

- Run `make docker-volume-init` once before the first build.
- Init uses **tar** (not rsync) for the bulk copy; macOS APFS xattrs / vendor symlinks often make rsync exit 23 even at 99%.
- If a previous init copied ~99% then failed, re-run `make docker-volume-init` — it detects the existing tree and skips re-copy.
- Keep `LWS_HMI_JOBS=4` (default on macOS) unless you know you have headroom.
- Enable **Settings → General → Use Rosetta for x86_64/amd64 emulation** (Apple Silicon).
- If builds still crash, use a native Linux VM instead of Docker Desktop.
- Force the old bind-mount path (not recommended): `LWS_HMI_BIND_MOUNT=1 make build-rootfs`

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
export LWS_HMI_SDK=/path/to/rk356x_linux6.1_20250730_1126   # override SDK location
export LWS_HMI_JOBS=4                                      # parallel make jobs (default 4 on macOS)
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
