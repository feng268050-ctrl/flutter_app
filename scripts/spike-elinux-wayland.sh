#!/usr/bin/env bash
# E0.5 spike: cross-compile Sony flutter-embedded-linux Wayland runner.
# Requires wayland (+ protocols) in Buildroot staging (see chips/lws_hmi_wayland.config).
#
# Usage:
#   bash scripts/spike-elinux-wayland.sh build
#   bash scripts/spike-elinux-wayland.sh push
#   bash scripts/spike-elinux-wayland.sh run     # expects Weston already running
#   bash scripts/spike-elinux-wayland.sh restore
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPIKE_CACHE="${SPIKE_CACHE:-$ROOT/.cache/elinux-spike}"
SRC="$SPIKE_CACHE/flutter-embedded-linux"
OUT="$SPIKE_CACHE/out-wayland"
TAG="${ELINUX_TAG:-42d3d75a56}"
REPO="${ELINUX_REPO:-https://github.com/flutter-elinux/flutter-embedded-linux.git}"

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
    mkdir -p "$SPIKE_CACHE"
    git clone --depth 1 --branch "$TAG" "$REPO" "$SRC"
  fi
  local patch="$ROOT/scripts/spike-elinux-present-fps.patch"
  if [[ -f "$patch" ]] && ! grep -q 'NotePresentSuccess' \
      "$SRC/src/flutter/shell/platform/linux_embedded/surface/elinux_egl_surface.cc"; then
    git -C "$SRC" apply "$patch"
    echo "spike-elinux-wayland: applied present-FPS patch"
  fi
}

cmd_build() {
  ensure_src
  mkdir -p "$OUT"
  echo "spike-elinux-wayland: cross-compiling Wayland runner in Docker ..."
  bash "$ROOT/scripts/docker-run.sh" bash -lc "
    set -euo pipefail
    OUT_BR=/work/sdk/buildroot/output/rockchip_rk3566_rk3568_lws_hmi
    HOST=\$OUT_BR/host
    STAGING=\$OUT_BR/staging
    SRC=/work/lws-hmi/.cache/elinux-spike/flutter-embedded-linux
    BUILD=/work/lws-hmi/.cache/elinux-spike/out-wayland/cmake-build
    TOOLCHAIN=/work/lws-hmi/.cache/elinux-spike/out-wayland/aarch64-toolchain.cmake
    ENGINE_SO=/work/lws-hmi/prebuilt/flutter-engine/3.41.9/arm64-release/target/usr/lib/libflutter_engine.so

    export PATH=\"\$HOST/bin:\$PATH\"
    export PKG_CONFIG=\"\$HOST/bin/pkg-config\"
    export PKG_CONFIG_SYSROOT_DIR=\"\$STAGING\"
    export PKG_CONFIG_LIBDIR=\"\$STAGING/usr/lib/pkgconfig:\$STAGING/usr/share/pkgconfig\"
    export PKG_CONFIG_PATH=\"\$PKG_CONFIG_LIBDIR\"

    for pc in wayland-client wayland-cursor wayland-egl wayland-protocols; do
      if ! pkg-config --exists \"\$pc\"; then
        echo \"ERROR: staging missing \$pc — enable chips/lws_hmi_wayland.config and rebuild packages\" >&2
        exit 1
      fi
    done

    mkdir -p \"\$SRC/build\"
    ln -sfn \"\$ENGINE_SO\" \"\$SRC/build/libflutter_engine.so\"

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
    VSYNC_OPT=\"\${ENABLE_VSYNC:-ON}\"
    # user_config for wayland example sets BACKEND_TYPE=WAYLAND
    cmake \
      -DCMAKE_TOOLCHAIN_FILE=\"\$TOOLCHAIN\" \
      -DCMAKE_BUILD_TYPE=Release \
      -DFLUTTER_RELEASE=ON \
      -DUSER_PROJECT_PATH=examples/flutter-wayland-client \
      -DENABLE_VSYNC=\$VSYNC_OPT \
      \"\$SRC\"
    cmake --build . -j\"\${BUILD_JOBS:-8}\"

    # Example binary name from user_build.cmake (flutter-wayland-client → TARGET flutter-client)
    BIN=""
    for cand in flutter-client flutter-wayland-client; do
      if [[ -x ./\$cand ]]; then BIN=./\$cand; break; fi
    done
    test -n \"\$BIN\"
    install -D -m 0755 \"\$BIN\" \
      /work/lws-hmi/.cache/elinux-spike/out-wayland/flutter-wayland-client
    aarch64-none-linux-gnu-strip \
      /work/lws-hmi/.cache/elinux-spike/out-wayland/flutter-wayland-client || true
    file /work/lws-hmi/.cache/elinux-spike/out-wayland/flutter-wayland-client
    echo \"spike-elinux-wayland: ENABLE_VSYNC=\$VSYNC_OPT\"
  "
  echo "spike-elinux-wayland: binary at $OUT/flutter-wayland-client"
}

cmd_push() {
  local bin="$OUT/flutter-wayland-client"
  [[ -x "$bin" ]] || { echo "ERROR: missing $bin — run build first" >&2; exit 1; }
  SSH "mkdir -p '$REMOTE_DIR'"
  SSH "cat > '$REMOTE_DIR/flutter-wayland-client' && chmod +x '$REMOTE_DIR/flutter-wayland-client' && ls -la '$REMOTE_DIR'" <"$bin"
}

cmd_run() {
  local rotation="${1:-90}"
  echo "spike-elinux-wayland: launching Wayland client (Weston must be up) ..."
  SSH "systemctl stop hmi.service 2>/dev/null || true
    true # flutter-pi removed 2>/dev/null || true
    pkill -9 -x flutter-drm-gbm-backend 2>/dev/null || true
    pkill -9 -x flutter-wayland-client 2>/dev/null || true
    sleep 1
    if [[ ! -f /opt/hmi/data/icudtl.dat ]]; then
      mkdir -p /opt/hmi/data
      cp -L /usr/share/flutter/release/data/icudtl.dat /opt/hmi/data/icudtl.dat
    fi
    if [[ -z \"\${WAYLAND_DISPLAY:-}\" ]]; then
      export WAYLAND_DISPLAY=wayland-0
    fi
    if [[ ! -S /run/\${XDG_RUNTIME_DIR#/run/}/\$WAYLAND_DISPLAY && ! -S \$XDG_RUNTIME_DIR/\$WAYLAND_DISPLAY ]]; then
      # Common Weston sockets
      for d in /run /tmp /var/run; do
        if [[ -S \$d/wayland-0 ]]; then export XDG_RUNTIME_DIR=\$d; export WAYLAND_DISPLAY=wayland-0; break; fi
      done
    fi
    cd '$REMOTE_DIR'
    nohup env XDG_RUNTIME_DIR=\${XDG_RUNTIME_DIR:-/run} WAYLAND_DISPLAY=\${WAYLAND_DISPLAY:-wayland-0} \
      ./flutter-wayland-client --bundle=/opt/hmi --rotation=$rotation --fullscreen \
      >'$REMOTE_DIR/wayland-run.log' 2>&1 &
    echo \$! >'$REMOTE_DIR/wayland-run.pid'
    sleep 1
    if kill -0 \$(cat '$REMOTE_DIR/wayland-run.pid') 2>/dev/null; then
      echo \"spike wayland pid=\$(cat '$REMOTE_DIR/wayland-run.pid')\"
      tail -n 40 '$REMOTE_DIR/wayland-run.log' || true
    else
      echo 'ERROR: wayland client exited:' >&2
      cat '$REMOTE_DIR/wayland-run.log' >&2 || true
      exit 1
    fi
  "
}

cmd_restore() {
  SSH "pkill -9 -x flutter-wayland-client 2>/dev/null || true
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
