#!/usr/bin/env bash
# Keep the Rockchip SDK on a Docker volume (ext4 inside the VM) instead of a
# macOS bind mount. Buildroot generates huge numbers of small files; virtiofs
# often crashes Docker Desktop long before memory limits are hit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/scripts/require-macos.sh"

IMAGE="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
VOLUME="${DOCKER_VOLUME:-lws-hmi-sdk}"
HOST_SDK="$ROOT/linux-sdk"
LOG_DIR="$ROOT/.cache"
RSYNC_LOG="$LOG_DIR/docker-volume-rsync.log"

resolve_host_sdk() {
  if [[ -n "${HOST_SDK:-}" ]]; then
    echo "$HOST_SDK"
    return 0
  fi
  echo "$ROOT/linux-sdk"
}

HOST_SDK="$(resolve_host_sdk)"

require_host_sdk() {
  if [[ ! -d "$HOST_SDK" ]]; then
    echo "ERROR: host SDK not found at $HOST_SDK" >&2
    exit 1
  fi
}

require_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running." >&2
    exit 1
  fi
}

volume_mark() {
  echo "/work/sdk/.lws-hmi-volume-initialized"
}

# Vendor tools symlink into rockdev/, which is created on first build.
prepare_host_sdk() {
  mkdir -p "$HOST_SDK/rockdev"
}

verify_volume_sdk() {
  docker run --rm --platform "$PLATFORM" \
    -v "$VOLUME:/work/sdk" \
    "$IMAGE" \
    bash -c 'test -x /work/sdk/build.sh \
      && test -d /work/sdk/buildroot \
      && test -d /work/sdk/device/rockchip \
      && test -d /work/sdk/kernel'
}

volume_has_sdk_tree() {
  verify_volume_sdk >/dev/null 2>&1
}

run_tar_to_volume() {
  echo "Streaming SDK into volume with tar (no rsync xattr/symlink quirks) ..."
  docker run --rm --platform "$PLATFORM" \
    -v "$VOLUME:/work/sdk" \
    -v "$HOST_SDK:/src:ro" \
    "$IMAGE" \
    bash -c 'set -euo pipefail
      cd /src
      tar \
        --checkpoint=10000 \
        --checkpoint-action=echo="  ... archived %u files" \
        -cf - . \
      | tar -C /work/sdk -xf -
    '
}

run_rsync_to_volume() {
  local mode="${1:-incremental}"
  mkdir -p "$LOG_DIR"
  local -a rsync_args=(
    -rlptD
    --no-xattrs
    --omit-dir-times
    --no-owner
    --no-group
    --info=progress2
    --human-readable
    --log-file=/cache/rsync.log
  )
  if [[ "$mode" == "incremental" ]]; then
    rsync_args+=(
      --exclude output/
      --exclude buildroot/output/
      --exclude buildroot/dl/
      --exclude .lws-hmi-volume-initialized
    )
  fi

  set +e
  docker run --rm --platform "$PLATFORM" \
    -v "$VOLUME:/work/sdk" \
    -v "$HOST_SDK:/src:ro" \
    -v "$LOG_DIR:/cache" \
    "$IMAGE" \
    rsync "${rsync_args[@]}" /src/ /work/sdk/
  local rc=$?
  set -e

  if [[ -f "$RSYNC_LOG" ]]; then
    if grep -E 'rsync:|error' "$RSYNC_LOG" | tail -20 | grep -qv '^$'; then
      echo "rsync log (last issues):"
      grep -E 'rsync:|error|failed|referent' "$RSYNC_LOG" | tail -20 || true
    fi
  fi

  if [[ $rc -eq 0 ]]; then
    return 0
  fi
  if [[ $rc -eq 23 ]] && volume_has_sdk_tree; then
    echo "WARNING: rsync exit 23 (some macOS attrs/symlinks skipped) but SDK core is present; continuing."
    return 0
  fi
  echo "ERROR: rsync failed with exit code $rc" >&2
  return "$rc"
}

mark_volume_initialized() {
  docker run --rm --platform "$PLATFORM" \
    -v "$VOLUME:/work/sdk" \
    "$IMAGE" \
    touch "$(volume_mark)"
}

apply_overlay_in_volume() {
  docker run --rm --platform "$PLATFORM" \
    -v "$ROOT:/work/lws-hmi" \
    -v "$VOLUME:/work/sdk" \
    -e DOCKER=1 \
    -e SDK_DIR=/work/sdk \
    -w /work/lws-hmi \
    "$IMAGE" \
    bash /work/lws-hmi/scripts/apply-overlay.sh
}

finish_init() {
  if ! verify_volume_sdk; then
    echo "ERROR: volume copy looks incomplete (missing build.sh / buildroot / kernel)." >&2
    exit 1
  fi
  mark_volume_initialized
  apply_overlay_in_volume
  echo "Volume '$VOLUME' ready. Builds now use /work/sdk inside the Docker VM."
}

cmd_init() {
  require_docker
  require_host_sdk
  prepare_host_sdk
  docker volume create "$VOLUME" >/dev/null 2>&1 || true

  if volume_has_sdk_tree; then
    echo "SDK tree already present in volume '$VOLUME'; skipping copy."
    finish_init
    return 0
  fi

  echo "Copying SDK into Docker volume '$VOLUME' (first run can take 10–30 min) ..."
  echo "Source: $HOST_SDK"
  run_tar_to_volume
  finish_init
}

cmd_sync() {
  require_docker
  require_host_sdk
  prepare_host_sdk
  if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
    echo "Volume '$VOLUME' missing. Run: make docker-volume-init" >&2
    exit 1
  fi
  echo "Syncing host SDK changes into volume (keeping buildroot/output, dl, output) ..."
  run_rsync_to_volume incremental
  apply_overlay_in_volume
}

cmd_pull() {
	# Legacy name — publish firmware to repo-root output/firmware/ only.
	bash "$ROOT/scripts/docker-export-artifacts.sh" firmware
}

cmd_export() {
	local scope="${1:-firmware}"
	bash "$ROOT/scripts/docker-export-artifacts.sh" "$scope"
}

cmd_status() {
  require_docker
  if docker volume inspect "$VOLUME" >/dev/null 2>&1; then
    echo "volume: $VOLUME (exists)"
    docker run --rm --platform "$PLATFORM" \
      -v "$VOLUME:/work/sdk" \
      "$IMAGE" \
      bash -lc 'du -sh /work/sdk /work/sdk/buildroot/output /work/sdk/buildroot/dl /work/sdk/output 2>/dev/null || true'
    if volume_has_sdk_tree; then
      echo "sdk tree: OK (build.sh, buildroot, kernel present)"
    else
      echo "sdk tree: incomplete — run make docker-volume-init"
    fi
  else
    echo "volume: $VOLUME (not created — run: make docker-volume-init)"
  fi
  echo "host SDK: $HOST_SDK"
}

ensure_volume_ready() {
  require_docker
  if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: Docker volume '$VOLUME' is not initialized.

On macOS, bind-mounting the SDK from APFS often crashes Docker Desktop during
Buildroot. Initialize a volume first:

  make docker-volume-init

Then retry your build.
EOF
    exit 1
  fi
  if ! docker run --rm --platform "$PLATFORM" \
    -v "$VOLUME:/work/sdk" \
    "$IMAGE" \
    test -f "$(volume_mark)"; then
    if volume_has_sdk_tree; then
      echo "Volume has SDK tree but was not marked initialized; finishing init ..."
      finish_init
      return 0
    fi
    echo "ERROR: volume '$VOLUME' exists but is not initialized. Run: make docker-volume-init" >&2
    exit 1
  fi
}

case "${1:-}" in
  --print-volume) echo "$VOLUME" ;;
  --print-host-sdk) echo "$HOST_SDK" ;;
  init) cmd_init ;;
  sync) cmd_sync ;;
  pull) cmd_pull ;;
  export) cmd_export "${2:-firmware}" ;;
  status) cmd_status ;;
  ensure-ready) ensure_volume_ready ;;
  *)
    echo "Usage: $0 {init|sync|export|pull|status|ensure-ready}" >&2
    exit 1
    ;;
esac
