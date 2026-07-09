# Rockchip RK356x Linux SDK (Innohi) build environment for ynh960 + Buildroot.
# Optional: create .env from .env.example (see README). Bash `source .env` works too.
# USB flash: set SERIAL when more than one device is connected.

SHELL := /bin/bash
.DEFAULT_GOAL := help

LINUX_SDK ?= $(HOME)/Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126

DOCKER_IMAGE ?= lws-hmi-builder:22.04
DOCKER_PLATFORM ?= linux/amd64

BOARD ?= ynh960
CHIP ?= rk3566_rk3568
DEFCONFIG ?= ynh960_defconfig

# USB flash / adb (override when multiple devices connected)
SERIAL ?=
IMAGE ?=
FLASH_ENV = SERIAL='$(SERIAL)' UPDATE_IMG='$(IMAGE)'

.PHONY: help setup link-sdk apply-overlay clean-overlay docker-image docker-volume-init docker-volume-sync docker-volume-pull docker-volume-status shell lunch config build build-rootfs build-boot-logo build-flutter-app build-deps build-flutter-engine rebuild-flutter-engine build-flutter-sdk rebuild-flutter-sdk build-flutter-pi rebuild-flutter-pi rebuild-deps build-dev-deps rebuild-dev-deps build-all-deps rebuild-all-deps build-opencv rebuild-opencv build-opencv-ximgproc build-rknn-toolkit rebuild-rknn-toolkit build-rknn-rt rebuild-rknn-rt build-mediamtx rebuild-mediamtx build-prebuilt rebuild-prebuilt pull-display-params devices bootloader loader upgrade

# Run a command with `.env` exported (if present).
# Usage: $(call WITH_DOTENV,<command>)
define WITH_DOTENV
bash -c 'set -euo pipefail; \
  __ENV_SERIAL="$${SERIAL-}"; __ENV_IMAGE="$${IMAGE-}"; \
  __ENV_LINUX_SDK="$${LINUX_SDK-}"; __ENV_BUILD_JOBS="$${BUILD_JOBS-}"; \
  __ENV_BUILD_BIND_MOUNT="$${BUILD_BIND_MOUNT-}"; \
  set -a; [[ -f .env ]] && source .env; set +a; \
  [[ -n "$$__ENV_SERIAL" ]] && export SERIAL="$$__ENV_SERIAL"; \
  [[ -n "$$__ENV_IMAGE" ]] && export IMAGE="$$__ENV_IMAGE"; \
  [[ -n "$$__ENV_LINUX_SDK" ]] && export LINUX_SDK="$$__ENV_LINUX_SDK"; \
  [[ -n "$$__ENV_BUILD_JOBS" ]] && export BUILD_JOBS="$$__ENV_BUILD_JOBS"; \
  [[ -n "$$__ENV_BUILD_BIND_MOUNT" ]] && export BUILD_BIND_MOUNT="$$__ENV_BUILD_BIND_MOUNT"; \
  $(1)'
endef

help:
	@echo "lws-hmi — Buildroot + ynh960 (Linux: native build; macOS: Docker linux/amd64)"
	@echo ""
	@echo "Setup:"
	@echo "  make setup                 # link SDK + apply overlay (+ Docker image on macOS)"
	@echo "  make link-sdk              # symlink sdk/ → Rockchip Linux SDK"
	@echo "  make apply-overlay         # patch SDK with lws-hmi board/buildroot overlay"
	@echo "  make clean-overlay         # restore patched SDK files"
	@echo ""
	@echo "Docker (macOS only):"
	@echo "  make docker-image          # build lws-hmi-builder container image"
	@echo "  make docker-volume-init    # copy SDK into Docker volume — run once before build"
	@echo "  make docker-volume-sync    # refresh overlay into volume (auto before each build)"
	@echo "  make docker-volume-pull    # copy output/ from volume back to host SDK"
	@echo "  make docker-volume-status  # show volume mount and SDK tree status"
	@echo ""
	@echo "Build:"
	@echo "  make shell                 # shell in SDK tree (Linux host / macOS container)"
	@echo "  make lunch                 # select rk3566_rk3568:ynh960_defconfig in SDK"
	@echo "  make config                # show current SDK .config summary"
	@echo "  make build                 # full SDK build (long; needs network)"
	@echo "  make build-rootfs          # Buildroot rootfs only"
	@echo "  make build-boot-logo       # splash_icon.png → logo.bmp for U-Boot/kernel splash"
	@echo "  make build-flutter-app     # cross-build Hello World → fs-overlay /opt/hmi"
	@echo "  make build-deps            # Flutter stack → prebuilt/ (sources in .cache/)"
	@echo "  make build-flutter-engine  # engine source tarball (skipped if prebuilt present)"
	@echo "  make build-flutter-sdk     # host Flutter SDK → prebuilt/flutter-sdk/"
	@echo "  make build-flutter-pi      # flutter-pi source (skipped if prebuilt present)"
	@echo "  make build-prebuilt        # export Buildroot Flutter → prebuilt/ (macOS: from Docker volume)"
	@echo "  make rebuild-deps          # FORCE=1 rebuild all P1 dependency targets"
	@echo ""
	@echo "Dependencies (P3/P5 dev — not in P1 defconfig yet):"
	@echo "  make build-dev-deps        # opencv/rknn sources + prebuilt rknn-rt/mediamtx"
	@echo "  make build-opencv          # OpenCV + opencv_contrib source tarballs"
	@echo "  make build-opencv-ximgproc # ximgproc EdgeDrawing sources (libai)"
	@echo "  make build-rknn-toolkit    # RKNN-Toolkit2 wheel + torch (model convert)"
	@echo "  make build-rknn-rt         # Linux aarch64 librknnrt → prebuilt/rknn-rt/"
	@echo "  make build-mediamtx        # MediaMTX source + binary → prebuilt/mediamtx/"
	@echo "  make build-all-deps        # build-deps + build-dev-deps"
	@echo "  make rebuild-dev-deps      # FORCE=1 rebuild P3/P5 targets"
	@echo ""
	@echo "Board:"
	@echo "  make pull-display-params   # adb pull LCD/MIPI tables from ynh960 → board/"
	@echo ""
	@echo "USB Flash (macOS only):"
	@echo "  make devices               # list devices (android / Loader / Maskrom / …)"
	@echo "  make bootloader            # adb reboot loader → RockUSB (upgrade_tool ld)"
	@echo "  make loader                # flash MiniLoaderAll.bin via USB (MaskROM/Loader)"
	@echo "  make upgrade               # flash update.img via USB (IMAGE=... to override)"
	@echo ""
	@echo "Common Env Vars:"
	@echo "  LINUX_SDK=$(LINUX_SDK)"
	@echo "  BUILD_JOBS=4|8             # parallel jobs (default 4 macOS Docker, 8 Linux native)"
	@echo "  BUILD_BIND_MOUNT=1         # macOS only: bind-mount SDK instead of Docker volume"
	@echo "  SERIAL=<serial>            # device serial (macOS USB flash)"
	@echo "  IMAGE=<path>               # firmware image for make upgrade"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)"
	@echo "  DOCKER_PLATFORM=$(DOCKER_PLATFORM)"
	@echo ""
	@echo "Notes:"
	@echo "  - Run make build-deps before build-rootfs; prebuilt/ in git skips Flutter compile."
	@echo "  - macOS: make setup → make docker-volume-init → make lunch → make build-rootfs."
	@echo "  - macOS flash auto-pulls output/ from Docker volume before loader/upgrade."
	@echo "  - Set VAR=value before the command, or add a '.env' in the repo root (see .env.example)."

# --- Setup ---

setup: link-sdk apply-overlay
	@bash scripts/setup-host.sh

link-sdk:
	@bash scripts/link-sdk.sh

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

docker-volume-status:
	@bash scripts/docker-volume.sh status

shell:
	@bash scripts/docker-run.sh

# --- Build ---

lunch:
	@bash scripts/docker-run.sh ./build.sh $(CHIP):$(DEFCONFIG)

config:
	@bash scripts/docker-run.sh bash -lc 'test -r output/.config && grep -E "^RK_(CHIP|KERNEL_DTS|ROOTFS|DEFCONFIG|BUILDROOT)" output/.config || echo "No output/.config yet — run make lunch first"'

build:
	@bash scripts/docker-run.sh ./build.sh

build-rootfs:
	@bash scripts/docker-run.sh ./build.sh rootfs

build-boot-logo:
	@bash scripts/build-boot-logo.sh

build-flutter-app:
	@bash scripts/build-flutter-app.sh
	@bash scripts/apply-overlay.sh

build-flutter-engine:
	@bash scripts/build-flutter-engine.sh

rebuild-flutter-engine:
	@FORCE=1 bash scripts/build-flutter-engine.sh

build-flutter-sdk:
	@bash scripts/build-flutter-sdk.sh

rebuild-flutter-sdk:
	@FORCE=1 bash scripts/build-flutter-sdk.sh

build-flutter-pi:
	@bash scripts/build-flutter-pi.sh

rebuild-flutter-pi:
	@FORCE=1 bash scripts/build-flutter-pi.sh

build-deps:
	@bash scripts/build-deps.sh

rebuild-deps:
	@FORCE=1 bash scripts/build-deps.sh

build-dev-deps:
	@bash scripts/build-dev-deps.sh

rebuild-dev-deps:
	@FORCE=1 bash scripts/build-dev-deps.sh

build-all-deps:
	@bash scripts/build-all-deps.sh

rebuild-all-deps:
	@FORCE=1 bash scripts/build-all-deps.sh

build-opencv:
	@bash scripts/build-opencv.sh

rebuild-opencv:
	@FORCE=1 bash scripts/build-opencv.sh

build-opencv-ximgproc:
	@bash scripts/build-opencv-ximgproc.sh

build-rknn-toolkit:
	@bash scripts/build-rknn-toolkit.sh

rebuild-rknn-toolkit:
	@FORCE=1 bash scripts/build-rknn-toolkit.sh

build-rknn-rt:
	@bash scripts/build-rknn-rt.sh

rebuild-rknn-rt:
	@FORCE=1 bash scripts/build-rknn-rt.sh

build-mediamtx:
	@bash scripts/build-mediamtx.sh

rebuild-mediamtx:
	@FORCE=1 bash scripts/build-mediamtx.sh

build-prebuilt:
	@bash scripts/build-prebuilt.sh

rebuild-prebuilt:
	@FORCE=1 bash scripts/build-prebuilt.sh

# --- Board ---

pull-display-params:
	@$(call WITH_DOTENV,bash scripts/pull-display-params.sh)
	@bash scripts/apply-overlay.sh

# --- USB Flash ---

devices:
	@$(call WITH_DOTENV,bash scripts/flash-usb.sh devices)

bootloader:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh bootloader)

loader:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh loader)

upgrade:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh upgrade)
