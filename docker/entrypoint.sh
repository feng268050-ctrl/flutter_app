#!/usr/bin/env bash
set -euo pipefail

export LWS_HMI_DOCKER=1

# Rockchip SDK scripts call $(nproc) for -j flags. Cap parallelism to reduce
# memory spikes (especially under linux/amd64 emulation on Apple Silicon).
LWS_HMI_JOBS="${LWS_HMI_JOBS:-4}"
mkdir -p /usr/local/lws-hmi-bin
cat > /usr/local/lws-hmi-bin/nproc <<EOF
#!/bin/sh
echo ${LWS_HMI_JOBS}
EOF
chmod +x /usr/local/lws-hmi-bin/nproc
export PATH="/usr/local/lws-hmi-bin:${PATH}"
export MAKEFLAGS="-j${LWS_HMI_JOBS} ${MAKEFLAGS:-}"

if [[ -d /work/sdk ]]; then
  cd /work/sdk
fi

if [[ $# -eq 0 ]]; then
  exec bash -l
fi
exec "$@"
