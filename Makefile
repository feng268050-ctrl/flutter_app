# Rockchip RK356x Linux SDK (Innohi) build environment for ynh960 + Buildroot.
#
# Default SDK path (override with LWS_HMI_SDK=...):
LWS_HMI_SDK ?= $(HOME)/Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126

DOCKER_IMAGE ?= lws-hmi-builder:22.04
DOCKER_PLATFORM ?= linux/amd64

BOARD ?= ynh960
CHIP ?= rk3566_rk3568
DEFCONFIG ?= ynh960_defconfig

.PHONY: help setup link-sdk apply-overlay docker-image docker-volume-init docker-volume-sync docker-volume-pull docker-volume-status shell lunch config build build-rootfs clean-overlay pull-display-params build-boot-logo build-flutter-app upgrade loader bootloader devices

# USB flash / adb (override when multiple devices connected)
SERIAL ?=
USB_LOCATION ?=
IMAGE ?=
FLASH_ENV = SERIAL='$(SERIAL)' USB_LOCATION='$(USB_LOCATION)' UPDATE_IMG='$(IMAGE)'

help:
	@echo "lws-hmi — Buildroot + ynh960 via Docker (linux/amd64)"
	@echo ""
	@echo "  make setup          link SDK + apply ynh960 board overlay + build Docker image"
	@echo "  make docker-volume-init   (macOS) copy SDK into Docker volume — run once before build"
	@echo "  make docker-volume-sync   refresh overlay into volume (auto before each build on macOS)"
	@echo "  make docker-volume-pull   copy output/ from volume back to host SDK"
	@echo "  make shell          interactive shell in builder container"
	@echo "  make lunch          select rk3566_rk3568:ynh960_defconfig in SDK"
	@echo "  make config         show current SDK .config summary"
	@echo "  make build          full SDK build (long; needs network)"
	@echo "  make build-rootfs   build Buildroot rootfs only"
	@echo "  make build-boot-logo   PNG → logo.bmp for U-Boot/kernel splash"
	@echo "  make build-flutter-app cross-build Hello World → fs-overlay /opt/hmi"
	@echo "  make pull-display-params  adb pull LCD/MIPI tables from ynh960"
	@echo "  make devices         list devices (android / Loader / Maskrom / …)"
	@echo "  make bootloader      adb reboot loader → RockUSB (upgrade_tool ld)"
	@echo "  make loader          flash MiniLoaderAll.bin via USB (MaskROM/Loader)"
	@echo "  make upgrade         flash update.img via USB (IMAGE=... to override)"
	@echo "  make clean-overlay  remove lws-hmi patches from SDK"
	@echo "Environment:"
	@echo "  LWS_HMI_SDK=$(LWS_HMI_SDK)"
	@echo "  LWS_HMI_JOBS=4          limit parallel make jobs (default 4 on macOS)"
	@echo "  LWS_HMI_BIND_MOUNT=1    force macOS bind mount (not recommended)"
	@echo "  LWS_HMI_UPGRADE_TOOL_DIR=~/Downloads/upgrade_tool_v2.44_for_mac"
	@echo "  LWS_HMI_AUTO_PULL=1     pull output/ from Docker volume before flash (macOS)"
	@echo "  SERIAL=...              device serial (bootloader / loader / upgrade)"
	@echo "  USB_LOCATION=...        RockUSB LocationID for upgrade_tool -s (PDF §1.11)"
	@echo "  IMAGE=...               firmware image for make upgrade (default: sdk/output/firmware/update.img)"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)"
	@echo "  DOCKER_PLATFORM=$(DOCKER_PLATFORM)"

setup: link-sdk apply-overlay docker-image
	@echo "Setup complete. Run: make shell  OR  make lunch"

link-sdk:
	@bash scripts/link-sdk.sh

apply-overlay:
	@bash scripts/apply-overlay.sh

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

lunch:
	@bash scripts/docker-run.sh ./build.sh $(CHIP):$(DEFCONFIG)

config:
	@bash scripts/docker-run.sh bash -lc 'test -r output/.config && grep -E "^RK_(CHIP|KERNEL_DTS|ROOTFS|DEFCONFIG|BUILDROOT)" output/.config || echo "No output/.config yet — run make lunch first"'

build:
	@bash scripts/docker-run.sh ./build.sh

build-rootfs:
	@bash scripts/docker-run.sh ./build.sh rootfs

clean-overlay:
	@bash scripts/apply-overlay.sh --restore

pull-display-params:
	@bash scripts/pull-display-params.sh
	@bash scripts/apply-overlay.sh

build-boot-logo:
	@bash scripts/build-boot-logo.sh

build-flutter-app:
	@bash scripts/build-flutter-app.sh
	@bash scripts/apply-overlay.sh

devices:
	@bash scripts/flash-usb.sh devices

bootloader:
	@$(FLASH_ENV) bash scripts/flash-usb.sh bootloader

loader:
	@$(FLASH_ENV) bash scripts/flash-usb.sh loader

upgrade:
	@$(FLASH_ENV) bash scripts/flash-usb.sh upgrade
