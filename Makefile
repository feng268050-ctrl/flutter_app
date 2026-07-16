# Rockchip RK356x Linux SDK (Innohi) build environment for ynh960 + Buildroot.
# Optional: create .env from .env.example (see README). Bash `source .env` works too.
# USB flash: set SERIAL when more than one device is connected.

SHELL := /bin/bash
.DEFAULT_GOAL := help

FLUTTER_SDK ?= $(CURDIR)/flutter-sdk

DOCKER_IMAGE ?= lws-hmi-builder:22.04
DOCKER_PLATFORM ?= linux/amd64

BOARD ?= ynh960
CHIP ?= rk3566_rk3568
DEFCONFIG ?= ynh960_defconfig

# USB flash / adb / remote SSH (override when multiple devices connected)
SERIAL ?=
IP ?=
IMAGE ?=
FLASH_ENV = SERIAL='$(SERIAL)' IP='$(IP)' UPDATE_IMG='$(IMAGE)'

# Positional IP for: make connect <ip> / make disconnect <ip>
ifneq ($(filter connect disconnect,$(firstword $(MAKECMDGOALS))),)
  SSH_DEVICE_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(SSH_DEVICE_ARGS),)
$(SSH_DEVICE_ARGS):
	@:
  endif
endif

# Positional path for: make extract-linux-sdk /path/to/sdk-volumes
ifneq ($(filter extract-linux-sdk,$(firstword $(MAKECMDGOALS))),)
  EXTRACT_LINUX_SDK_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(EXTRACT_LINUX_SDK_ARGS),)
$(EXTRACT_LINUX_SDK_ARGS):
	@:
  endif
endif

.PHONY: help setup apply-overlay clean-overlay docker-image docker-volume-init docker-volume-sync docker-volume-pull docker-export-artifacts docker-volume-status sdk-shell shell logs lunch show-config build build-kernel build-uboot fetch-uboot build-rootfs build-img build-boot-logo build-app build-debug-app debug-setup debug-host-prepare debug-app build-reboot-rockusb-loader check-prebuilt clean-buildroot-output migrate-buildroot-output fix-buildroot-host-rpaths export-prebuilt export-prebuilt-runtime build-prebuilt export-buildroot-toolchain build-runtime-deps rebuild-runtime-deps build-deps rebuild-deps build-flutter-engine rebuild-flutter-engine fetch-flutter-engine refetch-flutter-engine cache-publish-flutter-engine build-flutter-pi rebuild-flutter-pi fetch-flutter-sdk refetch-flutter-sdk build-dev-deps rebuild-dev-deps fetch-opencv refetch-opencv fetch-opencv-ximgproc fetch-rknn-toolkit refetch-rknn-toolkit fetch-rknn-rt refetch-rknn-rt build-mediamtx rebuild-mediamtx build-gstreamer rebuild-gstreamer build-platform-packages rebuild-platform-packages rebuild-prebuilt extract-linux-sdk pull-display-params audit devices connect disconnect push-app upgrade reboot reboot-loader loader flash flash-android watch-maskrom sdk-native-prepare build-sdk-native repack-sdk-native audit-sdk-native flash-sdk-native usb-ssh-setup test-debug-app

# Run a command with `.env` exported (if present).
# Usage: $(call WITH_DOTENV,<command>)
define WITH_DOTENV
bash -c 'set -euo pipefail; \
  __ENV_SERIAL="$${SERIAL-}"; __ENV_IP="$${IP-}"; __ENV_IMAGE="$${IMAGE-}"; \
  __ENV_FLUTTER_SDK="$${FLUTTER_SDK-}"; __ENV_BUILD_JOBS="$${BUILD_JOBS-}"; \
  __ENV_BUILD_BIND_MOUNT="$${BUILD_BIND_MOUNT-}"; \
  set -a; [[ -f .env ]] && source .env; set +a; \
  [[ -n "$$__ENV_SERIAL" ]] && export SERIAL="$$__ENV_SERIAL"; \
  [[ -n "$$__ENV_IP" ]] && export IP="$$__ENV_IP"; \
  [[ -n "$$__ENV_IMAGE" ]] && export IMAGE="$$__ENV_IMAGE"; \
  [[ -n "$$__ENV_FLUTTER_SDK" ]] && export FLUTTER_SDK="$$__ENV_FLUTTER_SDK"; \
  [[ -n "$$__ENV_BUILD_JOBS" ]] && export BUILD_JOBS="$$__ENV_BUILD_JOBS"; \
  [[ -n "$$__ENV_BUILD_BIND_MOUNT" ]] && export BUILD_BIND_MOUNT="$$__ENV_BUILD_BIND_MOUNT"; \
  $(1)'
endef

help:
	@echo "lws-hmi — Buildroot + ynh960 (Linux: native build; macOS: Docker linux/amd64)"
	@echo ""
	@echo "Setup:"
	@echo "  make setup                 # apply overlay (+ Docker image on macOS)"
	@echo "  make apply-overlay         # patch SDK with lws-hmi board/buildroot overlay"
	@echo "  make clean-overlay         # restore patched SDK files"
	@echo ""
	@echo "Docker (macOS only):"
	@echo "  make docker-image          # build lws-hmi-builder container image"
	@echo "  make docker-volume-init    # (1) copy host SDK → Docker volume — once"
	@echo "  make docker-volume-sync    # refresh host SDK/overlay into volume before build"
	@echo "  make docker-export-artifacts # (3) volume firmware → host (auto after build-img/kernel)"
	@echo "  make docker-volume-pull    # alias: export full linux-sdk/output/ (legacy)"
	@echo "  make docker-volume-status  # show volume mount and SDK tree status"
	@echo ""
	@echo "Build (scope = active #include in overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig):"
	@echo "  make build                 # full image: prebuilt → overlay → lunch → logo → app → kernel → rootfs → img"
	@echo "  make lunch                 # select ynh960 + lws_hmi Buildroot profile in SDK"
	@echo "  make show-config           # print RK_* lines from output/.config"
	@echo "  make build-boot-logo       # board/logo → logo.bmp (kernel FIT splash)"
	@echo "  make build-app             # release app (AOT) → fs-overlay /opt/hmi + apply-overlay"
	@echo "  make build-debug-app       # debug app bundle → .cache (make debug-app / IDE; rarely run alone)"
	@echo "  make build-kernel          # kernel, DTB, boot.img (DTS / logo changes)"
	@echo "  make build-rootfs          # rootfs.tar (enabled defconfig packages + fs-overlay)"
	@echo "  make build-img             # pack update.img from loader + boot + rootfs"
	@echo "  make sdk-shell             # interactive shell in linux-sdk (native Linux or macOS Docker)"
	@echo "  See docs/build-optimization.md"
	@echo ""
	@echo "Dependencies (prebuilt / fetch — run before first make build-rootfs):"
	@echo "  make extract-linux-sdk SRC=<dir>  # xz split volumes → linux-sdk/ (FORCE=1 to replace)"
	@echo "  make check-prebuilt        # verify prebuilt for enabled defconfig fragments"
	@echo "  make build-deps            # build-dev-deps + build-runtime-deps"
	@echo "  make build-dev-deps        # dev host: FLUTTER_SDK + RKNN-Toolkit"
	@echo "  make build-runtime-deps    # runtime: flutter, gstreamer, mediamtx, opencv, rknn-rt"
	@echo "  make build-gstreamer       # runtime: MPP + GStreamer → prebuilt/ (before build-rootfs)"
	@echo "  make build-platform-packages # runtime: libmodbus, yaml-cpp, sqlite, avahi → prebuilt/"
	@echo "  make build-flutter-engine  # runtime: compile engine → prebuilt/ (needs fetch first)"
	@echo "  make fetch-flutter-engine  # runtime: engine sources → .cache/flutter-engine/"
	@echo "  make build-flutter-pi      # runtime: flutter-pi → prebuilt/"
	@echo "  make build-mediamtx        # runtime: mediamtx arm64 → prebuilt/"
	@echo "  make fetch-opencv          # runtime: OpenCV sources → .cache/opencv/"
	@echo "  make fetch-opencv-ximgproc # runtime: ximgproc EdgeDrawing → .cache/"
	@echo "  make fetch-rknn-rt         # runtime: aarch64 librknnrt → prebuilt/rknn-rt/"
	@echo "  make fetch-flutter-sdk     # dev: host Flutter SDK → flutter-sdk/"
	@echo "  make fetch-rknn-toolkit    # dev: RKNN-Toolkit2 + torch (ONNX→RKNN on x86)"
	@echo "  make export-prebuilt       # re-export flutter + runtime (usually build-* already did)"
	@echo "  rebuild-*                  # FORCE=1 refresh (e.g. make rebuild-runtime-deps)"
	@echo ""
	@echo "Debug (device / host — USB-SSH, remote SSH, Flutter, serial):"
	@echo "  make usb-ssh-setup         # host ECM IP + sshpass doctor (macOS may sudo)"
	@echo "  make debug-host-prepare    # USB ECM or registered SSH reachability for debug-app/IDE"
	@echo "  make connect <ip>          # register remote SSH board (MODE=SSH in make devices)"
	@echo "  make disconnect <ip>       # remove registered remote SSH board"
	@echo "  make devices               # RockUSB + USB-SSH + registered SSH"
	@echo "  make shell                 # interactive device shell (USB-SSH or SSH)"
	@echo "  make logs                  # live journal; UNIT/TAG/GREP/PRIORITY/KERNEL filters"
	@echo "  make push-app              # scp app over SSH (USB-SSH or registered IP)"
	@echo "  make upgrade               # SSH A/B: dual FIT + rootfs; reboot removes SSH registry row"
	@echo "  make debug-setup           # Flutter Custom Device + IDE doctor (one-time host)"
	@echo "  make debug-app             # flutter run -d lws-hmi (USB-SSH or SSH)"
	@echo "  make serial-console        # TTL UART ttyFIQ0 @ 1500000 (quit Ctrl+])"
	@echo "  make serial-ports          # list host /dev/cu.* TTL ports"
	@echo "  make serial-sniff          # auto-detect baud while power-cycling board"
	@echo ""
	@echo "USB Flash (macOS only):"
	@echo "  make audit                 # pre-flight before make flash"
	@echo "  make reboot                # Linux → USB-SSH/SSH sysrq + unregister; Android → adb"
	@echo "  make reboot-loader         # Linux USB-SSH → RockUSB + unregister; Android → adb"
	@echo "  make flash                 # uf update.img; ul loader when RockUSB is Maskrom (macOS)"
	@echo "  make flash-android         # optional: flash Android instead"
	@echo ""
	@echo "SDK-native (Innohi baseline, optional):"
	@echo "  make build-sdk-native      # Innohi SDK-native ynh960 (boot.its, no lws_hmi)"
	@echo "  make repack-sdk-native     # rebuild kernel+update.img only (after build-sdk-native)"
	@echo "  make audit-sdk-native      # verify boot.its FIT + SDK loader"
	@echo "  make flash-sdk-native      # MaskROM flash SDK-native update.img"
	@echo ""
	@echo "Misc (infrequent — board params, BR output maintenance):"
	@echo "  make pull-display-params        # adb: ynh960 LCD/MIPI tables → board/ (+ apply-overlay)"
	@echo "  make migrate-buildroot-output   # reuse legacy *_lws_hmi_p1 BR tree as lws_hmi"
	@echo "  make fix-buildroot-host-rpaths  # fix stale paths in BR tree after migrate"
	@echo "  make clean-buildroot-output     # delete active BR output dir (keeps dl/; full rootfs rebuild)"
	@echo "  make export-buildroot-toolchain # tar.gz BR host+staging → prebuilt/ (team cache, not runtime)"
	@echo ""
	@echo "Common Env Vars:"
	@echo "  FLUTTER_SDK=$(FLUTTER_SDK)"
	@echo "  BUILD_JOBS=4|8             # parallel jobs (default 4 macOS Docker, 8 Linux native)"
	@echo "  BUILD_BIND_MOUNT=1         # macOS only: bind-mount SDK instead of Docker volume"
	@echo "  LWS_HMI_CACHE_ROOT=...   # NAS mount for large .cache artifacts (see .env.example)"
	@echo "  LWS_HMI_CACHE_URL=...      # optional HTTP mirror of the same layout"
	@echo "  SERIAL=<serial>            # device serial (flash / USB-SSH / SSH)"
	@echo "  IP=<addr>                  # registered SSH only (not USB-SSH); make connect first"
	@echo "  IMAGE=<path>               # firmware image for make flash"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)"
	@echo "  DOCKER_PLATFORM=$(DOCKER_PLATFORM)"
	@echo ""
	@echo "Notes:"
	@echo "  - macOS Docker: init volume → build in Docker → artifacts auto-export to host (see docker-export-artifacts)."
	@echo "  - Full firmware: make build (or build-img after rootfs/kernel changes)."
	@echo "  - MaskROM flash: make flash (uses output/firmware/update.img on host)."
	@echo "  - Set VAR=value before the command, or add a '.env' in the repo root (see .env.example)."

# --- Setup ---

setup: apply-overlay
	@bash scripts/setup-host.sh

apply-overlay:
	@bash scripts/apply-overlay.sh

clean-overlay:
	@bash scripts/apply-overlay.sh --restore

# --- Docker ---

docker-image:
	@bash scripts/docker-build-image.sh

docker-volume-init:
	@bash scripts/docker-volume.sh init

docker-volume-sync:
	@bash scripts/docker-volume.sh sync

docker-volume-pull:
	@bash scripts/docker-volume.sh pull

docker-export-artifacts:
	@bash scripts/docker-export-artifacts.sh firmware

docker-volume-status:
	@bash scripts/docker-volume.sh status

sdk-shell:
	@bash scripts/docker-run.sh

# --- Build ---

lunch:
	@bash scripts/docker-run.sh ./build.sh $(CHIP):$(DEFCONFIG)
	@bash scripts/docker-run.sh bash /work/lws-hmi/scripts/sync-lunch-config.sh

show-config:
	@bash scripts/docker-run.sh bash -lc 'test -r output/.config && grep -E "^RK_(CHIP|KERNEL_DTS|ROOTFS|DEFCONFIG|BUILDROOT)" output/.config || echo "No output/.config yet — run make lunch first"'

build: check-prebuilt apply-overlay lunch build-boot-logo build-app build-kernel build-rootfs build-img
	@echo ""
	@if [[ -r output/firmware/update.img ]]; then \
		echo "Build complete:"; bash scripts/artifact-size.sh output/firmware/update.img; \
	else \
		echo "ERROR: output/firmware/update.img missing after build" >&2; exit 1; \
	fi

build-kernel:
	@bash scripts/docker-run.sh bash -lc 'bash /work/lws-hmi/scripts/sync-lunch-config.sh && bash /work/lws-hmi/scripts/build-kernel-ab.sh'
	@bash scripts/docker-export-artifacts.sh firmware

build-rootfs: check-prebuilt
	@bash scripts/docker-run.sh ./build.sh rootfs
	@bash scripts/lws-hmi-rootfs-postprocess.sh
	@bash scripts/verify-rootfs-overlay.sh

build-img:
	@bash scripts/build-img.sh

build-boot-logo:
	@bash scripts/build-boot-logo.sh

build-app:
	@bash scripts/build-app.sh
	@bash scripts/apply-overlay.sh

build-debug-app:
	@bash scripts/build-debug-app.sh

debug-setup:
	@bash scripts/debug-setup.sh

debug-host-prepare:
	@$(call WITH_DOTENV,bash scripts/debug-host-prepare.sh)

debug-app:
	@$(call WITH_DOTENV,bash scripts/debug-app.sh)

test-debug-app:
	@bash scripts/tests/debug-app.test.sh

build-reboot-rockusb-loader:
	@LWS_HMI_SKIP_OVERLAY=1 bash scripts/docker-run.sh bash /work/lws-hmi/scripts/build-reboot-rockusb-loader.sh

fetch-uboot:
	@bash scripts/docker-run.sh bash /work/lws-hmi/scripts/fetch-uboot.sh

build-uboot:
	@bash scripts/build-uboot.sh

# --- Dependencies ---

# SRC=/path/to/volumes or: make extract-linux-sdk /path/to/volumes
# FORCE=1 replaces an existing linux-sdk/
extract-linux-sdk:
	@SRC='$(SRC)' FORCE='$(FORCE)' DEST='$(DEST)' bash scripts/extract-linux-sdk.sh $(EXTRACT_LINUX_SDK_ARGS)

check-prebuilt:
	@bash scripts/check-prebuilt.sh

build-runtime-deps:
	@bash scripts/build-runtime-deps.sh

rebuild-runtime-deps:
	@FORCE=1 bash scripts/build-runtime-deps.sh

build-deps:
	@bash scripts/build-deps.sh

rebuild-deps:
	@FORCE=1 bash scripts/build-deps.sh

build-flutter-engine:
	@bash scripts/build-flutter-engine.sh

rebuild-flutter-engine:
	@FORCE=1 bash scripts/build-flutter-engine.sh

fetch-flutter-engine:
	@bash scripts/fetch-flutter-engine.sh

refetch-flutter-engine:
	@FORCE=1 bash scripts/fetch-flutter-engine.sh

cache-publish-flutter-engine:
	@bash scripts/cache-publish-flutter-engine.sh

build-flutter-pi:
	@bash scripts/build-flutter-pi.sh

rebuild-flutter-pi:
	@FORCE=1 bash scripts/build-flutter-pi.sh

fetch-flutter-sdk:
	@bash scripts/fetch-flutter-sdk.sh

refetch-flutter-sdk:
	@FORCE=1 bash scripts/fetch-flutter-sdk.sh

build-dev-deps:
	@bash scripts/build-dev-deps.sh

rebuild-dev-deps:
	@FORCE=1 bash scripts/build-dev-deps.sh

fetch-opencv:
	@bash scripts/fetch-opencv.sh

refetch-opencv:
	@FORCE=1 bash scripts/fetch-opencv.sh

fetch-opencv-ximgproc:
	@bash scripts/fetch-opencv-ximgproc.sh

fetch-rknn-toolkit:
	@bash scripts/fetch-rknn-toolkit.sh

refetch-rknn-toolkit:
	@FORCE=1 bash scripts/fetch-rknn-toolkit.sh

fetch-rknn-rt:
	@bash scripts/fetch-rknn-rt.sh

refetch-rknn-rt:
	@FORCE=1 bash scripts/fetch-rknn-rt.sh

build-mediamtx:
	@bash scripts/build-mediamtx.sh

rebuild-mediamtx:
	@FORCE=1 bash scripts/build-mediamtx.sh

build-gstreamer:
	@bash scripts/build-gstreamer.sh

rebuild-gstreamer:
	@FORCE=1 bash scripts/build-gstreamer.sh

build-platform-packages:
	@bash scripts/build-platform-packages.sh

rebuild-platform-packages:
	@FORCE=1 bash scripts/build-platform-packages.sh

export-prebuilt:
	@bash scripts/export-prebuilt.sh

rebuild-prebuilt:
	@FORCE=1 bash scripts/export-prebuilt.sh

# Aliases (flutter-only / runtime-only); prefer make export-prebuilt
build-prebuilt:
	@EXPORT_RUNTIME=0 bash scripts/export-prebuilt.sh

export-prebuilt-runtime:
	@EXPORT_FLUTTER=0 bash scripts/export-prebuilt.sh

# --- SDK-native ---

sdk-native-prepare:
	@LWS_HMI_SKIP_OVERLAY=1 bash scripts/docker-run.sh bash /work/lws-hmi/scripts/prepare-sdk-native.sh

build-sdk-native:
	@LWS_HMI_SKIP_OVERLAY=1 BUILD_JOBS=1 LWS_HMI_NO_MAKEFLAGS=1 bash scripts/docker-run.sh bash /work/lws-hmi/scripts/build-sdk-native.sh

repack-sdk-native:
	@LWS_HMI_SKIP_OVERLAY=1 BUILD_JOBS=1 LWS_HMI_NO_MAKEFLAGS=1 bash scripts/docker-run.sh bash /work/lws-hmi/scripts/repack-sdk-native-img.sh

audit-sdk-native:
	@bash scripts/audit-sdk-native.sh

serial-console:
	@bash scripts/serial-console.sh

serial-sniff:
	@bash scripts/serial-sniff.sh

serial-ports:
	@bash scripts/serial-console.sh --list
	@bash -c 'system_profiler SPUSBDataType 2>/dev/null | grep -A5 -iE "ch34|wch|cp210|ftdi|serial|uart" | head -25 || true'

flash-sdk-native: audit-sdk-native
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh flash)

sdk-native-rootfix:
	@LWS_HMI_SKIP_OVERLAY=1 bash scripts/docker-run.sh bash /work/lws-hmi/scripts/build-sdk-native-rootfix.sh

# --- Misc ---

pull-display-params:
	@$(call WITH_DOTENV,bash scripts/pull-display-params.sh)
	@bash scripts/apply-overlay.sh

clean-buildroot-output:
	@bash scripts/clean-buildroot-output.sh

migrate-buildroot-output:
	@bash scripts/migrate-buildroot-output.sh

fix-buildroot-host-rpaths:
	@bash scripts/fix-buildroot-host-rpaths.sh

export-buildroot-toolchain:
	@bash scripts/export-buildroot-toolchain.sh

audit:
	@bash scripts/audit-firmware.sh

# --- USB Flash ---

devices:
	@$(call WITH_DOTENV,bash scripts/flash-usb.sh devices)

connect:
	@$(call WITH_DOTENV,bash scripts/ssh-devices.sh connect $(IP) $(SSH_DEVICE_ARGS))

disconnect:
	@$(call WITH_DOTENV,bash scripts/ssh-devices.sh disconnect $(IP) $(SSH_DEVICE_ARGS))

shell:
	@$(call WITH_DOTENV,bash scripts/device-shell.sh)

logs:
	@$(call WITH_DOTENV,bash scripts/device-logs.sh)

usb-ssh-setup:
	@$(call WITH_DOTENV,bash scripts/usb-ssh-host-setup.sh)

push-app:
	@$(call WITH_DOTENV,bash scripts/push-app.sh)

upgrade:
	@$(call WITH_DOTENV,bash scripts/upgrade-remote.sh)

reboot:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh reboot)

reboot-loader:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh reboot-loader)

loader:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh loader)

flash:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh flash)

ANDROID_IMG ?= $(CURDIR)/images/android/update.img

flash-android:
	@$(call WITH_DOTENV,UPDATE_IMG='$(ANDROID_IMG)' bash scripts/flash-usb.sh flash)

watch-maskrom:
	@bash scripts/watch-maskrom.sh
