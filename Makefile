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
export BOARD CHIP DEFCONFIG

# Flutter project under app/ (build-app / upgrade-app / build-rootfs). Default product HMI.
APP ?= lws_hmi

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

.PHONY: help setup apply-overlay clean-overlay docker-image docker-volume-init docker-volume-sync docker-volume-pull docker-export-artifacts docker-volume-status sdk-shell shell logs lunch show-config build build-kernel build-kernel-a build-kernel-b build-uboot fetch-uboot build-rootfs prepare-rootfs build-img build-oem build-emulator emulator emulator-stop setup-emulator-qemu build-boot-logo build-app prepare-app-assets build-debug-app debug-setup prepare-debug-host debug-app build-libexec-binaries rebuild-libexec-binaries build-hmi-capture screenshot record-screen check-prebuilt check-linux-sdk trim-linux-sdk squash-linux-sdk-platform clean-buildroot-output migrate-buildroot-output fix-buildroot-host-rpaths export-prebuilt export-prebuilt-runtime build-prebuilt export-buildroot-toolchain build-runtime-deps rebuild-runtime-deps build-deps rebuild-deps build-flutter-engine rebuild-flutter-engine fetch-flutter-engine refetch-flutter-engine cache-publish-flutter-engine rebuild-flutter-embedded-linux rebuild-flutter-embedded-linux fetch-flutter-sdk refetch-flutter-sdk build-dev-deps rebuild-dev-deps fetch-opencv refetch-opencv fetch-opencv-ximgproc fetch-rknn-toolkit refetch-rknn-toolkit fetch-rknn-rt refetch-rknn-rt fetch-btop refetch-btop fetch-emulator-swgl build-libexec-binaries rebuild-libexec-binaries build-umtprd rebuild-umtprd build-secrets-seal rebuild-secrets-seal build-mediamtx rebuild-mediamtx build-opencv rebuild-opencv build-ai rebuild-ai build-gstreamer rebuild-gstreamer build-platform-packages rebuild-platform-packages rebuild-prebuilt extract-linux-sdk pull-display-params devices connect disconnect push-app upgrade-app pack-app upgrade-control-board upgrade-camera upgrade-process-library reset-process-library migrate-secrets migrate-seal-kek set-prop del-prop write-identity login register-device publish publish-only publish-app publish-app-only publish-control-board-firmware publish-control-board-firmware-only publish-camera-firmware publish-camera-firmware-only sign-keys pack-ota upgrade reboot reboot-loader loader flash flash-android watch-maskrom setup-usb-ssh ssh-keys test-debug-app alarm alarm-clean smoke-ai audit audit-cve fetch-cve-db l10n l10n-sync l10n-gen l10n-verify version version-bump check-typography

# Run a command with `.env` exported (if present).
# Usage: $(call WITH_DOTENV,<command>)
define WITH_DOTENV
bash -c 'set -euo pipefail; \
  __ENV_SN="$${SN-}"; __ENV_CHIPID="$${CHIPID-}"; __ENV_SERIAL="$${SERIAL-}"; __ENV_IP="$${IP-}"; __ENV_IMAGE="$${IMAGE-}"; \
  __ENV_APP="$${APP-}"; \
  __ENV_OEM_ONLY="$${OEM_ONLY-}"; \
  __ENV_UPGRADE_TRANSPORT="$${UPGRADE_TRANSPORT-}"; \
  if [[ -n "$${OEM_IMG+x}" ]]; then __ENV_OEM_IMG_SET=1; __ENV_OEM_IMG="$${OEM_IMG-}"; else __ENV_OEM_IMG_SET=0; fi; \
  if [[ -n "$${UPGRADE_PACKAGE+x}" ]]; then __ENV_UPGRADE_PACKAGE_SET=1; __ENV_UPGRADE_PACKAGE="$${UPGRADE_PACKAGE-}"; else __ENV_UPGRADE_PACKAGE_SET=0; fi; \
  __ENV_OTA_SIGNING_KEY="$${OTA_SIGNING_KEY-}"; \
  __ENV_REQUIRE_OTA_SIG="$${REQUIRE_OTA_SIG-}"; \
  __ENV_CLOUD_API_BASE="$${CLOUD_API_BASE-}"; \
  __ENV_CLOUD_ACCESS_TOKEN="$${CLOUD_ACCESS_TOKEN-}"; \
  __ENV_CLOUD_ACCOUNT="$${CLOUD_ACCOUNT-}"; \
  __ENV_CLOUD_PASSWORD="$${CLOUD_PASSWORD-}"; \
  __ENV_PUBLISH_API_TOKEN="$${PUBLISH_API_TOKEN-}"; \
  __ENV_RELEASE="$${RELEASE-}"; \
  __ENV_PUBLISH_ARTIFACT="$${PUBLISH_ARTIFACT-}"; \
  __ENV_FLUTTER_SDK="$${FLUTTER_SDK-}"; __ENV_BUILD_JOBS="$${BUILD_JOBS-}"; \
  __ENV_BUILD_BIND_MOUNT="$${BUILD_BIND_MOUNT-}"; \
  set -a; [[ -f .env ]] && source .env; set +a; \
  [[ -n "$$__ENV_SN" ]] && export SN="$$__ENV_SN"; \
  [[ -n "$$__ENV_CHIPID" ]] && export CHIPID="$$__ENV_CHIPID"; \
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
  [[ -n "$$__ENV_CLOUD_API_BASE" ]] && export CLOUD_API_BASE="$$__ENV_CLOUD_API_BASE"; \
  [[ -n "$$__ENV_CLOUD_ACCESS_TOKEN" ]] && export CLOUD_ACCESS_TOKEN="$$__ENV_CLOUD_ACCESS_TOKEN"; \
  [[ -n "$$__ENV_CLOUD_ACCOUNT" ]] && export CLOUD_ACCOUNT="$$__ENV_CLOUD_ACCOUNT"; \
  [[ -n "$$__ENV_CLOUD_PASSWORD" ]] && export CLOUD_PASSWORD="$$__ENV_CLOUD_PASSWORD"; \
  [[ -n "$$__ENV_PUBLISH_API_TOKEN" ]] && export PUBLISH_API_TOKEN="$$__ENV_PUBLISH_API_TOKEN"; \
  [[ -n "$$__ENV_RELEASE" ]] && export RELEASE="$$__ENV_RELEASE"; \
  [[ -n "$$__ENV_PUBLISH_ARTIFACT" ]] && export PUBLISH_ARTIFACT="$$__ENV_PUBLISH_ARTIFACT"; \
  [[ -n "$$__ENV_FLUTTER_SDK" ]] && export FLUTTER_SDK="$$__ENV_FLUTTER_SDK"; \
  [[ -n "$$__ENV_BUILD_JOBS" ]] && export BUILD_JOBS="$$__ENV_BUILD_JOBS"; \
  [[ -n "$$__ENV_BUILD_BIND_MOUNT" ]] && export BUILD_BIND_MOUNT="$$__ENV_BUILD_BIND_MOUNT"; \
  $(1)'
endef

help:
	@echo "lws-hmi — generic embedded OS + Flutter HMI (Linux: native; macOS: Docker linux/amd64)"
	@echo ""
	@echo "Setup:"
	@echo "  make setup                 # apply-overlay (+ Docker image on macOS)"
	@echo "  make apply-overlay         # patch SDK (required before any build that consumes overlay)"
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
	@echo "  make build                 # full image: prebuilt → overlay → lunch → logo → ai → app → kernel → rootfs → img"
	@echo "  make lunch                 # once: init SDK platform profile (not product/board pick)"
	@echo "  make show-config           # print RK_* lines from output/.config"
	@echo "  make build-boot-logo       # board/logo → logo.bmp (kernel FIT splash)"
	@echo "  make build-ai              # incremental lws_ai_daemon → prebuilt/ai (daily; rebuild-ai / FORCE=1 wipe cmake)"
	@echo "  make prepare-app-assets    # prune/convert process-library + firmware → assets/.generated/"
	@echo "  make build-app             # release AOT → app/<APP>/build/bundle/release (not SDK rootfs)"
	@echo "  make build-debug-app       # debug app bundle → .cache (make debug-app / IDE; rarely run alone)"
	@echo "  make build-kernel          # one Image + multi-DTB FIT → boot.img + boot_b.img (docs/make-commands 构建模型)"
	@echo "  make build-kernel-a        # slot A FIT only (rootfs_a → boot.img)"
	@echo "  make build-kernel-b        # slot B FIT only (rootfs_b → boot_b.img)"
	@echo "  make build-rootfs          # rootfs → output/firmware/<APP>/rootfs.img (needs prior apply-overlay if overlay changed)"
	@echo "  make prepare-rootfs        # check-prebuilt + Mali/embedder stack (no apply-overlay; no rootfs.img)"
	@echo "  make build-oem             # pack oem/out/<oem_id>/oem.img (FACTORY_SKU / OEM_ID)"
	@echo "  make build-img             # pack output/firmware/<APP>/<sku>/factory.img; needs build-oem"
	@echo "  make version               # print OS Version (default); APP=<id> → Flutter pubspec name+build"
	@echo "  make version-bump          # bump OS Version; APP= + VERSION= → Flutter; VERSION=x.y.z required"
	@echo "  make l10n                  # sync child ARBs + flutter gen-l10n (app/lws_hmi)"
	@echo "  make l10n-sync             # regenerate en_US/zh_CN/zh_TW child ARBs only"
	@echo "  make l10n-gen              # flutter gen-l10n only"
	@echo "  APP=…                     # app/ dir; *_hmi→/opt/hmi; os_settings→/opt/os_settings; rootfs/factory under output/firmware/<APP>/ (default lws_hmi)"
	@echo "  make l10n-verify           # fail if ARBs / AppLocalizations drift"
	@echo "  make check-typography      # fail bare fontSize:N / business AppTypography.*Size"
	@echo "  make sdk-shell             # interactive shell in linux-sdk (native Linux or macOS Docker)"
	@echo "  See docs/build-optimization.md"
	@echo ""
	@echo "Debug (device / host — USB-SSH, remote SSH, Flutter, serial):"
	@echo "  make setup-usb-ssh         # host ECM/RNDIS IP + team SSH key check (Win: Admin; macOS may sudo)"
	@echo "  make ssh-keys              # team id_ed25519 + sync overlay authorized_keys (internal distribution)"
	@echo "  make connect <ip>          # register remote SSH board (MODE=SSH; host:port OK for EMU)"
	@echo "  make disconnect <ip>       # remove registered remote SSH board"
	@echo "  make devices               # RockUSB + USB-SSH + SSH + EMU (auto-probe QEMU :2222)"
	@echo "  make shell                 # interactive device shell (USB-SSH or SSH)"
	@echo "  make logs                  # live journal; UNIT/TAG/GREP/PRIORITY/KERNEL filters"
	@echo "  make write-identity …      # Vendor Storage BRAND/MODEL/PRODUCT_SN (FORCE=1 overwrite); restart hmi"
	@echo "  make reset-process-library # clear process-library DB via HMI watcher; re-import bundled (no restart)"
	@echo "  make migrate-secrets       # re-seal software Wi‑Fi vault + cloud key → OP-TEE (SCOPE=all|wifi|cloud)"
	@echo "  make migrate-seal-kek      # HUK-wrap OP-TEE seal KEK ↔ Vendor Storage ID 23 (cloud seed unchanged)"
	@echo "  make set-prop KEY=val ...  # upsert product.ini tunables (not brand/model/sn); restart hmi"
	@echo "  make del-prop KEY          # remove one tunable key (not brand/model/sn); restart hmi if changed"
	@echo "  make alarm CODE=L001       # demo warn dialog on device (USB-SSH/SSH; HMI running)"
	@echo "  make alarm-clean           # clear alarm restrictions; keep visible warn popup"
	@echo "  make screenshot            # present-hook still (HMI or OS Settings) → output/screenshot/ (ROTATE= Q=)"
	@echo "  make record-screen         # present-hook record (either seat) → output/record-screen/ (FPS= SCALE= DURATION= AUDIO= AUDIO_DEV=)"
	@echo "  make smoke-ai              # upload stain demo JPG; offline RKNN infer via AI daemon sock"
	@echo "  make prepare-debug-host    # USB ECM or registered SSH reachability for debug-app/IDE"
	@echo "  make debug-setup           # Flutter Custom Device + IDE doctor (one-time host)"
	@echo "  make debug-app             # flutter run -d lws-hmi (USB-SSH or SSH)"
	@echo "  make push-app              # debug: SSH push APP → /opt/* + restart its unit (*_hmi→hmi; os_settings→os-settings)"
	@echo "  make serial-console        # MODE=TTL|RS485|RS232 (default TTL); BAUD=; LOG_FILE= (hex)"
	@echo "                             # TTL=miniterm (usbmodem/wch/SLAB@1.5M, usbserial@115200); RS485/RS232=hex+TX @115200"
	@echo "  make serial-ports          # list host /dev/cu.* serial ports"
	@echo "  make serial-sniff          # auto-detect baud while power-cycling board"
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
	@echo "  make build-umtprd          # runtime: umtprd aarch64 → prebuilt/ + fs-overlay (MTP)"
	@echo "  make build-libexec-binaries     # libexec C binaries → prebuilt/ (reboot-loader, extract-video-frame, hmi-capture, emulator touch bridge)"
	@echo "  make build-secrets-seal    # OP-TEE seal TA + CA (signs with keys/oem/vendor_ta.pem; TA_SIGN_KEY= overrides)"
	@echo "  make fetch-btop            # runtime: btop aarch64 musl → prebuilt/ + fs-overlay"
	@echo "  make fetch-opencv          # runtime: OpenCV sources → .cache/opencv/"
	@echo "  make fetch-opencv-ximgproc # runtime: ximgproc EdgeDrawing → .cache/"
	@echo "  make fetch-rknn-rt         # runtime: aarch64 librknnrt → prebuilt/rknn-rt/"
	@echo "  make fetch-flutter-sdk     # dev: host Flutter SDK → flutter-sdk/"
	@echo "  make fetch-rknn-toolkit    # dev: RKNN-Toolkit2 + torch (ONNX→RKNN on x86)"
	@echo "  make export-prebuilt       # re-export flutter + runtime (usually build-* already did)"
	@echo "  rebuild-*                  # FORCE=1 refresh (e.g. make rebuild-runtime-deps)"
	@echo ""
	@echo "Cloud + Upgrade (api-server / R2 publish / A/B + app/peripheral):"
	@echo "  make login                 # api-server POST /v1/login → output/cloud/credentials.json (access_token)"
	@echo "  make register-device       # SN=/IP= select board; SSH read-identity → POST /v1/admin/devices (needs login)"
	@echo "  make sign-keys             # release Ed25519 keypair → keys/ota/ + overlay /etc/ota/ed25519.pub"
	@echo "  make pack-ota              # pack existing boot/boot_b/rootfs[+oem] + manifest → tar.gz [+.sig]; does not build"
	@echo "  make pack-app              # tar.gz of overlay APP tree → output/app/<APP>/v*.tar.gz"
	@echo "  make upgrade               # SSH: pack-ota (or UPGRADE_PACKAGE=+.sig) host-HTTP → device pull; RockUSB: di (or extract UPGRADE_PACKAGE); OEM_ONLY=1"
	@echo "  make upgrade-app           # sign+HTTP serve app tar.gz; device download/verify/install+hmi restart"
	@echo "  make upgrade-control-board # sign+HTTP serve control-board bin; device download/verify/flash (no version gate)"
	@echo "  make upgrade-camera        # sign+HTTP serve camera zip; device download/verify/flash (no version gate)"
	@echo "  make upgrade-process-library # push process-library for device model; force import (no version gate)"
	@echo "  make publish               # pack-ota + upload tar.gz+.sig + release.json to R2 (presign; release-only)"
	@echo "  make publish-only          # upload existing ota-package.tar.gz+.sig (no pack) → release.json"
	@echo "  make publish-app                     # package+sign+upload app tar.gz → lws-hmi/app/release.json"
	@echo "  make publish-control-board-firmware  # sign+upload newest CB bin → lws-hmi/control-board/release.json"
	@echo "  make publish-camera-firmware         # sign+upload newest camera zip → lws-hmi/camera/release.json"
	@echo ""
	@echo "Audit:"
	@echo "  make audit                 # Lynis on device → output/audit/lynis-* (SN=/IP=; STRICT=1)"
	@echo "  make audit-cve             # Syft SBOM + Grype + cve-bin-tool → output/audit/cve-* (APP=; STRICT=1)"
	@echo "  make fetch-cve-db          # refresh host Grype + cve-bin-tool DBs (before release audit-cve)"
	@echo ""
	@echo "USB Flash (macOS / Linux x86_64 / Windows Git Bash):"
	@echo "  make reboot                # Linux → USB-SSH/SSH sysrq + unregister; Android → adb"
	@echo "  make reboot-loader         # Linux USB-SSH → RockUSB + unregister; Android → adb"
	@echo "  make flash                 # uf factory.img (APP+FACTORY_SKU); IMAGE= override; Maskrom ul"
	@echo "  make flash-android         # optional: flash Android instead"
	@echo ""
	@echo "Emulator (P3.2 — same Image+rootfs + sim-virt OEM; docs/p32-emulator.md):"
	@echo "  make setup-emulator-qemu   # once (macOS): install qemu-virgl (host VirGL / ANGLE→Metal)"
	@echo "  make fetch-emulator-swgl   # once: guest Mesa virtio_gpu → prebuilt/ (9p; FORCE=1 to refetch)"
	@echo "  make build-emulator        # assemble Image+rootfs+sim-virt oem → output/firmware/emulator/ (keeps provision.img; FORCE=1 recreates it)"
	@echo "  make emulator              # start QEMU (host VirGL; SSH :2222 + HTTP :5580 hostfwd)"
	@echo "  make emulator-stop         # stop lws-hmi QEMU guest (not Android Studio)"
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
	@echo "  CACHE_ROOT=...   # NAS mount for large .cache artifacts (see .env.example)"
	@echo "  CACHE_URL=...      # optional HTTP mirror of the same layout"
	@echo "  SN=<sn|chipid>             # select device by SN or ChipID (flash / USB-SSH / SSH)"
	@echo "  CHIPID=<chipid>            # select by ChipID only (multi-board)"
	@echo "  PRODUCT_SN=<sn>            # write-identity product serial only (not selection SN=; not register-device)"
	@echo "  FORCE=1                    # write-identity: overwrite non-empty Vendor Storage SN"
	@echo "  CLOUD_API_BASE=<url>       # api-server origin (default api-prod; test: api-test.lasercyber.workers.dev)"
	@echo "  CLOUD_ACCESS_TOKEN=<jwt>   # override saved login token (else output/cloud/credentials.json)"
	@echo "  CLOUD_ACCOUNT= / PASSWORD= # non-interactive make login (do not commit password)"
	@echo "  PUBLISH_API_TOKEN=<tok>    # make publish presign Bearer (STATIC_API_TOKENS); else login token"
	@echo "  PUBLISH_ARTIFACT=<slug>    # override R2 prefix (default APP with _→-); allows non-*_hmi"
	@echo "  IP=<addr>                  # registered SSH only (not USB-SSH); make connect first"
	@echo "  UPGRADE_TRANSPORT=auto|ssh|rockusb  # make upgrade transport (default auto)"
	@echo "  UPGRADE_PACKAGE=<path>     # existing .tar/.tar.gz/.tgz for make upgrade (SSH needs <path>.sig; RockUSB extracts then di)"
	@echo "  IMAGE=<path>               # firmware image for make flash"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)"
	@echo "  DOCKER_PLATFORM=$(DOCKER_PLATFORM)"
	@echo ""
	@echo "Notes:"
	@echo "  - Daily A/B: make build-kernel and/or build-rootfs then make upgrade (SSH packages+signs tar.gz; RockUSB di loose imgs)."
	@echo "  - Existing OTA tarball: UPGRADE_PACKAGE=/path/to/ota-package.tar.gz make upgrade (SSH: sibling .sig; RockUSB: extract+di)."
	@echo "  - Loader/Maskrom: make reboot-loader (or Maskrom) then make upgrade (di OTA images; not factory uf)."
	@echo "  - OEM-only (helpers/profile): make build-oem && OEM_ONLY=1 make upgrade"
	@echo "  - Cloud/publish + SSH upgrade: OTA_SIGNING_KEY=… REQUIRE_OTA_SIG=1 make pack-ota (archive + .sig); make upgrade serves via host HTTP."
	@echo "  - make publish: same tar.gz+.sig as upgrade; GET presigned-url on CLOUD_API_BASE (api-prod) then PUT R2; manifest has no sha512."
	@echo "  - macOS Docker: each build-* publishes matching imgs to output/firmware/ only (no host linux-sdk/output/ mirror)."
	@echo "  - Factory: make build-oem then build-img → output/firmware/<APP>/<sku>/factory.img; make flash."
	@echo "  - Kernel FIT shared (no APP=). Rootfs product = APP= only. Factory hardware = FACTORY_SKU= + OEM."
	@echo "  - APP= selects product HMI: *_hmi→/opt/hmi; rootfs under output/firmware/<APP>/ (+ R2 publish prefix)."
	@echo "  - FACTORY_SKU=ynh960-p800 (default) or ek3562-dev; override UBOOT_ID= / OEM_ID=; see board/factory-skus.tsv."
	@echo "  - Emulator: README Make commands → P3.2 emulator (setup → deps → kernel/rootfs → setup-emulator-qemu → fetch-emulator-swgl → build-emulator → emulator)."
	@echo "  - Set VAR=value before the command, or add a '.env' in the repo root (see .env.example)."

# --- Setup ---

setup: apply-overlay
	@bash scripts/setup-host.sh

apply-overlay:
	@# macOS Docker volume: apply inside the builder (/work/sdk). docker-run skips
	@# auto-overlay by default — run apply-overlay.sh as the container command.
	@if [ "$$(uname -s)" = Darwin ] && [ "${BUILD_BIND_MOUNT:-}" != "1" ]; then \
		SKIP_OVERLAY=1 bash scripts/docker-run.sh bash /work/lws-hmi/scripts/apply-overlay.sh; \
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

build: check-prebuilt apply-overlay lunch build-boot-logo build-ai build-app build-kernel build-rootfs build-oem build-img
	@echo ""
	@if [[ -r output/firmware/update.img || -r output/firmware/ynh960-p800/factory.img ]]; then \
		echo "Build complete:"; \
		bash scripts/artifact-size.sh output/firmware/ynh960-p800/factory.img 2>/dev/null \
			|| bash scripts/artifact-size.sh output/firmware/update.img; \
	else \
		echo "ERROR: factory.img / update.img missing after build" >&2; exit 1; \
	fi

# Shared kernel Image once; slot scripts rebuild DTBs + repack FIT (parallel for build-kernel).
define RUN_BUILD_KERNEL
mkdir -p output/logs; \
LOG="output/logs/build-kernel-$(1)-$$(date +%Y%m%d-%H%M%S).log"; \
echo "Logging to $$LOG"; \
bash scripts/docker-run.sh bash -lc 'bash /work/lws-hmi/scripts/sync-lunch-config.sh && bash /work/lws-hmi/scripts/build-kernel-ab.sh $(2)' 2>&1 | tee "$$LOG"; \
test $${PIPESTATUS[0]} -eq 0
endef

build-kernel-a:
	@$(call RUN_BUILD_KERNEL,a,a)
	@bash scripts/docker-export-artifacts.sh boot
	@mkdir -p output/firmware/emulator; \
	 if [ -r output/firmware/Image ]; then cp -Lf output/firmware/Image output/firmware/emulator/Image; \
	 echo "published output/firmware/emulator/Image"; fi

build-kernel-b:
	@$(call RUN_BUILD_KERNEL,b,b)
	@bash scripts/docker-export-artifacts.sh boot
	@mkdir -p output/firmware/emulator; \
	 if [ -r output/firmware/Image ]; then cp -Lf output/firmware/Image output/firmware/emulator/Image; \
	 echo "published output/firmware/emulator/Image"; fi

build-kernel:
	@$(call RUN_BUILD_KERNEL,ab,)
	@bash scripts/docker-export-artifacts.sh boot
	@mkdir -p output/firmware/emulator; \
	 if [ -r output/firmware/Image ]; then cp -Lf output/firmware/Image output/firmware/emulator/Image; \
	 echo "published output/firmware/emulator/Image"; fi

# Rootfs: Weston + eLinux + Mali wayland-gbm.
# prepare-rootfs flips Mali/embedder only when the stack stamp differs.
# Does not apply-overlay — run make apply-overlay after overlay/DTS/fs changes.
# ensure-rootfs-apps: build missing app/*/build/bundle/release, sync → SDK opt/, pack rootfs.
build-rootfs: prepare-rootfs
	@APP='$(APP)' bash scripts/ensure-rootfs-apps.sh
	@bash scripts/docker-run.sh ./build.sh rootfs
	@bash scripts/lws-hmi-rootfs-postprocess.sh
	@bash scripts/verify-rootfs-overlay.sh
	@APP='$(APP)' bash scripts/docker-export-artifacts.sh rootfs

# Stack ensure only (check-prebuilt + Mali/embedder). Idempotent; no apply-overlay.
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
	@APP='$(APP)' FORCE='$(FORCE)' bash scripts/build-emulator.sh

emulator:
	@bash scripts/run-emulator.sh start

emulator-stop:
	@bash scripts/run-emulator.sh stop

build-boot-logo:
	@bash scripts/build-boot-logo.sh

build-app:
	@APP='$(APP)' bash scripts/build-app.sh

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

build-libexec-binaries:
	@TOOL='$(TOOL)' FORCE='$(FORCE)' bash scripts/build-libexec-binaries.sh

rebuild-libexec-binaries:
	@TOOL='$(TOOL)' FORCE=1 bash scripts/build-libexec-binaries.sh

# Screen capture (HMI present-hook + libhmi_capture.so). Also via TOOL=hmi-capture make build-libexec-binaries.
build-hmi-capture:
	@FORCE='$(FORCE)' bash scripts/build-hmi-capture.sh

screenshot:
	@chmod +x scripts/screenshot.sh
	@$(call WITH_DOTENV,ROTATE='$(ROTATE)' Q='$(Q)' bash scripts/screenshot.sh)

# Ctrl+C is the normal stop; script exits 0 after pull. Map 130→0 so Make matches.
record-screen:
	@chmod +x scripts/record-screen.sh
	@set +e; \
	$(call WITH_DOTENV,FPS='$(FPS)' SCALE='$(SCALE)' ROTATE='$(ROTATE)' AUDIO='$(AUDIO)' AUDIO_DEV='$(AUDIO_DEV)' DURATION='$(DURATION)' bash scripts/record-screen.sh); \
	_ec=$$?; \
	if [ $$_ec -eq 0 ] || [ $$_ec -eq 130 ]; then exit 0; fi; \
	exit $$_ec

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
	@$(MAKE) apply-overlay

clean-buildroot-output:
	@bash scripts/clean-buildroot-output.sh

migrate-buildroot-output:
	@bash scripts/migrate-buildroot-output.sh

fix-buildroot-host-rpaths:
	@bash scripts/fix-buildroot-host-rpaths.sh

export-buildroot-toolchain:
	@bash scripts/export-buildroot-toolchain.sh

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

# Team SSH host key → keys/ssh/id_ed25519 (gitignored) + rootfs /root/.ssh/authorized_keys overlay.
ssh-keys:
	@chmod +x scripts/ssh-keys.sh
	@bash scripts/ssh-keys.sh

# Sign + host-HTTP serve HMI app tar.gz; device download+verify+install+/opt/hmi + hmi.service restart.
# Device-side: app watches /run/hmi/upgrade-app.cmd for `download <url>`.
upgrade-app:
	@chmod +x scripts/upgrade-app.sh scripts/pack-app.sh scripts/peripheral-ota-http.sh scripts/ota-sign.sh scripts/ota-http-serve.py
	@$(call WITH_DOTENV,APP='$(APP)' APP_PACKAGE='$(APP_PACKAGE)' bash scripts/upgrade-app.sh)

# Debug: unsigned SSH stream of app/<APP>/build/bundle/release → /opt/* (+ unit restart).
# Not an alias of upgrade-app — use upgrade-app / publish-app for signed shipping.
push-app:
	@chmod +x scripts/push-app.sh
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/push-app.sh)

pack-app:
	@chmod +x scripts/pack-app.sh
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/pack-app.sh)

# Sign + host-HTTP serve control-board firmware; device download+verify+Modbus (no version gate).
# Device-side: app watches /run/hmi/upgrade-control-board.cmd for `download <url>`.
upgrade-control-board:
	@chmod +x scripts/upgrade-control-board.sh scripts/peripheral-ota-http.sh scripts/ota-sign.sh scripts/ota-http-serve.py
	@$(call WITH_DOTENV,FIRMWARE_BIN='$(FIRMWARE_BIN)' bash scripts/upgrade-control-board.sh)

# Sign + host-HTTP serve camera firmware ZIP; device download+verify+CGI (no version gate).
# Device-side: app watches /run/hmi/upgrade-camera.cmd for `download <url>`.
upgrade-camera:
	@chmod +x scripts/upgrade-camera.sh scripts/peripheral-ota-http.sh scripts/ota-sign.sh scripts/ota-http-serve.py
	@$(call WITH_DOTENV,FIRMWARE_ZIP='$(FIRMWARE_ZIP)' bash scripts/upgrade-camera.sh)

# Push process-library matched to device Vendor Storage model (host helper).
# Device-side: app watches /run/hmi/upgrade-process-library.cmd and force-imports.
upgrade-process-library:
	@chmod +x scripts/upgrade-process-library.sh
	@$(call WITH_DOTENV,PACKAGE_DIR='$(PACKAGE_DIR)' bash scripts/upgrade-process-library.sh)

# Clear process-library DB via HMI watcher + force bundled re-import (no restart).
reset-process-library:
	@chmod +x scripts/reset-process-library.sh
	@$(call WITH_DOTENV,bash scripts/reset-process-library.sh)

# Re-seal software-KEK secrets → OP-TEE (Wi‑Fi vault + cloud Ed25519). SCOPE=all|wifi|cloud.
migrate-secrets:
	@chmod +x scripts/migrate-secrets.sh
	@$(call WITH_DOTENV,SCOPE='$(SCOPE)' bash scripts/migrate-secrets.sh)

migrate-seal-kek:
	@chmod +x scripts/migrate-seal-kek.sh
	@$(call WITH_DOTENV,bash scripts/migrate-seal-kek.sh)

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

# Lynis live-board hardening audit → output/audit/lynis-* (ephemeral upload; not flash preflight).
audit:
	@chmod +x scripts/audit-lynis.sh
	@$(call WITH_DOTENV,STRICT='$(STRICT)' FAIL_ON='$(FAIL_ON)' bash scripts/audit-lynis.sh)

# Syft SBOM + Grype + cve-bin-tool on APP rootfs.img → output/audit/cve-* (needs build-rootfs).
audit-cve:
	@chmod +x scripts/audit-cve.sh
	@$(call WITH_DOTENV,APP='$(APP)' STRICT='$(STRICT)' FAIL_ON='$(FAIL_ON)' ROOTFS_IMG='$(ROOTFS_IMG)' bash scripts/audit-cve.sh)

# Refresh host Grype + cve-bin-tool vulnerability DBs (no rootfs scan).
fetch-cve-db:
	@chmod +x scripts/fetch-cve-db.sh
	@$(call WITH_DOTENV,bash scripts/fetch-cve-db.sh)

# Upsert one or more UPPERCASE_KEY=value into /var/lib/hal/product.ini (SSH).
set-prop:
	@chmod +x scripts/set-product-prop.sh
	@$(call WITH_DOTENV,bash scripts/set-product-prop.sh $(MAKEOVERRIDES))

# Remove one UPPERCASE key from product.ini (e.g. make del-prop CAMERA_IP).
del-prop:
	@chmod +x scripts/del-product-prop.sh
	@$(call WITH_DOTENV,bash scripts/del-product-prop.sh $(filter-out del-prop,$(MAKECMDGOALS)) $(MAKEOVERRIDES))

# Write brand/model/product SN into Vendor Storage (SSH). Selection: SN=/CHIPID=/IP=.
# Payload: BRAND= MODEL= PRODUCT_SN= (alias IDENTITY_SN=). FORCE=1 to overwrite SN.
# Pass via MAKEOVERRIDES only — do NOT wrap BRAND='$(BRAND)' inside WITH_DOTENV's
# bash -c '…' (single quotes break on MODEL='L1 Pro' and silently no-op).
write-identity:
	@chmod +x scripts/write-identity.sh
	@$(call WITH_DOTENV,bash scripts/write-identity.sh $(MAKEOVERRIDES))

# Log in to sibling api-server; persist access_token under output/cloud/ (gitignored).
login:
	@chmod +x scripts/cloud-login.sh scripts/cloud-credentials.sh
	@$(call WITH_DOTENV,bash scripts/cloud-login.sh)

# Register selected board with api-server admin devices (SSH identity + login JWT).
# Selection: SN=/IP= (same as push-app). Identity always from on-board read-identity.
register-device:
	@chmod +x scripts/register-device.sh scripts/cloud-credentials.sh
	@$(call WITH_DOTENV,bash scripts/register-device.sh $(MAKEOVERRIDES))

# Print OS Version by default; APP= (CLI or env) selects Flutter app pubspec.
# Makefile default `APP ?= lws_hmi` (origin file) alone does not select Flutter.
version:
	@chmod +x scripts/app-version.sh
ifneq ($(filter command\ line environment,$(origin APP)),)
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/app-version.sh print-app)
else
	@$(call WITH_DOTENV,bash scripts/app-version.sh print-os)
endif

# Bump OS Version by default; APP= (CLI or env) + VERSION= bumps Flutter pubspec.
version-bump:
	@test -n "$(VERSION)" || (echo 'ERROR: VERSION is required (e.g. make version-bump VERSION=1.0.0)' >&2; exit 1)
	@chmod +x scripts/app-version.sh
ifneq ($(filter command\ line environment,$(origin APP)),)
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/app-version.sh bump-app '$(VERSION)')
else
	@$(call WITH_DOTENV,bash scripts/app-version.sh bump-os '$(VERSION)')
endif

# Release Ed25519 keypair (private under keys/ota/; pubkey → overlay /etc/ota/).
sign-keys:
	@chmod +x scripts/sign-keys.sh
	@bash scripts/sign-keys.sh

# Whole-device OTA tar.gz (+ optional .sig). Publish/CI: REQUIRE_OTA_SIG=1 OTA_SIGNING_KEY=…
pack-ota:
	@chmod +x scripts/pack-ota.sh scripts/ota-sign.sh
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/pack-ota.sh)

# Cloud publish: signed pack-ota then upload tar.gz + .sig + release.json (R2 presign on CLOUD_API_BASE).
publish:
	@chmod +x scripts/pack-ota.sh scripts/ota-sign.sh scripts/publish-ota.sh scripts/cloud-credentials.sh
	@$(call WITH_DOTENV,APP='$(APP)' REQUIRE_OTA_SIG=1 bash scripts/pack-ota.sh)
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/publish-ota.sh)

# Upload existing signed OTA package (no pack). Always release.json (no staging / RELEASE=).
publish-only:
	@chmod +x scripts/publish-ota.sh scripts/cloud-credentials.sh
	@$(call WITH_DOTENV,APP='$(APP)' bash scripts/publish-ota.sh)

# HMI app channel publish (always release.json under lws-hmi/app/).
publish-app:
	@chmod +x scripts/publish-app.sh scripts/pack-app.sh scripts/ota-sign.sh scripts/cloud-credentials.sh scripts/peripheral-ota-http.sh
	@$(call WITH_DOTENV,APP='$(APP)' APP_PACKAGE='$(APP_PACKAGE)' bash scripts/publish-app.sh)

publish-app-only:
	@chmod +x scripts/publish-app.sh scripts/cloud-credentials.sh scripts/peripheral-ota-http.sh
	@$(call WITH_DOTENV,APP='$(APP)' APP_PACKAGE='$(APP_PACKAGE)' bash scripts/publish-app.sh 1)

# Peripheral firmware cloud publish (always release.json under lws-hmi/control-board|camera/).
publish-control-board-firmware:
	@chmod +x scripts/publish-peripheral-firmware.sh scripts/ota-sign.sh scripts/cloud-credentials.sh scripts/peripheral-ota-http.sh
	@$(call WITH_DOTENV,APP='$(APP)' FIRMWARE_BIN='$(FIRMWARE_BIN)' bash scripts/publish-peripheral-firmware.sh control-board)

publish-control-board-firmware-only:
	@chmod +x scripts/publish-peripheral-firmware.sh scripts/cloud-credentials.sh scripts/peripheral-ota-http.sh
	@$(call WITH_DOTENV,APP='$(APP)' FIRMWARE_BIN='$(FIRMWARE_BIN)' bash scripts/publish-peripheral-firmware.sh control-board 1)

publish-camera-firmware:
	@chmod +x scripts/publish-peripheral-firmware.sh scripts/ota-sign.sh scripts/cloud-credentials.sh scripts/peripheral-ota-http.sh
	@$(call WITH_DOTENV,APP='$(APP)' FIRMWARE_ZIP='$(FIRMWARE_ZIP)' bash scripts/publish-peripheral-firmware.sh camera)

publish-camera-firmware-only:
	@chmod +x scripts/publish-peripheral-firmware.sh scripts/cloud-credentials.sh scripts/peripheral-ota-http.sh
	@$(call WITH_DOTENV,APP='$(APP)' FIRMWARE_ZIP='$(FIRMWARE_ZIP)' bash scripts/publish-peripheral-firmware.sh camera 1)

# SSH: package (unless UPGRADE_PACKAGE=) → host HTTP serve tar.gz+.sig → device download+verify+staged apply.
# RockUSB: still di loose images (unsigned; or package members via upgrade-package-env).
upgrade:
	@chmod +x scripts/upgrade-remote.sh scripts/pack-ota.sh scripts/ota-sign.sh scripts/ota-http-serve.py
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
