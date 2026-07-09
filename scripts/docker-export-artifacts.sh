#!/usr/bin/env bash
# macOS Docker volume: copy build artifacts from the ephemeral SDK volume → host.
#
# Principle: host inputs (repo, SDK tree) go into Docker; host-consumed outputs
# (firmware/, flash images) are exported when a build step finishes — not on demand at flash time.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
VOLUME="${LWS_HMI_DOCKER_VOLUME:-lws-hmi-sdk}"

resolve_host_sdk() {
	if [[ -n "${LWS_HMI_SDK_DIR:-}" && -d "${LWS_HMI_SDK_DIR}" && "${LWS_HMI_SDK_DIR}" != /work/sdk ]]; then
		echo "$LWS_HMI_SDK_DIR"
		return 0
	fi
	bash "$ROOT/scripts/link-sdk.sh" --print 2>/dev/null || true
}

uses_docker_volume() {
	[[ "$(uname -s)" == Darwin ]] || return 1
	[[ "${BUILD_BIND_MOUNT:-}" != "1" ]] || return 1
	docker volume inspect "$VOLUME" >/dev/null 2>&1
}

export_firmware_from_volume() {
	local host_sdk="$1"
	local host_fw="$host_sdk/output/firmware"
	local lws_fw="$ROOT/output/firmware"

	mkdir -p "$host_fw" "$lws_fw"

	echo "docker-export: volume:$VOLUME /work/sdk/output/firmware → host"
	docker run --rm --platform "$PLATFORM" \
		-v "$VOLUME:/work/sdk:ro" \
		-v "$host_fw:/dest-sdk-firmware" \
		-v "$lws_fw:/dest-lws-firmware" \
		"$IMAGE" \
		bash -c '
			set -euo pipefail
			if [[ ! -d /work/sdk/output/firmware ]]; then
				echo "docker-export: no /work/sdk/output/firmware in volume (build not run yet?)" >&2
				exit 1
			fi
			rsync -a --delete /work/sdk/output/firmware/ /dest-sdk-firmware/
			rsync -a --delete /work/sdk/output/firmware/ /dest-lws-firmware/
			# SDK firmware entries are often symlinks into the volume tree; dereference
			# flash-critical files so the host bind mount is not left with broken links.
			for f in update.img MiniLoaderAll.bin uboot.img misc.img parameter.txt; do
				if [[ -e /work/sdk/output/firmware/$f ]]; then
					rm -f "/dest-lws-firmware/$f"
					cp -Lf "/work/sdk/output/firmware/$f" "/dest-lws-firmware/$f"
				fi
			done
		'

	echo "docker-export: host paths"
	for f in update.img boot.img rootfs.img MiniLoaderAll.bin uboot.img parameter.txt; do
		if [[ -r "$lws_fw/$f" ]]; then
			ls -lh "$lws_fw/$f"
		fi
	done
}

export_output_from_volume() {
	local host_sdk="$1"
	mkdir -p "$host_sdk/output"
	echo "docker-export: volume:$VOLUME /work/sdk/output → $host_sdk/output"
	docker run --rm --platform "$PLATFORM" \
		-v "$VOLUME:/work/sdk:ro" \
		-v "$host_sdk/output:/dest" \
		"$IMAGE" \
		rsync -rlptD --no-xattrs --omit-dir-times --info=progress2 /work/sdk/output/ /dest/
	# Flash / audit default to lws-hmi/output/firmware — keep in sync.
	export_firmware_from_volume "$host_sdk"
}

main() {
	local scope="${1:-firmware}"
	local host_sdk

	if ! uses_docker_volume; then
		exit 0
	fi

	if ! docker info >/dev/null 2>&1; then
		echo "ERROR: Docker daemon is not running." >&2
		exit 1
	fi

	host_sdk="$(resolve_host_sdk)"
	if [[ -z "$host_sdk" || ! -d "$host_sdk" ]]; then
		echo "ERROR: host SDK not found (run: make link-sdk)" >&2
		exit 1
	fi

	case "$scope" in
	firmware) export_firmware_from_volume "$host_sdk" ;;
	output) export_output_from_volume "$host_sdk" ;;
	*)
		echo "Usage: $0 {firmware|output}" >&2
		exit 1
		;;
	esac
}

main "$@"
