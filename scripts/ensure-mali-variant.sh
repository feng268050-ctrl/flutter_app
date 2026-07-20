#!/usr/bin/env bash
# Ensure rockchip-mali matches the requested variant (gbm vs wayland-gbm).
# Remembers the last successful choice in .cache/lws-mali-variant and skips
# br-make-packages when unchanged *and* the expected embedder binary is present.
# FORCE=1 always rebuilds.
#
# Cross-image note: post-build purges the opposite embedder from target/. Buildroot
# stamps still think the package is installed, so switching back must reinstall
# flutter-pi (gbm) or weston+client (wayland-gbm).
#
# Usage:
#   bash scripts/ensure-mali-variant.sh gbm
#   bash scripts/ensure-mali-variant.sh wayland-gbm
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESIRED="${1:?usage: ensure-mali-variant.sh <gbm|wayland-gbm>}"
FORCE="${FORCE:-0}"
STAMP="$ROOT/.cache/lws-mali-variant"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
TARGET_BIN="buildroot/output/${BR_OUTPUT}/target/usr/bin"

case "$DESIRED" in
gbm|wayland-gbm) ;;
*)
	echo "ERROR: variant must be gbm or wayland-gbm (got: $DESIRED)" >&2
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
	LWS_HMI_SKIP_OVERLAY=1 bash "$ROOT/scripts/docker-run.sh" \
		test -x "${TARGET_BIN}/${bin}" >/dev/null 2>&1
}

embedder_ok() {
	if [[ "$DESIRED" == "gbm" ]]; then
		target_has flutter-pi
	else
		target_has weston && target_has flutter-wayland-client
	fi
}

if [[ "$FORCE" != "1" && "$CURRENT" == "$DESIRED" ]]; then
	if embedder_ok; then
		echo "ensure-mali-variant: already ${DESIRED} (stamp + embedder) — skip package rebuild"
		exit 0
	fi
	echo "ensure-mali-variant: stamp ${DESIRED} but embedder missing in target — reinstall"
	if [[ "$DESIRED" == "gbm" ]]; then
		bash "$ROOT/scripts/br-make-packages.sh" ensure-pi flutter-pi
	else
		bash "$ROOT/scripts/br-make-packages.sh" ensure-weston \
			weston flutter-embedded-linux
	fi
	exit 0
fi

if [[ -n "$CURRENT" && "$CURRENT" != "$DESIRED" ]]; then
	echo "ensure-mali-variant: ${CURRENT} → ${DESIRED} (rebuilding packages)"
elif [[ "$FORCE" == "1" ]]; then
	echo "ensure-mali-variant: FORCE=1 → rebuild for ${DESIRED}"
else
	echo "ensure-mali-variant: no stamp → rebuild for ${DESIRED}"
fi

if [[ "$DESIRED" == "wayland-gbm" ]]; then
	bash "$ROOT/scripts/br-make-packages.sh" weston-img \
		rockchip-mali wayland wayland-protocols weston flutter-embedded-linux
else
	# Default flutter-pi image: Mali gbm + reinstall flutter-pi (weston builds
	# purge /usr/bin/flutter-pi from the shared target/).
	bash "$ROOT/scripts/br-make-packages.sh" mali-gbm rockchip-mali flutter-pi
fi

printf '%s\n' "$DESIRED" >"$STAMP"
echo "ensure-mali-variant: stamped ${DESIRED} → $STAMP"
