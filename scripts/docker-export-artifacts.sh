#!/usr/bin/env bash
# Publish firmware artifacts to host output/firmware/ for make upgrade / flash.
#
# Single host copy: always lands under repo-root output/firmware/.
# Does NOT mirror into linux-sdk/output/firmware/ on the host.
#
# macOS Docker volume: copy selected files from the volume (dereferenced).
# Linux / bind-mount: move (or copy+rm) from linux-sdk/output/firmware →
#   output/firmware/ so the SDK tree does not keep a second full set.
#
# Scopes (avoid full-tree --delete so boot/rootfs exports do not clobber each other):
#   boot     — boot.img + boot_b.img + Image (shared output/firmware/)
#   rootfs   — rootfs.img → output/firmware/<APP>/ (product-specific)
#   update   — update.img (+ loader/uboot/misc/parameter when present)
#   firmware — all known flash/upgrade inputs
#   output   — legacy alias for firmware (no longer rsyncs linux-sdk/output/)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve

SIZE_HELPER="$ROOT/scripts/artifact-size.sh"
IMAGE="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
VOLUME="${DOCKER_VOLUME:-lws-hmi-sdk}"

resolve_host_sdk() {
	if [[ -n "${SDK_DIR:-}" && -d "${SDK_DIR}" && "${SDK_DIR}" != /work/sdk ]]; then
		echo "$SDK_DIR"
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
	boot) echo "boot.img boot_b.img Image" ;;
	rootfs) echo "rootfs.img rootfs.ext2 rootfs.ext4" ;;
	update) echo "update.img MiniLoaderAll.bin uboot.img misc.img parameter.txt" ;;
	firmware)
		echo "update.img boot.img boot_b.img Image rootfs.img rootfs.ext2 rootfs.ext4 MiniLoaderAll.bin uboot.img misc.img parameter.txt"
		;;
	*)
		echo "ERROR: unknown export scope: $1" >&2
		return 1
		;;
	esac
}

publish_sizes() {
	local dir="$1"
	shift
	local f
	local any=0
	for f in "$@"; do
		if [[ -r "$dir/$f" ]]; then
			any=1
			bash "$SIZE_HELPER" "$dir/$f"
		fi
	done
	[[ "$any" -eq 1 ]] || {
		echo "ERROR: no exported files under $dir for: $*" >&2
		return 1
	}
}

# Move flat host rootfs.* into output/firmware/<APP>/; refresh migration symlink.
promote_rootfs_to_app() {
	local flat="$ROOT/output/firmware"
	local f
	mkdir -p "$APP_FIRMWARE_DIR"
	for f in rootfs.img rootfs.ext2 rootfs.ext4; do
		if [[ -e "$flat/$f" && ! -L "$flat/$f" ]]; then
			rm -f "$APP_FIRMWARE_DIR/$f"
			mv -f "$flat/$f" "$APP_FIRMWARE_DIR/$f"
		fi
	done
	if [[ -e "$APP_FIRMWARE_DIR/rootfs.img" ]]; then
		ln -sfn "$APP/rootfs.img" "$flat/rootfs.img"
		echo "firmware-export: APP=$APP → $APP_ROOTFS_IMG (symlink $flat/rootfs.img)"
	fi
}

# Relocate listed firmware basenames from SDK firmware dir → host (no second copy left).
publish_from_host_sdk() {
	local host_sdk="$1"
	shift
	local src_fw="$host_sdk/output/firmware"
	local lws_fw="$ROOT/output/firmware"
	local f src
	local found=0

	mkdir -p "$lws_fw"
	[[ -d "$src_fw" ]] || {
		echo "ERROR: missing $src_fw — build step incomplete?" >&2
		return 1
	}
	echo "firmware-export: move $src_fw → $lws_fw (${*})"
	for f in "$@"; do
		src="$src_fw/$f"
		if [[ -e "$src" ]]; then
			found=1
			rm -f "$lws_fw/$f"
			# Prefer atomic rename; fall back to copy+rm across filesystems.
			if mv -f "$src" "$lws_fw/$f" 2>/dev/null; then
				:
			else
				cp -Lf "$src" "$lws_fw/$f"
				rm -f "$src"
			fi
		fi
	done
	[[ "$found" -eq 1 ]] || {
		echo "ERROR: none of [$*] found under $src_fw — build step incomplete?" >&2
		return 1
	}
}

# Copy from Docker volume → repo output/firmware only (no host linux-sdk/output mirror).
publish_from_volume() {
	shift # host_sdk unused; kept for call-site compatibility
	local lws_fw="$ROOT/output/firmware"
	local list=""
	local f

	for f in "$@"; do
		list="${list}${f}"$'\n'
	done

	mkdir -p "$lws_fw"
	echo "docker-export: volume:$VOLUME firmware → $lws_fw (${*})"

	docker run --rm --platform "$PLATFORM" \
		-v "$VOLUME:/work/sdk:ro" \
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
					rm -f "/dest-lws-firmware/$f"
					cp -Lf "/work/sdk/output/firmware/$f" "/dest-lws-firmware/$f"
				fi
			done <<< "$EXPORT_FILES"
			if [[ "$found" -ne 1 ]]; then
				echo "docker-export: none of the requested files exist in volume firmware/" >&2
				echo "$EXPORT_FILES" >&2
				exit 1
			fi
		'
}

finish_publish() {
	local scope="$1"
	shift
	case "$scope" in
	rootfs | firmware)
		promote_rootfs_to_app
		publish_sizes "$APP_FIRMWARE_DIR" rootfs.img rootfs.ext2 rootfs.ext4 || true
		if [[ "$scope" == firmware ]]; then
			publish_sizes "$ROOT/output/firmware" boot.img boot_b.img Image update.img \
				MiniLoaderAll.bin uboot.img misc.img parameter.txt || true
		fi
		# Require at least rootfs.img for rootfs scope (size already printed above).
		if [[ "$scope" == rootfs ]]; then
			[[ -r "$APP_ROOTFS_IMG" ]] || {
				echo "ERROR: missing $APP_ROOTFS_IMG after export" >&2
				return 1
			}
		fi
		;;
	*)
		publish_sizes "$ROOT/output/firmware" "$@"
		;;
	esac
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
		echo "firmware-export: scope=output is a legacy alias for firmware (no linux-sdk/output/ mirror)"
		scope=firmware
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
	# shellcheck disable=SC2086
	finish_publish "$scope" $(files_for_scope "$scope")
}

main "$@"
