#!/usr/bin/env bash
# Shared build environment: cap $(nproc) and make -j for Rockchip SDK scripts.
# Sourced by docker/entrypoint.sh (container) and scripts/native-run.sh (Linux host).

setup_build_env() {
  BUILD_JOBS="${BUILD_JOBS:-8}"
  export BUILD_JOBS

  local nproc_wrapper_dir="${LWS_HMI_NPROC_BIN:-/tmp/lws-hmi-nproc-$$}"
  mkdir -p "$nproc_wrapper_dir"
  cat > "$nproc_wrapper_dir/nproc" <<EOF
#!/bin/sh
echo ${BUILD_JOBS}
EOF
  chmod +x "$nproc_wrapper_dir/nproc"
  export PATH="${nproc_wrapper_dir}:${PATH}"
  # Global MAKEFLAGS=-jN enables a GNU make jobserver that breaks nested invocations
  # (busybox kconfig, cmake) inside Docker Buildroot. Parallelism instead comes from
  # Rockchip build.sh -j (via capped nproc) and BR2_JLEVEL in lws_hmi_build.config.
  if [[ "${LWS_HMI_NO_MAKEFLAGS:-}" == "1" || "${LWS_HMI_DOCKER:-}" == "1" ]]; then
    unset MAKEFLAGS
  else
    export MAKEFLAGS="-j${BUILD_JOBS} ${MAKEFLAGS:-}"
  fi

  # linux/amd64 Docker on macOS: curl ALPN/HTTP2 TLS fails with "unexpected eof".
  # cipd (gclient, gn/vpython3) uses curl; force HTTP/1.1 without ALPN.
  if [[ "${LWS_HMI_DOCKER:-}" == "1" || -f /.dockerenv ]]; then
    local curl_home="${LWS_HMI_ROOT:-/work/lws-hmi}/.cache/curl-home"
    mkdir -p "$curl_home"
    if [[ ! -f "$curl_home/.curlrc" ]]; then
      printf '%s\n' '--http1.1' '--no-alpn' >"$curl_home/.curlrc"
    fi
    export CURL_HOME="$curl_home"
  fi
}
