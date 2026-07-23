#!/usr/bin/env bash
# Sync AI native runtimes (lws_ai_daemon + shared libs) into the installed app's
# nativeLibraryDir, then restart the app — without reinstalling the APK.
#
# Preferred path after `make ai`:
#   app/src/main/jniLibs/arm64-v8a/liblws_ai_daemon.so (+ librknnrt/libmpp/libc++_shared)
# Supervisor execs liblws_ai_daemon.so, so that binary keeps the execute bit.
#
# Usage:
#   scripts/ci/sync-ai.sh
#   scripts/ci/sync-ai.sh /path/to/app.apk          # fallback source (extract lib/<abi>/*.so)
#
# Env:
#   ADB_SERIAL (optional)
#   NATIVE_SRC_DIR (optional)  # default: app/src/main/jniLibs
#   PKG (optional)             # default: com.lasercyber.lws.ui
#   ACTIVITY (optional)        # default: .activitys.SplashActivity
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG="${PKG:-com.lasercyber.lws.ui}"
ACTIVITY="${ACTIVITY:-.activitys.SplashActivity}"
NATIVE_SRC_DIR="${NATIVE_SRC_DIR:-$ROOT/app/src/main/jniLibs}"
DAEMON_SO_NAME="liblws_ai_daemon.so"

usage() {
  cat <<'EOF'
Usage:
  scripts/ci/sync-ai.sh
  scripts/ci/sync-ai.sh /path/to/app.apk
  make sync-ai

Purpose:
  Push AI daemon + runtime .so files into the installed app nativeLibraryDir
  (no APK reinstall), then force-stop + relaunch so AiDaemonSupervisor re-spawns
  liblws_ai_daemon.so.

Sources (in order):
  1) app/src/main/jniLibs/<abi>/*.so (or NATIVE_SRC_DIR) — after `make ai`
  2) Extract from APK argument: lib/<abi>/*.so

Env:
  ADB_SERIAL      Optional adb target
  NATIVE_SRC_DIR  Defaults to app/src/main/jniLibs
  PKG             Defaults to com.lasercyber.lws.ui
  ACTIVITY        Defaults to .activitys.SplashActivity
EOF
}

HOST_APK=""
case "${1:-}" in
  "" ) ;;
  -h|--help ) usage; exit 0 ;;
  -* ) die "unknown option: $1 (use --help)" ;;
  * ) HOST_APK="$1" ;;
esac

root_exec() {
  # Prefer direct shell (works when adb shell is already uid=0).
  if adb_bin shell "$1"; then
    return 0
  fi
  # Fallback to su 0 when adb shell isn't root-capable.
  adb_bin shell 'command -v su >/dev/null 2>&1' >/dev/null 2>&1 || return 1
  adb_bin shell su 0 sh -c "$1" </dev/null
}

ensure_root_context() {
  adb_bin root >/dev/null 2>&1 || true
  sleep 1
  adb_bin wait-for-device >/dev/null 2>&1 || true
  if adb_bin shell id 2>/dev/null | tr -d '\r' | grep -q 'uid=0'; then
    return 0
  fi
  adb_bin shell 'command -v su >/dev/null 2>&1' 2>/dev/null || die "need root: adb root or su 0"
  adb_bin shell su 0 id </dev/null 2>/dev/null | tr -d '\r' | grep -q 'uid=0' || die "need root: adb root or su 0"
}

map_abi_dir() {
  case "$1" in
    arm64-v8a) echo "arm64" ;;
    armeabi-v7a) echo "arm" ;;
    x86_64) echo "x86_64" ;;
    x86) echo "x86" ;;
    *) echo "$1" ;;
  esac
}

extract_from_apk() {
  local apk="$1"
  local out_dir="$2"
  [[ -f "$apk" ]] || die "APK not found: $apk"
  command -v unzip >/dev/null 2>&1 || die "unzip not found in PATH"
  mkdir -p "$out_dir"
  unzip -q "$apk" 'lib/*/*.so' -d "$out_dir" || true
  [[ -d "$out_dir/lib" ]] || die "no native libs found in APK (lib/*/*.so): $apk"
  echo "$out_dir/lib"
}

source_lib_root() {
  if [[ -d "$NATIVE_SRC_DIR" ]] && compgen -G "$NATIVE_SRC_DIR/*/*.so" >/dev/null; then
    echo "$NATIVE_SRC_DIR"
    return 0
  fi
  [[ -n "$HOST_APK" ]] || die "no .so found under $NATIVE_SRC_DIR; run 'make ai' or provide an APK path"
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  extract_from_apk "$HOST_APK" "$tmp"
}

pick_device_lib_dir() {
  local abi_dir="$1"
  local cmd
  cmd=$(
    cat <<EOF
set -euo pipefail
pkg="${PKG}"
abi="${abi_dir}"

# Prefer dumpsys: gives exact nativeLibraryDir for current install.
if command -v dumpsys >/dev/null 2>&1; then
  d="\$(
    dumpsys package "\$pkg" 2>/dev/null \
      | tr -d '\r' \
      | sed -n 's/^.*nativeLibraryDir=\\([^ ]*\\).*$/\\1/p' \
      | grep "/lib/\$abi\$" \
      | head -n 1
  )"
  if [[ -n "\$d" ]]; then
    echo "\$d"
    exit 0
  fi

  legacy="\$(
    dumpsys package "\$pkg" 2>/dev/null \
      | tr -d '\r' \
      | sed -n 's/^ *legacyNativeLibraryDir=\\([^ ]*\\).*$/\\1/p' \
      | head -n 1
  )"
  if [[ -n "\$legacy" ]]; then
    echo "\$legacy/\$abi"
    exit 0
  fi

  code_path="\$(
    dumpsys package "\$pkg" 2>/dev/null \
      | tr -d '\r' \
      | sed -n 's/^ *codePath=\\([^ ]*\\).*$/\\1/p' \
      | head -n 1
  )"
  if [[ -n "\$code_path" ]]; then
    echo "\$code_path/lib/\$abi"
    exit 0
  fi
fi

# Fallback: glob common /data/app location.
for d in /data/app/*"\$pkg"*/lib/"\$abi"; do
  if [ -d "\$d" ]; then echo "\$d"; exit 0; fi
done
exit 1
EOF
  )

  # Some su wrappers print env lines to stdout; only accept absolute paths.
  root_exec "$cmd" | tr -d '\r' | grep -E '^/' | head -n 1
}

sync_one_abi() {
  local src_root="$1"
  local abi="$2"
  local mapped
  mapped="$(map_abi_dir "$abi")"

  local device_dir=""
  device_dir="$(pick_device_lib_dir "$mapped" || true)"
  [[ -n "$device_dir" ]] || die "cannot find device native lib dir for ABI '${mapped}' (checked dumpsys nativeLibraryDir, legacyNativeLibraryDir, codePath/lib, and /data/app/*${PKG}*/lib/)"

  local tmp_remote="/data/local/tmp/lws-ui-sync-ai/${abi}"
  root_exec "mkdir -p ${device_dir}"
  root_exec "mkdir -p ${tmp_remote}"

  local n=0
  local has_daemon=0
  shopt -s nullglob
  local so
  for so in "$src_root/$abi/"*.so; do
    n=$((n+1))
    local base
    base="$(basename "$so")"
    if [[ "$base" == "$DAEMON_SO_NAME" ]]; then
      has_daemon=1
    fi
    adb_bin push "$so" "$tmp_remote/$base" >/dev/null
  done
  shopt -u nullglob
  [[ "$n" -gt 0 ]] || die "no .so files found for ABI '$abi' under $src_root/$abi/"
  if [[ "$has_daemon" -ne 1 ]]; then
    die "missing $DAEMON_SO_NAME under $src_root/$abi/ (run 'make ai' to stage the daemon)"
  fi

  root_exec "cp -f ${tmp_remote}/*.so ${device_dir}/"
  # Runtime deps: read-only shared objects.
  root_exec "chmod 0644 ${device_dir}/*.so" >/dev/null 2>&1 || true
  # Daemon is ProcessBuilder-exec'd; must keep +x (AiDaemonBinary.canExecute).
  root_exec "chmod 0755 ${device_dir}/${DAEMON_SO_NAME}" >/dev/null 2>&1 || true
  # Product path no longer loads in-process libai.so — drop stale copies.
  root_exec "rm -f ${device_dir}/libai.so" >/dev/null 2>&1 || true
  root_exec "rm -rf ${tmp_remote}" >/dev/null 2>&1 || true

  echo "OK: synced $n AI libs to $device_dir (daemon +x, removed stale libai.so)" >&2
}

restart_app() {
  echo "INFO: restarting app ${PKG} (Supervisor will re-spawn ${DAEMON_SO_NAME})..." >&2
  adb_bin shell am force-stop "$PKG" >/dev/null 2>&1 || true
  adb_bin shell am start -W -n "${PKG}/${ACTIVITY}" >/dev/null 2>&1 \
    || adb_bin shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
    || die "failed to relaunch app (am start / monkey)"
  echo "OK: app restarted." >&2
}

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"
ensure_root_context

src_root="$(source_lib_root)"
echo "INFO: AI native source: $src_root" >&2

abis=()
if [[ -d "$src_root" ]]; then
  while IFS= read -r d; do
    abis+=("$(basename "$d")")
  done < <(find "$src_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi
[[ "${#abis[@]}" -gt 0 ]] || die "no ABI directories found under $src_root"

for abi in "${abis[@]}"; do
  sync_one_abi "$src_root" "$abi"
done

restart_app
echo "OK: sync-ai complete." >&2
