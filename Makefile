# Rockchip RK356x Linux SDK (Innohi) build environment for ynh960 + Buildroot.
# Optional: create .env from .env.example (see README). Bash `source .env` works too.
# USB flash: set SERIAL or USB_LOCATION when more than one device is connected.

SHELL := /bin/bash
.DEFAULT_GOAL := help

LWS_HMI_SDK ?= $(HOME)/Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126

DOCKER_IMAGE ?= lws-hmi-builder:22.04
DOCKER_PLATFORM ?= linux/amd64

BOARD ?= ynh960
CHIP ?= rk3566_rk3568
DEFCONFIG ?= ynh960_defconfig

# USB flash / adb (override when multiple devices connected)
SERIAL ?=
USB_LOCATION ?=
IMAGE ?=
FLASH_ENV = SERIAL='$(SERIAL)' USB_LOCATION='$(USB_LOCATION)' UPDATE_IMG='$(IMAGE)'

.PHONY: help setup link-sdk apply-overlay clean-overlay docker-image docker-volume-init docker-volume-sync docker-volume-pull docker-volume-status shell lunch config build build-rootfs build-boot-logo build-flutter-app pull-display-params devices bootloader loader upgrade

# Run a command with `.env` exported (if present).
# Usage: $(call WITH_DOTENV,<command>)
define WITH_DOTENV
bash -c 'set -euo pipefail; \
  __ENV_SERIAL="$${SERIAL-}"; __ENV_USB_LOCATION="$${USB_LOCATION-}"; __ENV_IMAGE="$${IMAGE-}"; \
  __ENV_LWS_HMI_SDK="$${LWS_HMI_SDK-}"; __ENV_LWS_HMI_JOBS="$${LWS_HMI_JOBS-}"; \
  __ENV_LWS_HMI_BIND_MOUNT="$${LWS_HMI_BIND_MOUNT-}";   __ENV_LWS_HMI_AUTO_PULL="$${LWS_HMI_AUTO_PULL-}"; \
  set -a; [[ -f .env ]] && source .env; set +a; \
  [[ -n "$$__ENV_SERIAL" ]] && export SERIAL="$$__ENV_SERIAL"; \
  [[ -n "$$__ENV_USB_LOCATION" ]] && export USB_LOCATION="$$__ENV_USB_LOCATION"; \
  [[ -n "$$__ENV_IMAGE" ]] && export IMAGE="$$__ENV_IMAGE"; \
  [[ -n "$$__ENV_LWS_HMI_SDK" ]] && export LWS_HMI_SDK="$$__ENV_LWS_HMI_SDK"; \
  [[ -n "$$__ENV_LWS_HMI_JOBS" ]] && export LWS_HMI_JOBS="$$__ENV_LWS_HMI_JOBS"; \
  [[ -n "$$__ENV_LWS_HMI_BIND_MOUNT" ]] && export LWS_HMI_BIND_MOUNT="$$__ENV_LWS_HMI_BIND_MOUNT"; \
  [[ -n "$$__ENV_LWS_HMI_AUTO_PULL" ]] && export LWS_HMI_AUTO_PULL="$$__ENV_LWS_HMI_AUTO_PULL"; \
  $(1)'
endef

help:
	@echo "lws-hmi — Buildroot + ynh960 via Docker (linux/amd64)"
	@echo ""
	@echo "Setup:"
	@echo "  make setup                 # link SDK + apply overlay + build Docker image"
	@echo "  make link-sdk              # symlink sdk/ → Rockchip Linux SDK"
	@echo "  make apply-overlay         # patch SDK with lws-hmi board/buildroot overlay"
	@echo "  make clean-overlay         # restore patched SDK files"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-image          # build lws-hmi-builder container image"
	@echo "  make docker-volume-init    # (macOS) copy SDK into Docker volume — run once before build"
	@echo "  make docker-volume-sync    # refresh overlay into volume (auto before each build on macOS)"
	@echo "  make docker-volume-pull    # copy output/ from volume back to host SDK"
	@echo "  make docker-volume-status  # show volume mount and SDK tree status"
	@echo "  make shell                 # interactive shell in builder container"
	@echo ""
	@echo "Build:"
	@echo "  make lunch                 # select rk3566_rk3568:ynh960_defconfig in SDK"
	@echo "  make config                # show current SDK .config summary"
	@echo "  make build                 # full SDK build (long; needs network)"
	@echo "  make build-rootfs          # Buildroot rootfs only"
	@echo "  make build-boot-logo       # splash_icon.png → logo.bmp for U-Boot/kernel splash"
	@echo "  make build-flutter-app     # cross-build Hello World → fs-overlay /opt/hmi"
	@echo ""
	@echo "Board:"
	@echo "  make pull-display-params   # adb pull LCD/MIPI tables from ynh960 → board/"
	@echo ""
	@echo "USB Flash:"
	@echo "  make devices               # list devices (android / Loader / Maskrom / …)"
	@echo "  make bootloader            # adb reboot loader → RockUSB (upgrade_tool ld)"
	@echo "  make loader                # flash MiniLoaderAll.bin via USB (MaskROM/Loader)"
	@echo "  make upgrade               # flash update.img via USB (IMAGE=... to override)"
	@echo ""
	@echo "Common Env Vars:"
	@echo "  LWS_HMI_SDK=$(LWS_HMI_SDK)"
	@echo "  LWS_HMI_JOBS=4             # limit parallel make jobs (default 4 on macOS)"
	@echo "  LWS_HMI_BIND_MOUNT=1       # force macOS bind mount (not recommended)"
	@echo "  LWS_HMI_AUTO_PULL=1        # pull output/ from Docker volume before flash (macOS)"
	@echo "  SERIAL=<serial>            # device serial (bootloader / loader / upgrade)"
	@echo "  USB_LOCATION=<id>          # RockUSB LocationID for upgrade_tool -s (PDF §1.11)"
	@echo "  IMAGE=<path>               # firmware image for make upgrade (default: sdk/output/firmware/update.img)"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)"
	@echo "  DOCKER_PLATFORM=$(DOCKER_PLATFORM)"
	@echo ""
	@echo "Notes:"
	@echo "  - Set VAR=value before the command, or add a '.env' in the repo root (see .env.example)."
	@echo "  - Run 'make setup' then 'make docker-volume-init' (macOS) before the first build."
	@echo "  - Typical flow: lunch → build-rootfs → docker-volume-pull → devices → bootloader → upgrade."
	@echo "  - Use 'make build-flutter-app' + 'make build-rootfs' for app changes; 'make build' when boot logo/kernel changes."

# --- Setup ---

setup: link-sdk apply-overlay docker-image
	@echo "Setup complete. Run: make shell  OR  make lunch"

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
