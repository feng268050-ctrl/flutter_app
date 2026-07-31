# Rockchip RK356x Linux SDK (Innohi) build environment for ynh960 + Buildroot.
# Optional: create .env from .env.example (see README). Bash `source .env` works too.
# USB flash: set SN when more than one device is connected.

SHELL := /bin/bash
.DEFAULT_GOAL := help

FLUTTER_SDK ?= $(CURDIR)/flutter-sdk

DOCKER_IMAGE ?= lws-hmi-builder:22.04
DOCKER_PLATFORM ?= linux/amd64

BOARD ?= ynh960
CHIP ?= rk3566_rk3568
DEFCONFIG ?= ynh960_defconfig

# USB flash / adb / remote SSH (override when multiple devices connected)
SN ?=
CHIPID ?=
SERIAL ?=
IP ?=
IMAGE ?=
FLASH_ENV = SN='$(SN)' CHIPID='$(CHIPID)' SERIAL='$(SERIAL)' IP='$(IP)' UPDATE_IMG='$(IMAGE)'

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

.PHONY: help setup apply-overlay clean-overlay docker-image docker-volume-init docker-volume-sync docker-volume-pull docker-export-artifacts docker-volume-status sdk-shell shell logs lunch show-config build build-kernel build-uboot fetch-uboot build-rootfs prepare-rootfs build-img build-oem build-emulator emulator emulator-stop setup-emulator-qemu build-boot-logo build-app prepare-app-assets build-debug-app debug-setup debug-host-prepare debug-app build-reboot-rockusb-loader check-prebuilt check-linux-sdk trim-linux-sdk squash-linux-sdk-platform clean-buildroot-output migrate-buildroot-output fix-buildroot-host-rpaths export-prebuilt export-prebuilt-runtime build-prebuilt export-buildroot-toolchain build-runtime-deps rebuild-runtime-deps build-deps rebuild-deps build-flutter-engine rebuild-flutter-engine fetch-flutter-engine refetch-flutter-engine cache-publish-flutter-engine rebuild-flutter-embedded-linux rebuild-flutter-embedded-linux fetch-flutter-sdk refetch-flutter-sdk build-dev-deps rebuild-dev-deps fetch-opencv refetch-opencv fetch-opencv-ximgproc fetch-rknn-toolkit refetch-rknn-toolkit fetch-rknn-rt refetch-rknn-rt fetch-btop refetch-btop fetch-emulator-swgl build-umtprd rebuild-umtprd build-mediamtx rebuild-mediamtx build-opencv rebuild-opencv build-ai rebuild-ai build-gstreamer rebuild-gstreamer build-platform-packages rebuild-platform-packages rebuild-prebuilt extract-linux-sdk pull-display-params audit devices connect disconnect push-app upgrade-control-board upgrade-process-library reset-process-library set-prop del-prop upgrade reboot reboot-loader loader flash flash-android watch-maskrom usb-ssh-setup test-debug-app alarm alarm-clean smoke-ai l10n l10n-sync l10n-gen l10n-verify

# Run a command with `.env` exported (if present).
# Usage: $(call WITH_DOTENV,<command>)
define WITH_DOTENV
bash -c 'set -euo pipefail; \
  __ENV_SN="$${SN-}"; __ENV_CHIPID="$${CHIPID-}"; __ENV_SERIAL="$${SERIAL-}"; __ENV_IP="$${IP-}"; __ENV_IMAGE="$${IMAGE-}"; \
  __ENV_OEM_ONLY="$${OEM_ONLY-}"; \
  if [[ -n "$${OEM_IMG+x}" ]]; then __ENV_OEM_IMG_SET=1; __ENV_OEM_IMG="$${OEM_IMG-}"; else __ENV_OEM_IMG_SET=0; fi; \
  __ENV_FLUTTER_SDK="$${FLUTTER_SDK-}"; __ENV_BUILD_JOBS="$${BUILD_JOBS-}"; \
  __ENV_BUILD_BIND_MOUNT="$${BUILD_BIND_MOUNT-}"; \
  set -a; [[ -f .env ]] && source .env; set +a; \
  [[ -n "$$__ENV_SN" ]] && export SN="$$__ENV_SN"; \
  [[ -n "$$__ENV_CHIPID" ]] && export CHIPID="$$__ENV_CHIPID"; \
  [[ -n "$$__ENV_SERIAL" ]] && export SERIAL="$$__ENV_SERIAL"; \
  [[ -n "$$__ENV_IP" ]] && export IP="$$__ENV_IP"; \
  [[ -n "$$__ENV_IMAGE" ]] && export IMAGE="$$__ENV_IMAGE"; \
  [[ -n "$$__ENV_OEM_ONLY" ]] && export OEM_ONLY="$$__ENV_OEM_ONLY"; \
  [[ "$$__ENV_OEM_IMG_SET" == 1 ]] && export OEM_IMG="$$__ENV_OEM_IMG"; \
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
	@echo "  make docker-export-artifacts # manual/legacy: SCOPE=boot|rootfs|update|firmware (auto after builds)"
	@echo "  make docker-volume-pull    # alias: export full linux-sdk/output/ (legacy)"
	@echo "  make docker-volume-status  # show volume mount and SDK tree status"
	@echo ""
	@echo "Build (scope = active #include in overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig):"
	@echo "  make build                 # full image: prebuilt → overlay → lunch → logo → app → kernel → rootfs → img"
	@echo "  make lunch                 # select ynh960 + lws_hmi Buildroot profile in SDK"
	@echo "  make show-config           # print RK_* lines from output/.config"
	@echo "  make build-boot-logo       # board/logo → logo.bmp (kernel FIT splash)"
	@echo "  make build-app             # release HMI (AOT) → fs-overlay /opt/hmi + apply-overlay"
	@echo "  make prepare-app-assets    # prune/convert process-library + firmware → assets/.generated/"
	@echo "  make build-debug-app       # debug app bundle → .cache (make debug-app / IDE; rarely run alone)"
	@echo "  make l10n                  # sync child ARBs + flutter gen-l10n (app/lws_hmi)"
	@echo "  make l10n-sync             # regenerate en_US/zh_CN/zh_TW child ARBs only"
	@echo "  make l10n-gen              # flutter gen-l10n only"
	@echo "  make l10n-verify           # fail if ARBs / AppLocalizations drift"
	@echo "  make build-kernel          # dual FIT → output/firmware/boot.img + boot_b.img (exports; for upgrade)"
	@echo "  make build-rootfs          # rootfs → output/firmware/rootfs.img (Weston + eLinux + Mali wayland-gbm)"
	@echo "  make prepare-rootfs        # ensure Buildroot stack → Weston (no rootfs.img pack)"
	@echo "  make build-oem             # pack oem/out/<oem_id>/oem.img (FACTORY_SKU / OEM_ID)"
	@echo "  make build-img             # pack factory.img (+ update.img symlink); needs build-oem"
	@echo "  make sdk-shell             # interactive shell in linux-sdk (native Linux or macOS Docker)"
	@echo "  See docs/build-optimization.md"
	@echo ""
	@echo "Emulator (P3.2 — same Image+rootfs + sim_virt OEM; docs/p32-emulator.md):"
	@echo "  make setup-emulator-qemu   # once (macOS): install qemu-virgl (host VirGL / ANGLE→Metal)"
	@echo "  make fetch-emulator-swgl   # once: guest Mesa virtio_gpu → prebuilt/ (9p; FORCE=1 to refetch)"
	@echo "  make build-emulator        # assemble Image+rootfs+sim_virt oem → output/firmware/emulator/ (grows emulator rootfs copy; EMULATOR_ROOTFS_SIZE=1536M)"
	@echo "  make emulator              # start QEMU (host VirGL required)"
	@echo "  make emulator-stop         # stop lws-hmi QEMU guest (not Android Studio)"
	@echo ""
	@echo "Dependencies (prebuilt / fetch — run before first make build-rootfs):"
	@echo "  make extract-linux-sdk SRC=<dir>  # xz split volumes → linux-sdk/ (FORCE=1 replace; TRIM=1 trim+squash)"
	@echo "  make trim-linux-sdk        # whitelist trim + platform squash (owned tree; keeps dl/output)"
	@echo "  make check-linux-sdk       # fail if forbidden dirs / fat paths remain under linux-sdk/"
	@echo "  make squash-linux-sdk-platform  # re-apply overlay/kernel + device patches into owned tree"
	@echo "  make check-prebuilt        # verify prebuilt for enabled defconfig fragments"
	@echo "  make build-deps            # build-dev-deps + build-runtime-deps"
	@echo "  make build-dev-deps        # dev host: FLUTTER_SDK + RKNN-Toolkit"
	@echo "  make build-runtime-deps    # runtime: flutter, gstreamer, mediamtx, opencv, ai, btop, rknn-rt"
	@echo "  make build-gstreamer       # runtime: MPP + GStreamer → prebuilt/ (before build-rootfs)"
	@echo "  make build-platform-packages # runtime: libmodbus, yaml-cpp, sqlite, avahi → prebuilt/"
	@echo "  make build-flutter-engine  # runtime: compile engine → prebuilt/ (needs fetch first)"
	@echo "  make fetch-flutter-engine  # runtime: engine sources → .cache/flutter-engine/"
	@echo "  make build-flutter-embedded-linux  # Weston image: eLinux Wayland client → prebuilt/"
	@echo "  make build-mediamtx        # runtime: mediamtx arm64 → prebuilt/ (App /opt/hmi)"
	@echo "  make build-opencv          # runtime: OpenCV aarch64 → prebuilt/opencv (for lws_ai)"
	@echo "  make build-ai              # runtime: lws_ai_daemon → prebuilt/ai (App /opt/hmi)"
	@echo "  make build-umtprd          # runtime: umtprd aarch64 → prebuilt/ + fs-overlay (MTP)"
	@echo "  make fetch-btop            # runtime: btop aarch64 musl → prebuilt/ + fs-overlay"
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
	@echo "  make connect <ip>          # register remote SSH board (MODE=SSH; host:port OK for EMU)"
	@echo "  make disconnect <ip>       # remove registered remote SSH board"
	@echo "  make devices               # RockUSB + USB-SSH + SSH + EMU (auto-probe QEMU :2222)"
	@echo "  make shell                 # interactive device shell (USB-SSH or SSH)"
	@echo "  make logs                  # live journal; UNIT/TAG/GREP/PRIORITY/KERNEL filters"
	@echo "  make push-app              # scp app over SSH (USB-SSH or registered IP)"
	@echo "  make upgrade-control-board # push latest control-board bin and trigger upgrade (no version gate)"
	@echo "  make upgrade-process-library # push process-library for device model; force import (no version gate)"
	@echo "  make reset-process-library # clear process-library DB via HMI watcher; re-import bundled (no restart)"
	@echo "  make set-prop KEY=val ...  # upsert product.ini tunables (not brand/model/sn); restart hmi"
	@echo "  make del-prop KEY          # remove one tunable key (not brand/model/sn); restart hmi if changed"
	@echo "  make alarm CODE=L001       # demo warn dialog on device (USB-SSH/SSH; HMI running)"
	@echo "  make alarm-clean           # clear alarm restrictions; keep visible warn popup"
	@echo "  make smoke-ai              # upload stain demo JPG; offline RKNN infer via AI daemon sock"
	@echo "  make upgrade               # SSH stream: inactive FIT+rootfs (+oem); env OEM_ONLY=1 for oem-only"
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
	@echo "  make flash                 # uf factory.img (FACTORY_SKU); IMAGE= override; Maskrom ul (macOS)"
	@echo "  make flash-android         # optional: flash Android instead"
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
	@echo "  SN=<sn|chipid>             # select device by SN or ChipID (flash / USB-SSH / SSH)"
	@echo "  CHIPID=<chipid>            # select by ChipID only (multi-board)"
	@echo "  IP=<addr>                  # registered SSH only (not USB-SSH); make connect first"
	@echo "  IMAGE=<path>               # firmware image for make flash"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)"
	@echo "  DOCKER_PLATFORM=$(DOCKER_PLATFORM)"
	@echo ""
	@echo "Notes:"
	@echo "  - Daily A/B: make build-kernel and/or build-rootfs then make upgrade (no build-img)."
	@echo "  - OEM-only (helpers/profile): make build-oem && OEM_ONLY=1 make upgrade"
	@echo "  - macOS Docker: each build-* publishes matching imgs to output/firmware/ (no manual export)."
	@echo "  - Factory: make build-oem then build-img → output/firmware/<sku>/factory.img; make flash."
	@echo "  - FACTORY_SKU=ynh960-p800 (default); override UBOOT_ID= / OEM_ID=; see board/factory-skus.tsv."
	@echo "  - Emulator: README Make commands → P3.2 emulator (setup → deps → kernel/rootfs → setup-emulator-qemu → fetch-emulator-swgl → build-emulator → emulator)."
	@echo "  - Set VAR=value before the command, or add a '.env' in the repo root (see .env.example)."

# --- Setup ---

setup: apply-overlay
	@bash scripts/setup-host.sh

apply-overlay:
	@# macOS Docker volume: run overlay inside the builder so /work/sdk is updated.
	@if [ "$$(uname -s)" = Darwin ] && [ "${BUILD_BIND_MOUNT:-}" != "1" ]; then \
		bash scripts/docker-run.sh true; \
	else \
		bash scripts/apply-overlay.sh; \
	fi

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
	@bash scripts/docker-export-artifacts.sh $${SCOPE:-firmware}

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

build: check-prebuilt apply-overlay lunch build-boot-logo build-app build-kernel build-rootfs build-oem build-img
	@echo ""
	@if [[ -r output/firmware/update.img || -r output/firmware/ynh960-p800/factory.img ]]; then \
		echo "Build complete:"; \
		bash scripts/artifact-size.sh output/firmware/ynh960-p800/factory.img 2>/dev/null \
			|| bash scripts/artifact-size.sh output/firmware/update.img; \
	else \
		echo "ERROR: factory.img / update.img missing after build" >&2; exit 1; \
	fi

build-kernel:
	@bash scripts/docker-run.sh bash -lc 'bash /work/lws-hmi/scripts/sync-lunch-config.sh && bash /work/lws-hmi/scripts/build-kernel-ab.sh'
	@bash scripts/docker-export-artifacts.sh boot
	@mkdir -p output/firmware/emulator; \
	 if [ -r output/firmware/Image ]; then cp -Lf output/firmware/Image output/firmware/emulator/Image; \
	 echo "published output/firmware/emulator/Image"; fi

# Rootfs: Weston + eLinux + Mali wayland-gbm.
# prepare-rootfs flips Mali/embedder only when the stack stamp differs.
build-rootfs: prepare-rootfs
	@bash scripts/docker-run.sh ./build.sh rootfs
	@bash scripts/lws-hmi-rootfs-postprocess.sh
	@bash scripts/verify-rootfs-overlay.sh
	@bash scripts/docker-export-artifacts.sh rootfs

# Stack ensure only (check-prebuilt + overlay + Mali/embedder). Idempotent.
prepare-rootfs:
	@bash scripts/prepare-rootfs-stack.sh weston

build-oem:
	@bash scripts/build-oem.sh

build-img:
	@bash scripts/build-img.sh

# --- Emulator (P3.2) ---

setup-emulator-qemu:
	@bash scripts/setup-emulator-qemu.sh

fetch-emulator-swgl:
	@bash scripts/fetch-emulator-swgl.sh

build-emulator:
	@bash scripts/build-emulator.sh

emulator:
	@bash scripts/run-emulator.sh start

emulator-stop:
	@bash scripts/run-emulator.sh stop

build-boot-logo:
	@bash scripts/build-boot-logo.sh

build-app:
	@bash scripts/build-app.sh

prepare-app-assets:
	@bash scripts/prepare-hmi-ship-assets.sh

# App UI i18n (edit app_en.arb + app_zh.arb, then make l10n)
l10n:
	@bash scripts/flutter/l10n.sh

l10n-sync:
	@bash scripts/flutter/l10n_sync.sh

l10n-gen:
	@bash scripts/flutter/l10n_gen.sh

l10n-verify:
	@bash scripts/flutter/l10n_verify.sh

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
# TRIM=1 runs trim-linux-sdk after extract
extract-linux-sdk:
	@SRC='$(SRC)' FORCE='$(FORCE)' DEST='$(DEST)' TRIM='$(TRIM)' bash scripts/extract-linux-sdk.sh $(EXTRACT_LINUX_SDK_ARGS)

trim-linux-sdk:
	@DEST='$(DEST)' CLEAN_OUTPUT='$(CLEAN_OUTPUT)' bash scripts/trim-linux-sdk.sh

check-linux-sdk:
	@bash scripts/check-linux-sdk-whitelist.sh

squash-linux-sdk-platform:
	@bash scripts/squash-linux-sdk-platform.sh

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

build-flutter-embedded-linux:
	@bash scripts/build-flutter-embedded-linux.sh

rebuild-flutter-embedded-linux:
	@FORCE=1 bash scripts/build-flutter-embedded-linux.sh

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

fetch-btop:
	@bash scripts/fetch-btop.sh

refetch-btop:
	@FORCE=1 bash scripts/fetch-btop.sh

build-umtprd:
	@bash scripts/build-umtprd.sh

rebuild-umtprd:
	@FORCE=1 bash scripts/build-umtprd.sh

build-mediamtx:
	@bash scripts/build-mediamtx.sh

rebuild-mediamtx:
	@FORCE=1 bash scripts/build-mediamtx.sh

build-opencv:
	@bash scripts/build-opencv.sh

rebuild-opencv:
	@FORCE=1 bash scripts/build-opencv.sh

build-ai:
	@bash scripts/build-ai.sh

rebuild-ai:
	@FORCE=1 bash scripts/build-ai.sh

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

serial-console:
	@bash scripts/serial-console.sh

serial-sniff:
	@bash scripts/serial-sniff.sh

serial-ports:
	@bash scripts/serial-console.sh --list
	@bash -c 'system_profiler SPUSBDataType 2>/dev/null | grep -A5 -iE "ch34|wch|cp210|ftdi|serial|uart" | head -25 || true'

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

# Push latest bundled control-board firmware (host helper).
# Device-side: app watches /run/hmi/upgrade-control-board.cmd and runs upgrade
# without confirm / without version gate.
upgrade-control-board:
	@$(call WITH_DOTENV,FIRMWARE_BIN='$(FIRMWARE_BIN)' bash scripts/upgrade-control-board.sh)

# Push process-library matched to device product.ini model (host helper).
# Device-side: app watches /run/hmi/upgrade-process-library.cmd and force-imports.
upgrade-process-library:
	@chmod +x scripts/upgrade-process-library.sh
	@$(call WITH_DOTENV,PACKAGE_DIR='$(PACKAGE_DIR)' bash scripts/upgrade-process-library.sh)

# Clear process-library DB via HMI watcher + force bundled re-import (no restart).
reset-process-library:
	@chmod +x scripts/reset-process-library.sh
	@$(call WITH_DOTENV,bash scripts/reset-process-library.sh)

# Demo warn dialog on device (writes /run/hmi/demo-alarm.cmd; HMI must be running).
alarm:
	@chmod +x scripts/trigger-alarm.sh
	@$(call WITH_DOTENV,CODE='$(CODE)' bash scripts/trigger-alarm.sh trigger)

# Clear episode restrictions only; visible warn popup stays open.
alarm-clean:
	@chmod +x scripts/trigger-alarm.sh
	@$(call WITH_DOTENV,bash scripts/trigger-alarm.sh clean)

# Upload stain demo JPG + run offline RKNN infer on /run/hmi/ai/cmd.sock (HMI/AI daemon running).
smoke-ai:
	@chmod +x scripts/smoke-ai-offline-infer.sh
	@$(call WITH_DOTENV,SMOKE_AI_IMAGE='$(SMOKE_AI_IMAGE)' bash scripts/smoke-ai-offline-infer.sh)

# Upsert one or more UPPERCASE_KEY=value into /var/lib/hal/product.ini (SSH).
set-prop:
	@chmod +x scripts/set-product-prop.sh
	@$(call WITH_DOTENV,bash scripts/set-product-prop.sh $(MAKEOVERRIDES))

# Remove one UPPERCASE key from product.ini (e.g. make del-prop CAMERA_IP).
del-prop:
	@chmod +x scripts/del-product-prop.sh
	@$(call WITH_DOTENV,bash scripts/del-product-prop.sh $(filter-out del-prop,$(MAKECMDGOALS)) $(MAKEOVERRIDES))

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

# Swallow extra goals for del-prop (e.g. make del-prop CAMERA_IP).
ifneq (,$(filter del-prop,$(MAKECMDGOALS)))
%:
	@:
endif
