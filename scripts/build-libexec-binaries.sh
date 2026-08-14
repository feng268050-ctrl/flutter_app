#!/usr/bin/env bash
# Cross-compile small C binaries → prebuilt/ + rootfs overlay usr/libexec/.
# Tools: reboot-loader, extract-video-frame, emulator-tablet-to-touch
#
# Usage:
#   bash scripts/build-libexec-binaries.sh
#   TOOL=reboot-loader bash scripts/build-libexec-binaries.sh
#   TOOL=emulator-tablet-to-touch,reboot-loader FORCE=1 bash scripts/build-libexec-binaries.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE="${FORCE:-0}"
TOOL="${TOOL:-all}"

LIBEXEC_BIN_ALL="reboot-loader extract-video-frame emulator-tablet-to-touch hmi-capture"

die() { echo "ERROR: $*" >&2; exit 1; }

libexec_bin_script_for() {
	case "$1" in
	reboot-loader) echo build-reboot-loader.sh ;;
	extract-video-frame) echo build-extract-video-frame.sh ;;
	emulator-tablet-to-touch) echo build-emulator-tablet-to-touch.sh ;;
	hmi-capture) echo build-hmi-capture.sh ;;
	*) return 1 ;;
	esac
}

libexec_bin_known() {
	case " $LIBEXEC_BIN_ALL " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

select_tools() {
	local raw="${1:-all}" item
	if [[ -z "$raw" || "$raw" == "all" ]]; then
		echo "$LIBEXEC_BIN_ALL"
		return 0
	fi
	local -a selected=()
	IFS=',' read -r -a parts <<<"$raw"
	for item in "${parts[@]}"; do
		item="${item#"${item%%[![:space:]]*}"}"
		item="${item%"${item##*[![:space:]]}"}"
		[[ -n "$item" ]] || continue
		libexec_bin_known "$item" || die "unknown TOOL=$item (known: $LIBEXEC_BIN_ALL)"
		selected+=("$item")
	done
	((${#selected[@]} > 0)) || die "TOOL is empty"
	local out=""
	for item in "${selected[@]}"; do
		out+="${out:+ }$item"
	done
	echo "$out"
}

if [[ "$(uname -s)" == Darwin ]] && [[ "${DOCKER:-}" != "1" ]]; then
	# Pass TOOL/FORCE on the remote argv — docker-run.sh does not forward TOOL=.
	exec env SKIP_OVERLAY=1 \
		bash "$ROOT/scripts/docker-run.sh" \
		env FORCE="$FORCE" TOOL="$TOOL" \
		bash /work/lws-hmi/scripts/build-libexec-binaries.sh
fi

tools="$(select_tools "$TOOL")"
echo "build-libexec-binaries: $tools"

for tool in $tools; do
	script="$(libexec_bin_script_for "$tool")" || die "unknown TOOL=$tool"
	echo "build-libexec-binaries: → $script"
	FORCE="$FORCE" bash "$ROOT/scripts/$script"
done

echo "build-libexec-binaries: done"
