#!/usr/bin/env bash
# Ensure rockchip-mali matches wayland-gbm for the Weston + eLinux stack.
# Remembers the last successful choice in .cache/lws-mali-variant and skips
# br-make-packages when unchanged *and* weston + flutter-wayland-client exist.
# FORCE=1 always rebuilds.
#
# Usage:
#   bash scripts/ensure-mali-variant.sh wayland-gbm
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESIRED="${1:?usage: ensure-mali-variant.sh <wayland-gbm>}"
FORCE="${FORCE:-0}"
STAMP="$ROOT/.cache/lws-mali-variant"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
TARGET_BIN="buildroot/output/${BR_OUTPUT}/target/usr/bin"

case "$DESIRED" in
wayland-gbm) ;;
gbm)
	echo "ERROR: Mali gbm (flutter-pi) stack was removed; use wayland-gbm" >&2
	exit 2
	;;
*)
	echo "ERROR: variant must be wayland-gbm (got: $DESIRED)" >&2
	exit 2
	;;
esac

mkdir -p "$(dirname "$STAMP")"
CURRENT=""
if [[ -f "$STAMP" ]]; then
	CURRENT="$(tr -d '[:space:]' <"$STAMP" || true)"
fi

target_has() {
	local bin="$1"
	# Docker volume: probe inside the SDK container (skip overlay for speed).
	SKIP_OVERLAY=1 bash "$ROOT/scripts/docker-run.sh" \
		test -x "${TARGET_BIN}/${bin}" >/dev/null 2>&1
}

embedder_ok() {
	target_has weston && target_has flutter-wayland-client
}

if [[ "$FORCE" != "1" && "$CURRENT" == "$DESIRED" ]]; then
	if embedder_ok; then
		echo "ensure-mali-variant: already ${DESIRED} (stamp + embedder) — skip package rebuild"
		exit 0
	fi
	echo "ensure-mali-variant: stamp ${DESIRED} but embedder missing in target — reinstall"
	bash "$ROOT/scripts/br-make-packages.sh" ensure-weston \
		weston flutter-embedded-linux
	exit 0
fi

if [[ -n "$CURRENT" && "$CURRENT" != "$DESIRED" ]]; then
	echo "ensure-mali-variant: ${CURRENT} → ${DESIRED} (rebuilding packages)"
elif [[ "$FORCE" == "1" ]]; then
	echo "ensure-mali-variant: FORCE=1 → rebuild for ${DESIRED}"
else
	echo "ensure-mali-variant: no stamp → rebuild for ${DESIRED}"
fi

bash "$ROOT/scripts/br-make-packages.sh" weston-img \
	rockchip-mali wayland wayland-protocols weston flutter-embedded-linux

printf '%s\n' "$DESIRED" >"$STAMP"
echo "ensure-mali-variant: stamped ${DESIRED} → $STAMP"
