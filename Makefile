# Local automation: signed release build, priv-app install, on-device tests.
# Optional: create .env with SIGNING_* variables (see .env.example). Bash `source .env` works too.
# Device: set ADB_SERIAL when more than one adb device is connected.

SHELL := /bin/bash
.DEFAULT_GOAL := help

SOURCE_RELEASE_APK := app/build/outputs/apk/release/app-release.apk
STAGING_APK := app/build/outputs/apk/staging/app-staging.apk
# Control-card firmware: single source under firmware/ (same "latest" rule as bundleFirmwareAssets).
# Use a helper script so GNU make's $(shell ...) is not broken by Python `)` characters.
FIRMWARE_BIN := $(shell bash "$(CURDIR)/scripts/make/pick-latest-firmware-bin.sh" 2>/dev/null)
APP_VERSION_NAME := $(shell sed -n 's/^[[:space:]]*versionName[[:space:]]*=[[:space:]]*"\([^"]*\)"/\1/p' app/build.gradle.kts | sed -n '1p')
PACK_VERSION := $(APP_VERSION_NAME)
ifeq ($(RELEASE),1)
  PACK_VERSION := $(APP_VERSION_NAME)
else
  PACK_VERSION := $(APP_VERSION_NAME)-beta
endif
PACK_NAME := lws-app_v$(PACK_VERSION).zip
PACK_OUTPUT := build/$(PACK_NAME)
PUBLISH_URL := http://api-prod.lasercyber.workers.dev/upload/lws-app/$(PACK_NAME)
PUBLISH_BASE_URL := https://api-prod.lasercyber.workers.dev
PUBLISH_PUBLIC_BASE_URL := https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev

# OTA manifest: staging by default; RELEASE=1 selects release.json + prod channel (not MANIFEST_JSON_FILE=…).
ifeq ($(RELEASE),1)
  TARGET_APK := $(SOURCE_RELEASE_APK)
  GRADLE_MANIFEST_FLAGS := -PMANIFEST_JSON_FILE=release.json -PRELEASE_CHANNEL=true
  PUBLISH_MANIFEST_NAME := release.json
else
  TARGET_APK := $(STAGING_APK)
  GRADLE_MANIFEST_FLAGS := -PMANIFEST_JSON_FILE=staging.json -PRELEASE_CHANNEL=false
  PUBLISH_MANIFEST_NAME := staging.json
endif

.PHONY: help build build-apk prepare install install-cloud-resume ensure-adb-ready sync sync-firmware sync-ai sync-native deploy emulator emulator-forward test pack pack-only publish publish-only version version-bump uninstall-eth0-autofix mediamtx opencv ai verify-opencv-detect alarm alarm-clean relaunch launch-dev reset-process-library set-prop del-prop show-camera-overlay

# Run a command with `.env` exported (if present).
# Usage: $(call WITH_DOTENV,<command>)
define WITH_DOTENV
bash -c 'set -euo pipefail; __ENV_ADB_SERIAL="$${ADB_SERIAL-}"; __ENV_MODEL="$${MODEL-}"; __ENV_SN="$${SN-}"; __ENV_CAMERA_IP="$${CAMERA_IP-}"; __ENV_HOST_IP="$${HOST_IP-}"; __ENV_EMULATOR_PORT="$${EMULATOR_PORT-}"; __ENV_EMULATOR_GPU="$${EMULATOR_GPU-}"; __ENV_EMULATOR_RECREATE="$${EMULATOR_RECREATE-}"; __ENV_EMULATOR_SCALE="$${EMULATOR_SCALE-}"; __ENV_EMULATOR_LCD_WIDTH="$${EMULATOR_LCD_WIDTH-}"; __ENV_EMULATOR_LCD_HEIGHT="$${EMULATOR_LCD_HEIGHT-}"; __ENV_EMULATOR_LCD_DENSITY="$${EMULATOR_LCD_DENSITY-}"; set -a; [[ -f .env ]] && source .env; set +a; [[ -n "$$__ENV_ADB_SERIAL" ]] && export ADB_SERIAL="$$__ENV_ADB_SERIAL"; [[ -n "$$__ENV_MODEL" ]] && export MODEL="$$__ENV_MODEL"; [[ -n "$$__ENV_SN" ]] && export SN="$$__ENV_SN"; [[ -n "$$__ENV_CAMERA_IP" ]] && export CAMERA_IP="$$__ENV_CAMERA_IP"; [[ -n "$$__ENV_HOST_IP" ]] && export HOST_IP="$$__ENV_HOST_IP"; [[ -n "$$__ENV_EMULATOR_PORT" ]] && export EMULATOR_PORT="$$__ENV_EMULATOR_PORT"; [[ -n "$$__ENV_EMULATOR_GPU" ]] && export EMULATOR_GPU="$$__ENV_EMULATOR_GPU"; [[ -n "$$__ENV_EMULATOR_RECREATE" ]] && export EMULATOR_RECREATE="$$__ENV_EMULATOR_RECREATE"; [[ -n "$$__ENV_EMULATOR_SCALE" ]] && export EMULATOR_SCALE="$$__ENV_EMULATOR_SCALE"; [[ -n "$$__ENV_EMULATOR_LCD_WIDTH" ]] && export EMULATOR_LCD_WIDTH="$$__ENV_EMULATOR_LCD_WIDTH"; [[ -n "$$__ENV_EMULATOR_LCD_HEIGHT" ]] && export EMULATOR_LCD_HEIGHT="$$__ENV_EMULATOR_LCD_HEIGHT"; [[ -n "$$__ENV_EMULATOR_LCD_DENSITY" ]] && export EMULATOR_LCD_DENSITY="$$__ENV_EMULATOR_LCD_DENSITY"; $(1)'
endef

help:
	@echo "LWS UI ($(APP_VERSION_NAME)) - Make targets"
	@echo ""
	@echo "Build:"
	@echo "  make build                 # Full build: opencv + ai + mediamtx + Gradle APK (staging unless RELEASE=1)"
	@echo "  make build-apk             # Gradle assembleRelease only (no native rebuild)"
	@echo "  make opencv                # Fetch vendored OpenCV Android SDK (native/toolchains/opencv)"
	@echo "  make ai                    # Build lws_ai_daemon (+ optional libai for tests); stages jniLibs"
	@echo "  make ai AI_INSTALL=1 ...   # After make ai, run :app:installDebug with optional -P flags below"
	@echo "  make mediamtx              # Cross-compile MediaMTX for arm64-v8a into app assets"
	@echo ""
	@echo "Install and Run:"
	@echo "  make prepare               # prepare device: writable /system, permissions XML, model config"
	@echo "  make install               # priv-app install + reboot + pm sync + launch; emulator: adb forward :5580 after launch"
	@echo "  make install VERSION=1.0.36 # cloud staging zip install (beta channel; strict verify)"
	@echo "  make install VERSION=1.0.17 RELEASE=1  # cloud release zip install (RELEASE must be on CLI)"
	@echo "  make install VERSION=1.0.30 INSTALL_SKIP_REBOOT=1  # wireless: push only, then reboot + resume"
	@echo "  make install-cloud-resume VERSION=1.0.30  # after reboot / wireless adb back online"
	@echo "  make sync                  # build-apk + adb push + pm install + launch (daily Java/Kotlin changes)"
	@echo "  make sync-firmware         # push latest firmware/*.bin + OTA (app must be foreground; no confirm, no version check)"
	@echo "  make sync-ai               # push AI jniLibs (liblws_ai_daemon.so + runtimes) + restart (no APK)"
	@echo "  make sync-native           # deprecated alias of sync-ai"
	@echo "  make verify-opencv-detect  # verify host libai JNI + optional APK DEX (dev/tests)"
	@echo "  make deploy                # build + prepare + install (full first-time setup)"
	@echo "  make emulator              # start emulator, prepare device, lens_det AI install if needed, launch app"
	@echo "  make emulator-forward      # re-apply adb -a server start + forward tcp:5580 → emulator-${EMULATOR_PORT:-5554}"
	@echo ""
	@echo "Test:"
	@echo "  make test                  # run scripts/ci checks + instrumentation (no app reinstall)"
	@echo ""
	@echo "Debug:"
	@echo "  make launch-dev            # open DevActivity on adb device (no rebuild or reinstall)"
	@echo "  make relaunch              # force-stop + relaunch app (no rebuild or reinstall)"
	@echo "  make reset-process-library # clear process-library DB + relaunch to re-import bundled xlsx"
	@echo "  make set-prop HOST_IP=192.168.1.50  # upsert one key in model.properties"
	@echo "  make del-prop HOST_IP      # remove one key from model.properties"
	@echo "  make alarm CODE=C002       # demo alarm popup on device (sticky until dismissed; staging only)"
	@echo "  make alarm CODE=H022       # e.g. laser comm alarm; H034 = zero-point offset"
	@echo "  make alarm-clean           # clear alarm restrictions only; keep visible warn popup (staging only)"
	@echo "                             # also clears production L001 lens block; stain detect may re-alert if still dirty"
	@echo "  make show-camera-overlay ENABLE=1 [X=10] [Y=10]  # clock + Machine Model name overlay"
	@echo ""
	@echo "Device network:"
	@echo "  make uninstall-eth0-autofix   # remove legacy /system eth0 self-heal (192.168.1.10); needs root"
	@echo "  make uninstall-eth0-autofix REBOOT=1   # same + reboot device"
	@echo ""
	@echo "Package:"
	@echo "  make pack                  # build + package APK and firmware bin into build/$(PACK_NAME)"
	@echo "  make pack-only             # package existing APK and firmware bin (no build)"
	@echo ""
	@echo "Publish:"
	@echo "  make publish               # pack + upload zip and manifest (staging.json or release.json if RELEASE=1)"
	@echo "  make publish-only          # publish existing package (no build/pack)"
	@echo ""
	@echo "Version:"
	@echo "  make version               # print versionName+versionCode from app/build.gradle.kts"
	@echo "  make version-bump VERSION=1.0.27  # or VERSION=1.0.27+1027 (code = M*1000+m*100+p)"
	@echo ""
	@echo "Common env vars:"
	@echo "  RELEASE=1                  # Release channel: release.json + prod tier, app-release.apk for install/pack"
	@echo "  SKIP_BUNDLED_FETCH=1       # Skips bundled asset downloads for Gradle build"
	@echo "  SKIP_RKNN_CONVERT=1        # make ai: skip ONNX→RKNN (use existing native/lensinspector/assets/models/*.rknn)"
	@echo "  AI_SKIP_RKNN_CONVERT=1     # make ai: alias of SKIP_RKNN_CONVERT (compat)"
	@echo "  RKNN_FORCE_CONVERT=1       # make ai: ignore ONNX SHA-256 cache and re-run Docker conversion"
	@echo "  AI_INSTALL=1               # make ai: also ./gradlew :app:installDebug after staging daemon jniLibs"
	@echo "  ENABLE_RKNN_STAIN_APP=...  # -PENABLE_RKNN_STAIN_APP=... for make build / make ai AI_INSTALL=1 (Gradle default: false)"
	@echo "  ENABLE_LENS_DET_APP=...    # -PENABLE_LENS_DET_APP=... (staging default: true; RELEASE=1 default: false)"
	@echo "  AI_GRADLE_PROPS='-P...'    # extra Gradle -P flags for make ai AI_INSTALL=1"
	@echo "  MODEL=<device-model>       # 'make emulator': write model= to /system/etc/model.properties (merged every run)"
	@echo "  SN=<serial>                # 'make emulator': write sn= to /system/etc/model.properties"
	@echo "  CAMERA_IP=<ipv4>           # optional: write camera_ip= to /system/etc/model.properties (make emulator/prepare)"
	@echo "  CAMERA_TYPE=<1|2>          # optional: write camera_type= (1=BLUE_LIGHT default, 2=RED_LIGHT)"
	@echo "  FOCUS_SCALE_REF=<int>      # optional: write focus_scale_ref= (default 0; make emulator/prepare)"
	@echo "  CONTROL_CARD_COMM_ALARM_MODE=<slide_window|immediate>  # optional: C001 detection mode (default slide_window)"
	@echo "  HOST_IP=<ipv4>             # optional: write host_ip= (make emulator); auto-detect dev host LAN when unset"
	@echo "  ADB_SERIAL=<serial>        # Set 'adb -s' target when multiple devices present"
	@echo "  EMULATOR_API_LEVEL=<n>     # 'make emulator' only: android-<n>/default AOSP system image; default 30"
	@echo "  EMULATOR_PORT=<n>          # 'make emulator' / emulator-forward: adb serial emulator-<n> for guest HTTP forward"
	@echo "  EMULATOR_GPU=<mode>        # 'make emulator' only: optional -gpu; run 'emulator -help-gpu' for available values"
	@echo "  EMULATOR_SCALE=<f>         # 'make emulator' only: host window scale (e.g. 0.75); guest resolution unchanged"
	@echo "  EMULATOR_AI_INSTALL=1      # 'make emulator' default: after boot, make ai AI_INSTALL=1 when lens_det missing"
	@echo "  EMULATOR_SKIP_AI_INSTALL=1 # 'make emulator': skip automatic lens_det AI install (same as EMULATOR_AI_INSTALL=0)"
	@echo "  EMULATOR_LCD_WIDTH=<n>     # default 2560 (device); alt 1280 @ density 160"
	@echo "  EMULATOR_LCD_HEIGHT=<n>    # default 1600; alt 800 @ density 160"
	@echo "  EMULATOR_LCD_DENSITY=<n>   # default 320; never 320 with 1280x800 px (clips UI)"
	@echo "  REBUILD_IMAGE=1            # 'make ai': rebuild RKNN Docker image; 'make emulator': delete+recreate AVD (fresh userdata)"
	@echo ""
	@echo "Notes:"
	@echo "  - Set VAR=value before the command, or add an '.env' in the repo root to set env variables."
	@echo "  - Run 'make build' and 'make prepare' before first 'make install', or use 'make deploy'."
	@echo "  - Use 'make sync' for daily Java/Kotlin edits (Gradle only); use 'make build' when native (ai/mediamtx) changes."
	@echo "  - AI native-only iterate: 'make ai && make sync-ai' (daemon/.so only). Java/IPC/assets changes still need 'make sync'."
	@echo "  - Use 'make test' for lint, unit checks, and instrumentation on the currently selected adb device."

# Set SKIP_BUNDLED_FETCH=1 to skip downloading assets when Workers endpoints are unavailable.
ifneq ($(SKIP_BUNDLED_FETCH),)
  GRADLE_MANIFEST_FLAGS += -PskipBundledFetch=true
endif

# GitLab sets GITLAB_CI; fall back to CI_JOB_ID so logs get --stacktrace / plain console even if one is missing.
GRADLE_CI_EXTRA_ARGS :=
ifneq ($(GITLAB_CI),)
  GRADLE_CI_EXTRA_ARGS := --console=plain --stacktrace
endif
ifeq ($(GRADLE_CI_EXTRA_ARGS),)
ifneq ($(CI_JOB_ID),)
  GRADLE_CI_EXTRA_ARGS := --console=plain --stacktrace
endif
endif

# Gradle -P flags for OpenCV lens_det / RKNN stain (make build, make ai AI_INSTALL=1).
# Staging/dev builds default ENABLE_LENS_DET_APP=true; RELEASE=1 keeps it off unless set explicitly.
ENABLE_RKNN_STAIN_APP ?=
ifeq ($(RELEASE),1)
ENABLE_LENS_DET_APP ?=
else
ENABLE_LENS_DET_APP ?= true
endif
AI_INSTALL ?=
AI_GRADLE_PROPS ?=

GRADLE_AI_FLAGS :=
ifneq ($(strip $(ENABLE_RKNN_STAIN_APP)),)
  GRADLE_AI_FLAGS += -PENABLE_RKNN_STAIN_APP=$(ENABLE_RKNN_STAIN_APP)
endif
ifneq ($(strip $(ENABLE_LENS_DET_APP)),)
  GRADLE_AI_FLAGS += -PENABLE_LENS_DET_APP=$(ENABLE_LENS_DET_APP)
endif
AI_GRADLE_PROPS_RESOLVED := $(AI_GRADLE_PROPS) $(GRADLE_AI_FLAGS)

version:
	@chmod +x scripts/make/app-version.sh
	@scripts/make/app-version.sh print

version-bump:
	@chmod +x scripts/make/app-version.sh
	@if [[ -z "$(VERSION)" ]]; then \
	  echo "ERROR: VERSION is required (e.g. make version-bump VERSION=1.0.27)" >&2; \
	  exit 1; \
	fi
	@scripts/make/app-version.sh bump "$(VERSION)"

mediamtx:
	@chmod +x scripts/ci/build-mediamtx.sh
	@scripts/ci/build-mediamtx.sh

opencv:
	@chmod +x scripts/make/fetch-opencv.sh scripts/make/opencv-path.sh \
	          scripts/make/fetch-opencv-ximgproc-edgedrawing.sh
	@bash scripts/make/fetch-opencv.sh
	@bash scripts/make/fetch-opencv-ximgproc-edgedrawing.sh

ai: opencv
	@chmod +x scripts/make/opencv-path.sh \
	          scripts/make/fetch-ndk-r18b.sh scripts/make/ndk-r18b-path.sh \
	          scripts/make/fetch-rknn-rt.sh scripts/make/rknn-rt-path.sh \
	          scripts/make/build-ai.sh scripts/make/stage-ai-jni-libs.sh \
	          scripts/make/convert-rknn.sh scripts/make/fetch-rknn-toolkit.sh \
	          scripts/make/rknn-cache.sh \
	          scripts/make/ensure-rosetta-host.sh
	@bash scripts/make/opencv-path.sh >/dev/null
	@bash scripts/make/fetch-ndk-r18b.sh
	@bash scripts/make/fetch-rknn-rt.sh
	@bash scripts/make/build-ai.sh
ifneq ($(filter 1 true yes TRUE yes YES,$(AI_INSTALL)),)
	@echo "make ai: installDebug$(if $(AI_GRADLE_PROPS_RESOLVED), $(AI_GRADLE_PROPS_RESOLVED),)"
	@$(call WITH_DOTENV,bash ./gradlew $(strip $(GRADLE_CI_EXTRA_ARGS)) :app:installDebug $(AI_GRADLE_PROPS_RESOLVED))
endif

verify-opencv-detect:
	@chmod +x native/lensinspector/scripts/verify_libai_jni.sh scripts/ci/verify-opencv-detect-integration.sh
	@bash scripts/ci/verify-opencv-detect-integration.sh $(if $(APK),$(APK),)

build-apk:
	@$(call WITH_DOTENV,bash ./gradlew $(strip $(GRADLE_CI_EXTRA_ARGS)) :app:assembleRelease $(GRADLE_MANIFEST_FLAGS) $(GRADLE_AI_FLAGS))
	@test -f "$(SOURCE_RELEASE_APK)" || { echo "ERROR: APK not found at $(SOURCE_RELEASE_APK)" >&2; exit 1; }
	@if [[ "$(TARGET_APK)" != "$(SOURCE_RELEASE_APK)" ]]; then \
	  mkdir -p "$(dir $(TARGET_APK))"; \
	  cp "$(SOURCE_RELEASE_APK)" "$(TARGET_APK)"; \
	fi
	@echo "APK: $(TARGET_APK)"

build: ai mediamtx build-apk

prepare:
	@chmod +x scripts/ci/prepare-device.sh
	@$(call WITH_DOTENV,./scripts/ci/prepare-device.sh)

ensure-adb-ready:
	@chmod +x scripts/ci/ensure-adb-ready.sh
	@$(call WITH_DOTENV,./scripts/ci/ensure-adb-ready.sh)

deploy: ensure-adb-ready build prepare install

emulator:
	@chmod +x scripts/emulator-launch.sh scripts/emulator-ensure-ai-opencv-stain-detect.sh
	@$(call WITH_DOTENV,./scripts/emulator-launch.sh)

emulator-forward:
	@chmod +x scripts/emulator-forward-local-http.sh
	@$(call WITH_DOTENV,./scripts/emulator-forward-local-http.sh)

INSTALL_RELEASE_FROM_CLI :=
ifeq ($(RELEASE),1)
INSTALL_RELEASE_FROM_CLI := 1
endif

install:
ifneq ($(VERSION),)
	@chmod +x scripts/ci/install-cloud-version.sh
	@$(call WITH_DOTENV,export INSTALL_RELEASE="$(INSTALL_RELEASE_FROM_CLI)"; export INSTALL_SKIP_REBOOT="$(INSTALL_SKIP_REBOOT)"; export VERSION="$(VERSION)"; ./scripts/ci/install-cloud-version.sh)
else
	@chmod +x scripts/ci/install-priv-app.sh scripts/ci/sync-pm-after-priv-app-install.sh scripts/ci/reboot-and-wait-boot.sh
	@$(call WITH_DOTENV,./scripts/ci/install-priv-app.sh "$(TARGET_APK)")
	@$(call WITH_DOTENV,./scripts/ci/reboot-and-wait-boot.sh)
	@$(call WITH_DOTENV,./scripts/ci/sync-pm-after-priv-app-install.sh "$(TARGET_APK)")
	@$(call WITH_DOTENV,if [[ -n "$${ADB_SERIAL:-}" ]]; then ADB_CMD=(adb -s "$$ADB_SERIAL"); else ADB_CMD=(adb); fi; \
	echo "INFO: launching app..."; \
	"$${ADB_CMD[@]}" shell am start -W -n com.lasercyber.lws.ui/.activitys.SplashActivity >/dev/null 2>&1 || true; \
	echo "OK: app launched.")
	@chmod +x scripts/ci/maybe-emulator-forward-local-http.sh
	@$(call WITH_DOTENV,./scripts/ci/maybe-emulator-forward-local-http.sh)
endif

install-cloud-resume:
	@chmod +x scripts/ci/install-cloud-version.sh
	@$(call WITH_DOTENV,export INSTALL_RELEASE="$(INSTALL_RELEASE_FROM_CLI)"; export INSTALL_PHASE=resume; export VERSION="$(VERSION)"; ./scripts/ci/install-cloud-version.sh)

sync: build-apk ensure-adb-ready
	@chmod +x scripts/ci/sync-install.sh
	@$(call WITH_DOTENV,./scripts/ci/sync-install.sh "$(TARGET_APK)")
	@$(call WITH_DOTENV,if [[ -n "$${ADB_SERIAL:-}" ]]; then ADB_CMD=(adb -s "$$ADB_SERIAL"); else ADB_CMD=(adb); fi; \
	echo "INFO: launching app..."; \
	"$${ADB_CMD[@]}" shell am start -W -n com.lasercyber.lws.ui/.activitys.SplashActivity >/dev/null 2>&1 || true; \
	echo "OK: sync complete.")

sync-firmware: ensure-adb-ready
	@chmod +x scripts/make/sync-firmware.sh scripts/make/pick-latest-firmware-bin.sh
	@$(call WITH_DOTENV,./scripts/make/sync-firmware.sh)

sync-ai: ensure-adb-ready
	@chmod +x scripts/ci/sync-ai.sh
	@$(call WITH_DOTENV,./scripts/ci/sync-ai.sh)

# Deprecated name kept for muscle memory / old docs.
sync-native: sync-ai
	@echo "WARN: 'make sync-native' is deprecated; use 'make sync-ai'."

uninstall-eth0-autofix:
	@chmod +x scripts/ci/uninstall-eth0-autofix.sh
	@$(call WITH_DOTENV,./scripts/ci/uninstall-eth0-autofix.sh)

launch-dev: ensure-adb-ready
	@chmod +x scripts/make/launch-dev-activity.sh
	@$(call WITH_DOTENV,./scripts/make/launch-dev-activity.sh)

relaunch: ensure-adb-ready
	@chmod +x scripts/make/relaunch-app.sh
	@$(call WITH_DOTENV,./scripts/make/relaunch-app.sh)

reset-process-library: ensure-adb-ready
	@chmod +x scripts/make/reset-process-library.sh scripts/make/relaunch-app.sh
	@$(call WITH_DOTENV,./scripts/make/reset-process-library.sh)

set-prop: ensure-adb-ready
	@chmod +x scripts/make/set-model-prop.sh scripts/make/relaunch-app.sh
	@$(call WITH_DOTENV,./scripts/make/set-model-prop.sh $(MAKEOVERRIDES))

del-prop: ensure-adb-ready
	@chmod +x scripts/make/del-model-prop.sh scripts/make/relaunch-app.sh
	@$(call WITH_DOTENV,./scripts/make/del-model-prop.sh $(filter-out del-prop,$(MAKECMDGOALS)) $(MAKEOVERRIDES))

show-camera-overlay: ensure-adb-ready
	@chmod +x scripts/make/show-camera-overlay.sh scripts/make/device-local-http-common.sh
	@$(call WITH_DOTENV,./scripts/make/show-camera-overlay.sh $(MAKEOVERRIDES))

alarm: ensure-adb-ready
	@chmod +x scripts/make/trigger-alarm.sh
	@$(call WITH_DOTENV,./scripts/make/trigger-alarm.sh trigger "$(CODE)")

alarm-clean: ensure-adb-ready
	@chmod +x scripts/make/trigger-alarm.sh
	@$(call WITH_DOTENV,./scripts/make/trigger-alarm.sh clean)

test:
	@bash -c 'set -euo pipefail; set -a; [[ -f .env ]] && source .env; set +a; \
	for f in scripts/ci/*.sh; do \
	  b=$$(basename "$$f"); \
	  case "$$b" in prepare-device.sh|install-priv-app.sh|sync-pm-after-priv-app-install.sh|run-ui-tests.sh) continue ;; esac; \
	  echo "==> $$f"; chmod +x "$$f"; "$$f"; \
	done'
	@$(call WITH_DOTENV,chmod +x scripts/ci/run-ui-tests.sh)
	@$(call WITH_DOTENV,./scripts/ci/run-ui-tests.sh)

pack: build pack-only

pack-only:
	@bash -c 'set -euo pipefail; \
	if [[ -z "$(APP_VERSION_NAME)" ]]; then \
	  echo "ERROR: failed to parse versionName from app/build.gradle.kts" >&2; \
	  exit 1; \
	fi; \
	test -f "$(TARGET_APK)" || { echo "ERROR: APK not found at $(TARGET_APK)" >&2; exit 1; }; \
	test -f "$(FIRMWARE_BIN)" || { echo "ERROR: firmware bin not found at $(FIRMWARE_BIN)" >&2; exit 1; }; \
	mkdir -p "$(dir $(PACK_OUTPUT))"; \
	zip -j -q "$(PACK_OUTPUT)" "$(TARGET_APK)" "$(FIRMWARE_BIN)"; \
	echo "Package: $(PACK_OUTPUT)"'

publish: pack publish-only

publish-only:
	@bash -c 'set -euo pipefail; \
	__publish_api_token_saved="$${PUBLISH_API_TOKEN-}"; \
	set -a; [[ -f .env ]] && source .env; set +a; \
	if [[ -n "$${__publish_api_token_saved}" ]]; then \
	  export PUBLISH_API_TOKEN="$${__publish_api_token_saved}"; \
	fi; \
	if [[ -z "$${PUBLISH_API_TOKEN:-}" ]]; then \
	  echo "ERROR: PUBLISH_API_TOKEN is required" >&2; \
	  exit 1; \
	fi; \
	test -f "$(PACK_OUTPUT)" || { echo "ERROR: package not found at $(PACK_OUTPUT)" >&2; exit 1; }; \
	echo "Publishing $(PACK_OUTPUT) with manifest $(PUBLISH_MANIFEST_NAME)"; \
	python3 scripts/publish_lws_app.py \
	  --base-url "$(PUBLISH_BASE_URL)" \
	  --token "$$PUBLISH_API_TOKEN" \
	  --zip-path "$(PACK_OUTPUT)" \
	  --pack-name "$(PACK_NAME)" \
	  --pack-version "$(PACK_VERSION)" \
	  --manifest-name "$(PUBLISH_MANIFEST_NAME)" \
	  --expected-public-base "$(PUBLISH_PUBLIC_BASE_URL)"'

# Swallow extra goals for del-prop (e.g. make del-prop HOST_IP).
%:
	@:
