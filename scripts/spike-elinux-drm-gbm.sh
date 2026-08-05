#!/usr/bin/env bash
# E0 spike: cross-compile Sony flutter-embedded-linux DRM-GBM runner against
# our Flutter 3.41.9 engine, using Buildroot staging as sysroot.
#
# Usage:
#   bash scripts/spike-elinux-drm-gbm.sh           # build
#   bash scripts/spike-elinux-drm-gbm.sh push      # scp binary to board /userdata/elinux-spike/
#   bash scripts/spike-elinux-drm-gbm.sh run       # stop hmi, launch spike against /opt/hmi
#   bash scripts/spike-elinux-drm-gbm.sh restore   # restart hmi.service
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPIKE_CACHE="${SPIKE_CACHE:-$ROOT/.cache/elinux-spike}"
SRC="$SPIKE_CACHE/flutter-embedded-linux"
OUT="$SPIKE_CACHE/out-drm-gbm"
TAG="${ELINUX_TAG:-42d3d75a56}"
REPO="${ELINUX_REPO:-https://github.com/flutter-elinux/flutter-embedded-linux.git}"
ENGINE_SO="$ROOT/prebuilt/flutter-engine/3.41.9/arm64-release/target/usr/lib/libflutter_engine.so"

IFACE="${IFACE:-en12}"
ADDR="${USB_SSH_ADDR:-192.168.55.1}"
USER_="${USB_SSH_USER:-root}"
PASS="${USB_SSH_PASS:-rockchip}"
REMOTE_DIR="${REMOTE_DIR:-/userdata/elinux-spike}"

SSH() {
  sshpass -p "$PASS" ssh \
    -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -o BindInterface="$IFACE" -o ServerAliveInterval=3 -o ServerAliveCountMax=3 \
    "$USER_@$ADDR" "$@"
}

ensure_src() {
  if [[ ! -d "$SRC/.git" ]]; then
    echo "spike-elinux: cloning $REPO @ $TAG ..."
    mkdir -p "$SPIKE_CACHE"
    git clone --depth 1 --branch "$TAG" "$REPO" "$SRC"
  fi
  if [[ ! -f "$ENGINE_SO" ]]; then
    echo "ERROR: missing $ENGINE_SO (run: make build-flutter-engine)" >&2
    exit 1
  fi
  # Idempotent present-FPS instrumentation for E0.5 seal.
  local patch="$ROOT/scripts/spike-elinux-present-fps.patch"
  if [[ -f "$patch" ]] && ! grep -q 'NotePresentSuccess' \
      "$SRC/src/flutter/shell/platform/linux_embedded/surface/elinux_egl_surface.cc"; then
    git -C "$SRC" apply "$patch"
    echo "spike-elinux: applied present-FPS patch"
  fi
}

cmd_build() {
  ensure_src
  mkdir -p "$OUT"

  echo "spike-elinux: cross-compiling DRM-GBM runner in Docker ..."
  bash "$ROOT/scripts/docker-run.sh" bash -lc "
    set -euo pipefail
    OUT_BR=/work/sdk/buildroot/output/rockchip_rk3566_rk3568_lws_hmi
    HOST=\$OUT_BR/host
    STAGING=\$OUT_BR/staging
    SRC=/work/lws-hmi/.cache/elinux-spike/flutter-embedded-linux
    BUILD=/work/lws-hmi/.cache/elinux-spike/out-drm-gbm/cmake-build
    TOOLCHAIN=/work/lws-hmi/.cache/elinux-spike/out-drm-gbm/aarch64-toolchain.cmake
    ENGINE_SO=/work/lws-hmi/prebuilt/flutter-engine/3.41.9/arm64-release/target/usr/lib/libflutter_engine.so

    export PATH=\"\$HOST/bin:\$PATH\"
    export PKG_CONFIG=\"\$HOST/bin/pkg-config\"
    export PKG_CONFIG_SYSROOT_DIR=\"\$STAGING\"
    export PKG_CONFIG_LIBDIR=\"\$STAGING/usr/lib/pkgconfig:\$STAGING/usr/share/pkgconfig\"
    export PKG_CONFIG_PATH=\"\$PKG_CONFIG_LIBDIR\"

    # CMake links against \$SRC/build/libflutter_engine.so (path relative to source tree).
    mkdir -p \"\$SRC/build\"
    ln -sfn \"\$ENGINE_SO\" \"\$SRC/build/libflutter_engine.so\"
    test -e \"\$SRC/build/libflutter_engine.so\"

    cat > \"\$TOOLCHAIN\" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-none-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-none-linux-gnu-g++)
set(CMAKE_SYSROOT \"\$STAGING\")
set(CMAKE_FIND_ROOT_PATH \"\$STAGING\" \"\$HOST\")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

    rm -rf \"\$BUILD\"
    mkdir -p \"\$BUILD\"
    cd \"\$BUILD\"
    # (DRM-GBM). ENABLE_VSYNC here is the embedder CMake option (Sony default OFF;
    # ON wires FlutterEngineOnVsync — critical for frame pacing on DRM).
    VSYNC_OPT=\"\${ENABLE_VSYNC:-ON}\"
    cmake \
      -DCMAKE_TOOLCHAIN_FILE=\"\$TOOLCHAIN\" \
      -DCMAKE_BUILD_TYPE=Release \
      -DFLUTTER_RELEASE=ON \
      -DUSER_PROJECT_PATH=examples/flutter-drm-gbm-backend \
      -DENABLE_VSYNC=\$VSYNC_OPT \
      \"\$SRC\"
    cmake --build . -j\"\${BUILD_JOBS:-8}\"

    install -D -m 0755 flutter-drm-gbm-backend \
      /work/lws-hmi/.cache/elinux-spike/out-drm-gbm/flutter-drm-gbm-backend
    cp -a /work/lws-hmi/.cache/elinux-spike/out-drm-gbm/flutter-drm-gbm-backend \
      /work/lws-hmi/.cache/elinux-spike/out-drm-gbm/flutter-drm-gbm-backend.vsync-\${VSYNC_OPT}
    aarch64-none-linux-gnu-strip \
      /work/lws-hmi/.cache/elinux-spike/out-drm-gbm/flutter-drm-gbm-backend || true
    file /work/lws-hmi/.cache/elinux-spike/out-drm-gbm/flutter-drm-gbm-backend
    echo \"spike-elinux: ENABLE_VSYNC=\$VSYNC_OPT\"
  "

  echo "spike-elinux: binary at $OUT/flutter-drm-gbm-backend"
}

cmd_push() {
  local bin="$OUT/flutter-drm-gbm-backend"
  [[ -x "$bin" ]] || { echo "ERROR: missing $bin — run build first" >&2; exit 1; }
  echo "spike-elinux: pushing to $USER_@$ADDR:$REMOTE_DIR ..."
  SSH "mkdir -p '$REMOTE_DIR'"
  # scp auth is flaky on this USB-SSH path; stream via ssh stdin instead.
  SSH "cat > '$REMOTE_DIR/flutter-drm-gbm-backend' && chmod +x '$REMOTE_DIR/flutter-drm-gbm-backend' && ls -la '$REMOTE_DIR'" <"$bin"
}

cmd_run() {
  local rotation="${1:-90}"
  echo "spike-elinux: stopping hmi.service and launching DRM-GBM runner ..."
  SSH "systemctl stop hmi.service 2>/dev/null || true
    # Ensure icudtl is visible to the runner (eLinux looks under bundle/data/).
    if [[ ! -f /opt/hmi/data/icudtl.dat ]]; then
      mkdir -p /opt/hmi/data
      for p in /usr/share/flutter/release/data/icudtl.dat /usr/share/flutter/icudtl.dat /usr/lib/icudtl.dat; do
        if [[ -e \$p ]]; then cp -L \$p /opt/hmi/data/icudtl.dat; break; fi
      done
    fi
    # Drop a broken symlink left by an earlier spike attempt.
    if [[ -L /opt/hmi/data/icudtl.dat && ! -e /opt/hmi/data/icudtl.dat ]]; then
      rm -f /opt/hmi/data/icudtl.dat
      cp -L /usr/share/flutter/release/data/icudtl.dat /opt/hmi/data/icudtl.dat
    fi
    true # flutter-pi removed 2>/dev/null || true
    pkill -9 -x flutter-drm-gbm-backend 2>/dev/null || true
    sleep 1
    # Ensure no stale DRM clients before claiming card0.
    if pidof flutter-drm-gbm-backend >/dev/null 2>&1 >/dev/null 2>&1; then
      echo 'ERROR: could not stop previous Flutter DRM client' >&2
      exit 1
    fi
    cd '$REMOTE_DIR'
    # Default vsync ON (omit --async-vblank). Rotation matches lcd0_rotation=90.
    nohup env FLUTTER_DRM_DEVICE=/dev/dri/card0 \
      ./flutter-drm-gbm-backend --bundle=/opt/hmi --rotation=$rotation \
      >'$REMOTE_DIR/run.log' 2>&1 &
    echo \$! >'$REMOTE_DIR/run.pid'
    sleep 1
    if kill -0 \$(cat '$REMOTE_DIR/run.pid') 2>/dev/null; then
      echo \"spike running pid=\$(cat '$REMOTE_DIR/run.pid')\"
      tail -n 40 '$REMOTE_DIR/run.log' || true
    else
      echo 'ERROR: spike exited immediately:' >&2
      cat '$REMOTE_DIR/run.log' >&2 || true
      exit 1
    fi
  "
}

cmd_restore() {
  echo "spike-elinux: restoring hmi.service ..."
  SSH "pkill -x flutter-drm-gbm-backend 2>/dev/null || true
    systemctl start hmi.service
    systemctl is-active hmi.service"
}

cmd="${1:-build}"
case "$cmd" in
  build) cmd_build ;;
  push) cmd_push ;;
  run) shift; cmd_run "$@" ;;
  restore) cmd_restore ;;
  *)
    echo "usage: $0 {build|push|run [rotation]|restore}" >&2
    exit 2
    ;;
esac
