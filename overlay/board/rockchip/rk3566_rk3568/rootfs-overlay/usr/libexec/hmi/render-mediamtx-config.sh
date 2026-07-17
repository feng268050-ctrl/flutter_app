#!/bin/sh
# Generate /etc/mediamtx/mediamtx.yaml from /oem/etc/model.properties (P5.1).
# Stub: ensure config exists so mediamtx.service can start when enabled.
set -eu

OUT="/etc/mediamtx/mediamtx.yaml"
MODEL="/oem/etc/model.properties"

mkdir -p /etc/mediamtx

if [ -f "$OUT" ]; then
  exit 0
fi

if [ -f /usr/share/lws-hmi/mediamtx.yaml.default ]; then
  cp /usr/share/lws-hmi/mediamtx.yaml.default "$OUT"
  exit 0
fi

# Minimal relay skeleton — replace via render from model.properties in P5.1.
cat >"$OUT" <<'EOF'
# lws-hmi default MediaMTX config (stub). Override via /oem/etc/model.properties.
paths: {}
EOF

if [ -f "$MODEL" ]; then
  echo "# model.properties present at $MODEL — full render TBD (P5.1)" >>"$OUT"
fi
