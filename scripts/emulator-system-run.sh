#!/usr/bin/env bash
# One-command system-level install and launch on an **already-running** adb device where adb root + adb remount work (writes /system/priv-app).
# Typical setup: `make emulator`, Android Studio writable-system emulator, or an engineering/device image — not most locked retail phones.
# Defaults: adb serial = ADB_SERIAL or emulator-${EMULATOR_PORT} (default 5554); staging APK at app/build/outputs/apk/staging/app-staging.apk, make build.
# MODEL / /system/etc/model.properties and privapp permissions XML: only `make emulator` applies those when using this repo's emulator flow.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"
source scripts/emulator-system-common.sh
unset MODEL AVD

ensure_tools
ensure_device_for_run
build_apk
root_and_remount
push_permissions
push_privapp
reboot_and_verify
start_app

echo "OK: system app installed and launched on ${SERIAL}"
