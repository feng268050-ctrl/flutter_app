#!/usr/bin/env bash
# Cross-compile Sony flutter-embedded-linux Wayland client → prebuilt/.
# Requires wayland in Buildroot staging (chips/lws_hmi_wayland.config once).
#
# Usage:
#   make build-flutter-embedded-linux
#   FORCE=1 make rebuild-flutter-embedded-linux
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/buildroot/flutter-embedded-linux.version"
VERSION="$(read_version_file "$VERSION_FILE" "db49896cf2")"
REPO="${ELINUX_REPO:-https://github.com/sony/flutter-embedded-linux.git}"
FORCE="${FORCE:-0}"

CACHE="$ROOT/.cache/flutter-embedded-linux"
SRC="$CACHE/src"
BUILD_HOST="$CACHE/out-wayland"
PREBUILT="$ROOT/prebuilt/flutter-embedded-linux/${VERSION}"

ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.24.4")"
RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"
ENGINE_SO="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}/target/usr/lib/libflutter_engine.so"
# Some exports place the .so at the prebuilt root.
if [[ ! -f "$ENGINE_SO" ]]; then
  ENGINE_SO="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}/libflutter_engine.so"
fi

if prebuilt_ready "$PREBUILT" && [[ "$FORCE" != "1" ]]; then
  echo "flutter-embedded-linux: prebuilt ready at $PREBUILT"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$BUILD_HOST" "$PREBUILT"
fi

if [[ ! -f "$ENGINE_SO" ]]; then
  echo "ERROR: missing flutter engine at $ENGINE_SO" >&2
  echo "  Run: make build-flutter-engine" >&2
  exit 1
fi

if [[ ! -d "$SRC/.git" ]]; then
  echo "flutter-embedded-linux: cloning $REPO @ $VERSION ..."
  mkdir -p "$CACHE"
  git clone --depth 1 --branch "$VERSION" "$REPO" "$SRC"
fi

echo "flutter-embedded-linux: cross-compiling Wayland client (ENABLE_VSYNC=ON) ..."
bash "$ROOT/scripts/docker-run.sh" bash -lc "
  set -euo pipefail
  OUT_BR=/work/sdk/buildroot/output/rockchip_rk3566_rk3568_lws_hmi
  HOST=\$OUT_BR/host
  STAGING=\$OUT_BR/staging
  SRC=/work/lws-hmi/.cache/flutter-embedded-linux/src
  BUILD=/work/lws-hmi/.cache/flutter-embedded-linux/out-wayland/cmake-build
  TOOLCHAIN=/work/lws-hmi/.cache/flutter-embedded-linux/out-wayland/aarch64-toolchain.cmake
  ENGINE_SO=/work/lws-hmi/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}/target/usr/lib/libflutter_engine.so
  if [[ ! -f \"\$ENGINE_SO\" ]]; then
    ENGINE_SO=/work/lws-hmi/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}/libflutter_engine.so
  fi

  export PATH=\"\$HOST/bin:\$PATH\"
  export PKG_CONFIG=\"\$HOST/bin/pkg-config\"
  export PKG_CONFIG_SYSROOT_DIR=\"\$STAGING\"
  export PKG_CONFIG_LIBDIR=\"\$STAGING/usr/lib/pkgconfig:\$STAGING/usr/share/pkgconfig\"
  export PKG_CONFIG_PATH=\"\$PKG_CONFIG_LIBDIR\"

  for pc in wayland-client wayland-cursor wayland-egl wayland-protocols; do
    if ! pkg-config --exists \"\$pc\"; then
      echo \"ERROR: staging missing \$pc — build weston pkgs once:\" >&2
      echo \"  LWS_HMI_WESTON=1 make apply-overlay\" >&2
      echo \"  bash scripts/br-make-packages.sh wayland-deps wayland wayland-protocols\" >&2
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
  cmake \\
    -DCMAKE_TOOLCHAIN_FILE=\"\$TOOLCHAIN\" \\
    -DCMAKE_BUILD_TYPE=Release \\
    -DFLUTTER_RELEASE=ON \\
    -DUSER_PROJECT_PATH=examples/flutter-wayland-client \\
    -DENABLE_VSYNC=ON \\
    \"\$SRC\"
  cmake --build . -j\"\${BUILD_JOBS:-8}\"

  BIN=\"\"
  for cand in flutter-client flutter-wayland-client; do
    if [[ -x ./\$cand ]]; then BIN=./\$cand; break; fi
  done
  test -n \"\$BIN\"
  install -D -m 0755 \"\$BIN\" \\
    /work/lws-hmi/.cache/flutter-embedded-linux/out-wayland/flutter-wayland-client
  aarch64-none-linux-gnu-strip \\
    /work/lws-hmi/.cache/flutter-embedded-linux/out-wayland/flutter-wayland-client || true
  file /work/lws-hmi/.cache/flutter-embedded-linux/out-wayland/flutter-wayland-client
"

STAGE="$CACHE/prebuilt-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/usr/bin"
install -D -m 0755 "$BUILD_HOST/flutter-wayland-client" \
  "$STAGE/usr/bin/flutter-wayland-client"
prebuilt_install_tree "$STAGE" "$PREBUILT" "$VERSION"
echo "flutter-embedded-linux: prebuilt at $PREBUILT"
