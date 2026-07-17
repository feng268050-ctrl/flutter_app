#!/usr/bin/env bash
# Apply Innohi MainServer skip to build-hooks/30-rootfs.sh (if not same file as mk-rootfs.sh).
set -euo pipefail

target="$1"
ROOT_PATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$ROOT_PATCH/lws-hmi-patch-innohi-mainserver.sh" "$target"
