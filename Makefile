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

# Flutter project under app/ (build-app / push-app / build-rootfs). Default product HMI.
APP ?= lws_hmi

# USB flash / adb / remote SSH (override when multiple devices connected)
SN ?=
CHIP_ID ?=
SERIAL ?=
IP ?=
IMAGE ?=
FLASH_ENV = SN='$(SN)' CHIP_ID='$(CHIP_ID)' SERIAL='$(SERIAL)' IP='$(IP)' UPDATE_IMG='$(IMAGE)'

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

.PHONY: help setup apply-overlay clean-overlay docker-image docker-volume-init docker-volume-sync docker-volume-pull docker-export-artifacts docker-volume-status sdk-shell shell logs lunch show-config build build-kernel build-uboot fetch-uboot build-rootfs prepare-rootfs build-img build-oem build-emulator emulator emulator-stop setup-emulator-qemu build-boot-logo build-app prepare-app-assets build-debug-app debug-setup prepare-debug-host debug-app build-reboot-rockusb-loader check-prebuilt check-linux-sdk trim-linux-sdk squash-linux-sdk-platform clean-buildroot-output migrate-buildroot-output fix-buildroot-host-rpaths export-prebuilt export-prebuilt-runtime build-prebuilt export-buildroot-toolchain build-runtime-deps rebuild-runtime-deps build-deps rebuild-deps build-flutter-engine rebuild-flutter-engine fetch-flutter-engine refetch-flutter-engine cache-publish-flutter-engine rebuild-flutter-embedded-linux rebuild-flutter-embedded-linux fetch-flutter-sdk refetch-flutter-sdk build-dev-deps rebuild-dev-deps fetch-opencv refetch-opencv fetch-opencv-ximgproc fetch-rknn-toolkit refetch-rknn-toolkit fetch-rknn-rt refetch-rknn-rt fetch-btop refetch-btop fetch-emulator-swgl build-umtprd rebuild-umtprd build-extract-video-frame rebuild-extract-video-frame build-secrets-seal rebuild-secrets-seal build-mediamtx rebuild-mediamtx build-opencv rebuild-opencv build-ai rebuild-ai build-gstreamer rebuild-gstreamer build-platform-packages rebuild-platform-packages rebuild-prebuilt extract-linux-sdk pull-display-params audit devices connect disconnect push-app upgrade-control-board upgrade-process-library reset-process-library set-prop del-prop write-identity ota-release-keys ota-package upgrade reboot reboot-loader loader flash flash-android watch-maskrom setup-usb-ssh test-debug-app alarm alarm-clean smoke-ai l10n l10n-sync l10n-gen l10n-verify version version-bump check-typography

# Run a command with `.env` exported (if present).
# Usage: $(call WITH_DOTENV,<command>)
define WITH_DOTENV
bash -c 'set -euo pipefail; \
  __ENV_SN="$${SN-}"; __ENV_CHIP_ID="$${CHIP_ID-}"; __ENV_SERIAL="$${SERIAL-}"; __ENV_IP="$${IP-}"; __ENV_IMAGE="$${IMAGE-}"; \
  __ENV_APP="$${APP-}"; \
  __ENV_OEM_ONLY="$${OEM_ONLY-}"; \
  __ENV_UPGRADE_TRANSPORT="$${UPGRADE_TRANSPORT-}"; \
  if [[ -n "$${OEM_IMG+x}" ]]; then __ENV_OEM_IMG_SET=1; __ENV_OEM_IMG="$${OEM_IMG-}"; else __ENV_OEM_IMG_SET=0; fi; \
  if [[ -n "$${UPGRADE_PACKAGE+x}" ]]; then __ENV_UPGRADE_PACKAGE_SET=1; __ENV_UPGRADE_PACKAGE="$${UPGRADE_PACKAGE-}"; else __ENV_UPGRADE_PACKAGE_SET=0; fi; \
  __ENV_OTA_SIGNING_KEY="$${OTA_SIGNING_KEY-}"; \
  __ENV_REQUIRE_OTA_SIG="$${REQUIRE_OTA_SIG-}"; \
  __ENV_FLUTTER_SDK="$${FLUTTER_SDK-}"; __ENV_BUILD_JOBS="$${BUILD_JOBS-}"; \
  __ENV_BUILD_BIND_MOUNT="$${BUILD_BIND_MOUNT-}"; \
  set -a; [[ -f .env ]] && source .env; set +a; \
  [[ -n "$$__ENV_SN" ]] && export SN="$$__ENV_SN"; \
  [[ -n "$$__ENV_CHIP_ID" ]] && export CHIP_ID="$$__ENV_CHIP_ID"; \
  [[ -n "$$__ENV_SERIAL" ]] && export SERIAL="$$__ENV_SERIAL"; \
  [[ -n "$$__ENV_IP" ]] && export IP="$$__ENV_IP"; \
  [[ -n "$$__ENV_IMAGE" ]] && export IMAGE="$$__ENV_IMAGE"; \
  [[ -n "$$__ENV_APP" ]] && export APP="$$__ENV_APP"; \
  [[ -n "$$__ENV_OEM_ONLY" ]] && export OEM_ONLY="$$__ENV_OEM_ONLY"; \
  [[ -n "$$__ENV_UPGRADE_TRANSPORT" ]] && export UPGRADE_TRANSPORT="$$__ENV_UPGRADE_TRANSPORT"; \
  [[ "$$__ENV_OEM_IMG_SET" == 1 ]] && export OEM_IMG="$$__ENV_OEM_IMG"; \
  [[ "$$__ENV_UPGRADE_PACKAGE_SET" == 1 ]] && export UPGRADE_PACKAGE="$$__ENV_UPGRADE_PACKAGE"; \
  [[ -n "$$__ENV_OTA_SIGNING_KEY" ]] && export OTA_SIGNING_KEY="$$__ENV_OTA_SIGNING_KEY"; \
  [[ -n "$$__ENV_REQUIRE_OTA_SIG" ]] && export REQUIRE_OTA_SIG="$$__ENV_REQUIRE_OTA_SIG"; \
  [[ -n "$$__ENV_FLUTTER_SDK" ]] && export FLUTTER_SDK="$$__ENV_FLUTTER_SDK"; \
  [[ -n "$$__ENV_BUILD_JOBS" ]] && export BUILD_JOBS="$$__ENV_BUILD_JOBS"; \
  [[ -n "$$__ENV_BUILD_BIND_MOUNT" ]] && export BUILD_BIND_MOUNT="$$__ENV_BUILD_BIND_MOUNT"; \
  $(1)'
endef

help:
	@echo "lws-hmi — Buildroot + ynh960 (Linux: native build; macOS: Docker linux/amd64)"
	@echo ""
	@echo "Full per-target docs (usage / when / env vars): docs/make-commands.md"
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
	@echo "  make docker-export-artifacts # manual/legacy: SCOPE=boot|rootfs|update|firmware → output/firmware/ only"
	@echo "  make docker-volume-pull    # legacy alias: same as SCOPE=firmware export (no linux-sdk/output/ mirror)"
	@echo "  make docker-volume-status  # show volume mount and SDK tree status"
	@echo ""
	@echo "Build (scope = active #include in overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig):"
	@echo "  make build                 # full image: prebuilt → overlay → lunch → logo → app → kernel → rootfs → img"
	@echo "  make lunch                 # select ynh960 + lws_hmi Buildroot profile in SDK"
	@echo "  make show-config           # print RK_* lines from output/.config"
	@echo "  make build-boot-logo       # board/logo → logo.bmp (kernel FIT splash)"
	@echo "  make build-app             # release AOT → fs-overlay (*_hmi→/opt/hmi; else /opt/<APP>)"
	@echo "  make prepare-app-assets    # prune/convert process-library + firmware → assets/.generated/"
	@echo "  make build-debug-app       # debug app bundle → .cache (make debug-app / IDE; rarely run alone)"
	@echo "  make version               # print app/<APP> pubspec versionName+build (default APP=lws_hmi)"
	@echo "  make version-bump          # bump pubspec (+ app_version.dart); VERSION=x.y.z required; APP= optional"
	@echo "  make l10n                  # sync child ARBs + flutter gen-l10n (app/lws_hmi)"
	@echo "  make l10n-sync             # regenerate en_US/zh_CN/zh_TW child ARBs only"
	@echo "  make l10n-gen              # flutter gen-l10n only"
	@echo "  APP=…                     # app/ dir; *_hmi→/opt/hmi; rootfs/factory under output/firmware/<APP>/ (default lws_hmi)"
	@echo "  make l10n-verify           # fail if ARBs / AppLocalizations drift"
	@echo "  make check-typography      # fail bare fontSize:N / business AppTypography.*Size"
	@echo "  make build-kernel          # dual multi-conf FIT → boot.img + boot_b.img (+ bare Image)"
	@echo "  make build-rootfs          # rootfs → output/firmware/<APP>/rootfs.img (default APP=lws_hmi)"
	@echo "  make prepare-rootfs        # ensure Buildroot stack → Weston (no rootfs.img pack)"
	@echo "  make build-oem             # pack oem/out/<oem_id>/oem.img (FACTORY_SKU / OEM_ID)"
	@echo "  make build-img             # pack output/firmware/<APP>/<sku>/factory.img; needs build-oem"
	@echo "  make sdk-shell             # interactive shell in linux-sdk (native Linux or macOS Docker)"
	@echo "  See docs/build-optimization.md"
	@echo ""
	@echo "Emulator (P3.2 — same Image+rootfs + sim_virt OEM; docs/p32-emulator.md):"
	@echo "  make setup-emulator-qemu   # once (macOS): install qemu-virgl (host VirGL / ANGLE→Metal)"
	@echo "  make fetch-emulator-swgl   # once: guest Mesa virtio_gpu → prebuilt/ (9p; FORCE=1 to refetch)"
	@echo "  make build-emulator        # assemble Image+rootfs+sim_virt oem → output/firmware/emulator/ (grows emulator rootfs copy to 1536M)"
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
	@echo "  make build-flutter-engine  # runtime: release engine → prebuilt/…/arm64-release (also: FLUTTER_ENGINE_RUNTIME_MODE=debug)"
	@echo "  make fetch-flutter-engine  # runtime: engine sources → .cache/flutter-engine/"
	@echo "  make build-flutter-embedded-linux  # Weston image: eLinux Wayland client → prebuilt/"
	@echo "  make build-mediamtx        # runtime: mediamtx arm64 → prebuilt/ (App /opt/hmi)"
	@echo "  make build-opencv          # runtime: OpenCV aarch64 → prebuilt/opencv (for lws_ai)"
	@echo "  make build-ai              # runtime: lws_ai_daemon → prebuilt/ai (App /opt/hmi)"
	@echo "  make build-umtprd          # runtime: umtprd aarch64 → prebuilt/ + fs-overlay (MTP)"
	@echo "  make build-extract-video-frame  # runtime: MP4→JPEG helper → prebuilt/ + libexec (GStreamer)"
	@echo "  make build-secrets-seal    # runtime: OP-TEE seal TA + secrets-seal-ca → prebuilt/ + overlay"
	@echo "  make fetch-btop            # runtime: btop aarch64 musl → prebuilt/ + fs-overlay"
	@echo "  make fetch-opencv          # runtime: OpenCV sources → .cache/opencv/"
	@echo "  make fetch-opencv-ximgproc # runtime: ximgproc EdgeDrawing → .cache/"
	@echo "  make fetch-rknn-rt         # runtime: aarch64 librknnrt → prebuilt/rknn-rt/"
	@echo "  make fetch-flutter-sdk     # dev: host Flutter SDK → DEST= (default flutter-sdk/; FORCE=1 refetch)"
	@echo "  make fetch-rknn-toolkit    # dev: RKNN-Toolkit2 + torch (ONNX→RKNN on x86)"
	@echo "  make export-prebuilt       # re-export flutter + runtime (usually build-* already did)"
	@echo "  rebuild-*                  # FORCE=1 refresh (e.g. make rebuild-runtime-deps)"
	@echo ""
	@echo "Debug (device / host — USB-SSH, remote SSH, Flutter, serial):"
	@echo "  make setup-usb-ssh         # host ECM/RNDIS IP + sshpass doctor (Win: Admin; macOS may sudo)"
	@echo "  make prepare-debug-host    # USB ECM or registered SSH reachability for debug-app/IDE"
	@echo "  make connect <ip>          # register remote SSH board (MODE=SSH; host:port OK for EMU)"
	@echo "  make disconnect <ip>       # remove registered remote SSH board"
	@echo "  make devices               # RockUSB + USB-SSH + SSH + EMU (auto-probe QEMU :2222)"
	@echo "  make shell                 # interactive device shell (USB-SSH or SSH)"
	@echo "  make logs                  # live journal; UNIT/TAG/GREP/PRIORITY/KERNEL_ONLY filters"
	@echo "  make push-app              # scp APP over SSH (*_hmi→/opt/hmi+hmi restart; else /opt/<id>)"
	@echo "  make upgrade-control-board # push latest control-board bin and trigger upgrade (no version gate)"
	@echo "  make upgrade-process-library # push process-library for device model; force import (no version gate)"
	@echo "  make reset-process-library # clear process-library DB via HMI watcher; re-import bundled (no restart)"
	@echo "  make set-prop KEY=val ...  # upsert properties.ini tunables (not brand/model/sn); restart hmi"
	@echo "  make del-prop KEY          # remove one tunable key (not brand/model/sn); restart hmi if changed"
	@echo "  make write-identity …      # Vendor Storage BRAND/MODEL/PRODUCT_SN (FORCE=1 overwrite); restart hmi"
	@echo "  make alarm CODE=L001       # demo warn dialog on device (USB-SSH/SSH; HMI running)"
	@echo "  make alarm-clean           # clear alarm restrictions; keep visible warn popup"
	@echo "  make smoke-ai              # upload stain demo JPG; offline RKNN infer via AI daemon sock"
	@echo "  make upgrade               # ota-package + host HTTP serve; device downloads tar.gz+.sig → verify/apply; or RockUSB di; OEM_ONLY=1"
	@echo "  make ota-package           # pack imgs → output/firmware/<APP>/ota-package.tar.gz [+.sig if OTA_SIGNING_KEY]"
	@echo "  make ota-release-keys          # release Ed25519 keypair → keys/ota/ + overlay /etc/ota/ed25519.pub"
	@echo "  make debug-setup           # Flutter Custom Device + IDE doctor (one-time host)"
	@echo "  make debug-app             # flutter run -d lws-hmi (USB-SSH or SSH)"
	@echo "  make serial-console        # MODE=TTL|RS485|RS232 (default TTL); BAUD=; LOG_FILE= (hex)"
	@echo "                             # TTL=miniterm @1500000 quit Ctrl+]; RS485/RS232=hex+TX bar @115200 quit Esc/:q"
	@echo "  make serial-ports          # list host /dev/cu.* serial ports"
	@echo "  make serial-sniff          # auto-detect baud while power-cycling board"
	@echo ""
	@echo "USB Flash (macOS / Linux x86_64 / Windows Git Bash):"
	@echo "  make audit                 # pre-flight before make flash"
	@echo "  make reboot                # Linux → USB-SSH/SSH sysrq + unregister; Android → adb"
	@echo "  make reboot-loader         # Linux USB-SSH → RockUSB + unregister; Android → adb"
	@echo "  make flash                 # uf factory.img (APP+FACTORY_SKU); IMAGE= override; Maskrom ul"
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
	@echo "  BUILD_JOBS=8               # parallel jobs (default 8; lower if Docker OOM)"
	@echo "  BUILD_BIND_MOUNT=1         # macOS only: bind-mount SDK instead of Docker volume"
	@echo "  NAS_CACHE_ROOT=...         # NAS mount for large .cache artifacts (see .env.example)"
	@echo "  NAS_READ_ONLY=0|1          # 1 = never write back to NAS (default 0)"
	@echo "  SN=<sn>                    # select device by SN (flash / USB-SSH / SSH)"
	@echo "  PRODUCT_SN=<sn>            # write-identity product serial (not selection SN=)"
	@echo "  FORCE=1                    # write-identity: overwrite non-empty Vendor Storage SN"
	@echo "  IP=<addr>                  # registered SSH only (not USB-SSH); make connect first"
	@echo "  UPGRADE_TRANSPORT=auto|ssh|rockusb  # make upgrade transport (default auto)"
	@echo "  IMAGE=<path>               # firmware image for make flash"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)"
	@echo "  DOCKER_PLATFORM=$(DOCKER_PLATFORM)"
	@echo ""
	@echo "Notes:"
	@echo "  - Daily A/B: make build-kernel and/or build-rootfs then make upgrade (packages tar.gz, staged apply; no .sig required)."
	@echo "  - Loader/Maskrom: make reboot-loader (or Maskrom) then make upgrade (di OTA images; not factory uf)."
	@echo "  - OEM-only (helpers/profile): make build-oem && OEM_ONLY=1 make upgrade"
	@echo "  - Cloud/publish + SSH upgrade: OTA_SIGNING_KEY=… REQUIRE_OTA_SIG=1 make ota-package (archive + .sig); make upgrade serves via host HTTP."
	@echo "  - macOS Docker: each build-* publishes matching imgs to output/firmware/ only (no host linux-sdk/output/ mirror)."
	@echo "  - Factory: make build-oem then build-img → output/firmware/<APP>/<sku>/factory.img; make flash."
	@echo "  - APP= selects HMI product: overlay /opt/hmi + host rootfs/factory under output/firmware/<APP>/."
	@echo "  - FACTORY_SKU=ynh960-p800 (default) → UBOOT_ID/OEM_ID via board/factory-skus.tsv; override either only when needed."
	@echo "  - Emulator: README Make commands → P3.2 emulator (setup → deps → kernel/rootfs → setup-emulator-qemu → fetch-emulator-swgl → build-emulator → emulator)."
	@echo "  - Set VAR=value before the command, or add a '.env' in the repo root (see .env.example)."
	@echo "  - docs/make-commands.md — full catalog of targets, parameters, and when to use them."

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
# Ensures APP (default lws_hmi) + auto factory_test when app/factory_test exists.
build-rootfs: prepare-rootfs
	@APP='$(APP)' bash scripts/ensure-rootfs-apps.sh
	@bash scripts/apply-overlay.sh
	@bash scripts/docker-run.sh ./build.sh rootfs
	@bash scripts/lws-hmi-rootfs-postprocess.sh
	@bash scripts/verify-rootfs-overlay.sh
	@APP='$(APP)' bash scripts/docker-export-artifacts.sh rootfs

# Stack ensure only (check-prebuilt + overlay + Mali/embedder). Idempotent.
prepare-rootfs:
	@bash scripts/prepare-rootfs-stack.sh weston

build-oem:
	@bash scripts/build-oem.sh

build-img:
	@APP='$(APP)' bash scripts/build-img.sh

# --- Emulator (P3.2) ---

setup-emulator-qemu:
	@bash scripts/setup-emulator-qemu.sh

fetch-emulator-swgl:
	@bash scripts/fetch-emulator-swgl.sh

build-emulator:
	@APP='$(APP)' bash scripts/build-emulator.sh

emulator:
	@bash scripts/run-emulator.sh start

emulator-stop:
	@bash scripts/run-emulator.sh stop

build-boot-logo:
	@bash scripts/build-boot-logo.sh

build-app:
	@APP='$(APP)' bash scripts/build-app.sh
	@bash scripts/apply-overlay.sh

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

check-typography:
	@bash scripts/flutter/check_no_bare_font_size.sh

build-debug-app:
	@bash scripts/build-debug-app.sh

debug-setup:
	@bash scripts/debug-setup.sh

prepare-debug-host:
	@$(call WITH_DOTENV,bash scripts/prepare-debug-host.sh)

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
	@FLUTTER_ENGINE_RUNTIME_MODE='$(FLUTTER_ENGINE_RUNTIME_MODE)' \
		FORCE='$(FORCE)' \
		FLUTTER_ENGINE_VERSION='$(FLUTTER_ENGINE_VERSION)' \
		bash scripts/build-flutter-engine.sh

rebuild-flutter-engine:
	@FLUTTER_ENGINE_RUNTIME_MODE='$(FLUTTER_ENGINE_RUNTIME_MODE)' \
		FORCE=1 \
		FLUTTER_ENGINE_VERSION='$(FLUTTER_ENGINE_VERSION)' \
		bash scripts/build-flutter-engine.sh

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
	@DEST='$(DEST)' FORCE='$(FORCE)' bash scripts/fetch-flutter-sdk.sh

refetch-flutter-sdk:
	@DEST='$(DEST)' FORCE=1 bash scripts/fetch-flutter-sdk.sh

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

build-extract-video-frame:
	@bash scripts/build-extract-video-frame.sh

rebuild-extract-video-frame:
	@FORCE=1 bash scripts/build-extract-video-frame.sh

build-secrets-seal:
	@bash scripts/build-secrets-seal.sh

rebuild-secrets-seal:
	@FORCE=1 bash scripts/build-secrets-seal.sh

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

setup-usb-ssh:
	@$(call WITH_DOTENV,bash scripts/usb-ssh-host-setup.sh)

push-app:
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/push-app.sh)

# Push latest bundled control-board firmware (host helper).
# Device-side: app watches /run/hmi/upgrade-control-board.cmd and runs upgrade
# without confirm / without version gate.
upgrade-control-board:
	@$(call WITH_DOTENV,FIRMWARE_BIN='$(FIRMWARE_BIN)' bash scripts/upgrade-control-board.sh)

# Push process-library matched to device Vendor Storage model (host helper).
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

# Remove one UPPERCASE key from properties.ini (e.g. make del-prop CAMERA_IP).
del-prop:
	@chmod +x scripts/del-product-prop.sh
	@$(call WITH_DOTENV,bash scripts/del-product-prop.sh $(filter-out del-prop,$(MAKECMDGOALS)) $(MAKEOVERRIDES))

# Write brand/model/product SN into Vendor Storage (SSH). Selection: SN=/IP=.
# Payload: BRAND= MODEL= PRODUCT_SN=. FORCE=1 to overwrite SN.
# Pass via MAKEOVERRIDES only — do NOT wrap BRAND='$(BRAND)' inside WITH_DOTENV's
# bash -c '…' (single quotes break on MODEL='L1 Pro' and silently no-op).
write-identity:
	@chmod +x scripts/write-identity.sh
	@$(call WITH_DOTENV,bash scripts/write-identity.sh $(MAKEOVERRIDES))

# Print selected APP pubspec versionName+build (host-only; default APP=lws_hmi).
version:
	@chmod +x scripts/app-version.sh
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/app-version.sh print)

# Bump selected APP pubspec (+ optional lib/app_version.dart). VERSION=x.y.z[+build] required.
version-bump:
	@test -n "$(VERSION)" || (echo 'ERROR: VERSION is required (e.g. make version-bump VERSION=1.0.40)' >&2; exit 1)
	@chmod +x scripts/app-version.sh
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/app-version.sh bump '$(VERSION)')

# Release Ed25519 keypair (private under keys/ota/; pubkey → overlay /etc/ota/).
ota-release-keys:
	@chmod +x scripts/ota-release-keys.sh
	@bash scripts/ota-release-keys.sh

# Whole-device OTA tar.gz (+ optional .sig). Publish/CI: REQUIRE_OTA_SIG=1 OTA_SIGNING_KEY=…
ota-package:
	@chmod +x scripts/ota-package.sh scripts/ota-sign.sh
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/ota-package.sh)

# SSH: package (unless UPGRADE_PACKAGE=) → host HTTP serve tar.gz+.sig → device download+verify+staged apply.
# RockUSB: still di loose images (unsigned; or package members via upgrade-package-env).
upgrade:
	@chmod +x scripts/upgrade-remote.sh scripts/ota-package.sh scripts/ota-sign.sh scripts/ota-http-serve.py
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/upgrade-remote.sh)

reboot:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh reboot)

reboot-loader:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh reboot-loader)

loader:
	@$(call WITH_DOTENV,$(FLASH_ENV) bash scripts/flash-usb.sh loader)

flash:
	@$(call WITH_DOTENV,$(FLASH_ENV) APP='$(APP)' bash scripts/flash-usb.sh flash)

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
