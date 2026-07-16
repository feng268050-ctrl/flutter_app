#!/usr/bin/env bash
# Publish firmware artifacts to host output/firmware/ for make upgrade / flash.
#
# macOS Docker volume: copy selected files from the volume (dereferenced).
# Linux / bind-mount: copy from linux-sdk/output/firmware to repo output/firmware.
#
# Scopes (avoid full-tree --delete so boot/rootfs exports do not clobber each other):
#   boot     — boot.img + boot_b.img
#   rootfs   — rootfs.img (+ rootfs.ext2 / rootfs.ext4 if present)
#   update   — update.img (+ loader/uboot/misc/parameter when present)
#   firmware — all known flash/upgrade inputs (legacy full sync)
#   output   — full linux-sdk/output/ (legacy; still ends with firmware publish)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIZE_HELPER="$ROOT/scripts/artifact-size.sh"
IMAGE="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
VOLUME="${LWS_HMI_DOCKER_VOLUME:-lws-hmi-sdk}"

resolve_host_sdk() {
	if [[ -n "${LWS_HMI_SDK_DIR:-}" && -d "${LWS_HMI_SDK_DIR}" && "${LWS_HMI_SDK_DIR}" != /work/sdk ]]; then
		echo "$LWS_HMI_SDK_DIR"
		return 0
	fi
	echo "$ROOT/linux-sdk"
}

uses_docker_volume() {
	[[ "$(uname -s)" == Darwin ]] || return 1
	[[ "${BUILD_BIND_MOUNT:-}" != "1" ]] || return 1
	docker volume inspect "$VOLUME" >/dev/null 2>&1
}

# Space-separated basenames (bash 3.2-safe; no mapfile).
files_for_scope() {
	case "$1" in
	boot) echo "boot.img boot_b.img" ;;
	rootfs) echo "rootfs.img rootfs.ext2 rootfs.ext4" ;;
	update) echo "update.img MiniLoaderAll.bin uboot.img misc.img parameter.txt" ;;
	firmware)
		echo "update.img boot.img boot_b.img rootfs.img rootfs.ext2 rootfs.ext4 MiniLoaderAll.bin uboot.img misc.img parameter.txt"
		;;
	*)
		echo "ERROR: unknown export scope: $1" >&2
		return 1
		;;
	esac
}

publish_sizes() {
	local lws_fw="$ROOT/output/firmware"
	local f
	local any=0
	for f in "$@"; do
		if [[ -r "$lws_fw/$f" ]]; then
			any=1
			bash "$SIZE_HELPER" "$lws_fw/$f"
		fi
	done
	[[ "$any" -eq 1 ]] || {
		echo "ERROR: no exported files under $lws_fw for: $*" >&2
		return 1
	}
}

# Copy listed firmware basenames from SDK firmware dir → host paths (dereference).
publish_from_host_sdk() {
	local host_sdk="$1"
	shift
	local src_fw="$host_sdk/output/firmware"
	local lws_fw="$ROOT/output/firmware"
	local f src
	local found=0

	mkdir -p "$src_fw" "$lws_fw"
	echo "firmware-export: $src_fw → $lws_fw (${*})"
	for f in "$@"; do
		src="$src_fw/$f"
		if [[ -e "$src" ]]; then
			found=1
			rm -f "$lws_fw/$f"
			cp -Lf "$src" "$lws_fw/$f"
		fi
	done
	[[ "$found" -eq 1 ]] || {
		echo "ERROR: none of [$*] found under $src_fw — build step incomplete?" >&2
		return 1
	}
	publish_sizes "$@"
}

publish_from_volume() {
	local host_sdk="$1"
	shift
	local host_fw="$host_sdk/output/firmware"
	local lws_fw="$ROOT/output/firmware"
	local list=""
	local f

	for f in "$@"; do
		list="${list}${f}"$'\n'
	done

	mkdir -p "$host_fw" "$lws_fw"
	echo "docker-export: volume:$VOLUME firmware → host (${*})"

	docker run --rm --platform "$PLATFORM" \
		-v "$VOLUME:/work/sdk:ro" \
		-v "$host_fw:/dest-sdk-firmware" \
		-v "$lws_fw:/dest-lws-firmware" \
		-e "EXPORT_FILES=$list" \
		"$IMAGE" \
		bash -c '
			set -euo pipefail
			if [[ ! -d /work/sdk/output/firmware ]]; then
				echo "docker-export: no /work/sdk/output/firmware in volume (build not run yet?)" >&2
				exit 1
			fi
			found=0
			while IFS= read -r f; do
				[[ -n "$f" ]] || continue
				if [[ -e /work/sdk/output/firmware/$f ]]; then
					found=1
					rm -f "/dest-sdk-firmware/$f" "/dest-lws-firmware/$f"
					cp -Lf "/work/sdk/output/firmware/$f" "/dest-sdk-firmware/$f"
					cp -Lf "/work/sdk/output/firmware/$f" "/dest-lws-firmware/$f"
				fi
			done <<< "$EXPORT_FILES"
			if [[ "$found" -ne 1 ]]; then
				echo "docker-export: none of the requested files exist in volume firmware/" >&2
				echo "$EXPORT_FILES" >&2
				exit 1
			fi
		'

	publish_sizes "$@"
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
	# shellcheck disable=SC2086
	publish_from_volume "$host_sdk" $(files_for_scope firmware)
}

main() {
	local scope="${1:-firmware}"
	local host_sdk

	host_sdk="$(resolve_host_sdk)"
	if [[ -z "$host_sdk" || ! -d "$host_sdk" ]]; then
		echo "ERROR: host SDK not found at $ROOT/linux-sdk" >&2
		exit 1
	fi

	case "$scope" in
	output)
		if uses_docker_volume; then
			if ! docker info >/dev/null 2>&1; then
				echo "ERROR: Docker daemon is not running." >&2
				exit 1
			fi
			export_output_from_volume "$host_sdk"
		else
			echo "firmware-export: scope=output is a no-op without Docker volume"
		fi
		return 0
		;;
	boot | rootfs | update | firmware) ;;
	*)
		echo "Usage: $0 {boot|rootfs|update|firmware|output}" >&2
		exit 1
		;;
	esac

	if uses_docker_volume; then
		if ! docker info >/dev/null 2>&1; then
			echo "ERROR: Docker daemon is not running." >&2
			exit 1
		fi
		# shellcheck disable=SC2086
		publish_from_volume "$host_sdk" $(files_for_scope "$scope")
	else
		# shellcheck disable=SC2086
		publish_from_host_sdk "$host_sdk" $(files_for_scope "$scope")
	fi
}

main "$@"
