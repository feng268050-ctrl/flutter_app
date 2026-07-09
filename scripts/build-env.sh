#!/usr/bin/env bash
# Shared build environment: cap $(nproc) and make -j for Rockchip SDK scripts.
# Sourced by docker/entrypoint.sh (container) and scripts/native-run.sh (Linux host).

setup_build_env() {
  BUILD_JOBS="${BUILD_JOBS:-4}"
  export BUILD_JOBS

  local nproc_wrapper_dir="${LWS_HMI_NPROC_BIN:-/tmp/lws-hmi-nproc-$$}"
  mkdir -p "$nproc_wrapper_dir"
  cat > "$nproc_wrapper_dir/nproc" <<EOF
#!/bin/sh
echo ${BUILD_JOBS}
EOF
  chmod +x "$nproc_wrapper_dir/nproc"
  export PATH="${nproc_wrapper_dir}:${PATH}"
  export MAKEFLAGS="-j${BUILD_JOBS} ${MAKEFLAGS:-}"
}
