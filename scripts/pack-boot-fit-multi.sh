#!/usr/bin/env bash
# Pack (or re-pack) a multi-configuration FIT into TARGET_IMG using inventory DTBs.
# Substitutes @KERNEL_IMG@ / @RESOURCE_IMG@ / @KERNEL_DTB@ / @KERNEL_DTB_<id>@ then mkimage.
# Intended after ./build.sh kernel (or equivalent) has produced Image + DTBs + resource.img.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-${RK_SDK_DIR:-$ROOT/linux-sdk}}"
INVENTORY="${FIT_BOARD_INVENTORY:-$ROOT/board/rk356x-fit-boards.txt}"
ITS_SRC="${FIT_ITS_SRC:-$ROOT/board/boot-multi.its}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

realpath_q() {
	local p="$1"
	if command -v realpath >/dev/null 2>&1; then
		realpath -q "$p" 2>/dev/null || realpath "$p"
	else
		python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p"
	fi
}

TARGET_IMG="${1:-}"
[[ -n "$TARGET_IMG" ]] || die "usage: $0 <target-boot.img> [kernel-img] [resource-img]"

KERNEL_IMG="${2:-}"
RESOURCE_IMG="${3:-}"

find_kernel_img() {
	local c
	for c in \
		"$SDK/kernel/arch/arm64/boot/Image" \
		"$SDK/output/firmware/Image"; do
		if [[ -r "$c" ]]; then
			echo "$c"
			return 0
		fi
	done
	return 1
}

find_resource_img() {
	local c
	for c in \
		"$SDK/kernel/resource.img" \
		"$SDK/output/resource.img" \
		"$SDK/rockdev/resource.img" \
		"$SDK/output/firmware/resource.img" \
		"$SDK/rockdev/Image/resource.img"; do
		if [[ -r "$c" ]]; then
			echo "$c"
			return 0
		fi
	done
	return 1
}

find_dtb_dir() {
	local c
	if [[ -n "${FIT_DTB_DIR:-}" ]]; then
		[[ -d "$FIT_DTB_DIR" ]] || die "FIT_DTB_DIR not a directory: $FIT_DTB_DIR"
		echo "$FIT_DTB_DIR"
		return 0
	fi
	for c in \
		"$SDK/kernel/arch/arm64/boot/dts/rockchip"; do
		if [[ -d "$c" ]]; then
			echo "$c"
			return 0
		fi
	done
	return 1
}

find_mkimage() {
	local c
	for c in \
		"$SDK/rkbin/tools/mkimage" \
		"$SDK/u-boot/tools/mkimage"; do
		if [[ -x "$c" ]]; then
			echo "$c"
			return 0
		fi
	done
	return 1
}

dtb_path_for() {
	local board="$1"
	local dir="$2"
	local p="$dir/${board}.dtb"
	[[ -r "$p" ]] || die "missing DTB for inventory board '$board': $p"
	realpath_q "$p"
}

[[ -r "$INVENTORY" ]] || die "missing inventory: $INVENTORY"
[[ -r "$ITS_SRC" ]] || die "missing ITS: $ITS_SRC — run scripts/generate-boot-fit-its.sh"

boards=()
while IFS= read -r line || [[ -n "$line" ]]; do
	line="${line%%#*}"
	line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
	[[ -z "$line" ]] && continue
	boards+=("$line")
done <"$INVENTORY"
[[ ${#boards[@]} -ge 1 ]] || die "empty board inventory"

default="${FIT_DEFAULT_BOARD:-${boards[0]}}"

if [[ -z "$KERNEL_IMG" ]]; then
	KERNEL_IMG="$(find_kernel_img)" || die "kernel Image not found"
fi
if [[ -z "$RESOURCE_IMG" ]]; then
	RESOURCE_IMG="$(find_resource_img)" || die "resource.img not found (logo FIT needs it)"
fi
[[ -r "$KERNEL_IMG" ]] || die "kernel Image not readable: $KERNEL_IMG"
[[ -r "$RESOURCE_IMG" ]] || die "resource.img not readable: $RESOURCE_IMG"

DTB_DIR="$(find_dtb_dir)" || die "rockchip DTB dir not found"
MKIMAGE="$(find_mkimage)" || die "mkimage not found under rkbin/tools"

DEFAULT_DTB="$(dtb_path_for "$default" "$DTB_DIR")"
KERNEL_ABS="$(realpath_q "$KERNEL_IMG")"
RESOURCE_ABS="$(realpath_q "$RESOURCE_IMG")"

TMP_ITS="$(mktemp)"
trap 'rm -f "$TMP_ITS"' EXIT
cp "$ITS_SRC" "$TMP_ITS"

# Portable in-place sed (GNU + BSD): write to temp then mv
sed_inplace() {
	local expr="$1" file="$2"
	local tmp
	tmp="$(mktemp)"
	sed -e "$expr" "$file" >"$tmp"
	mv "$tmp" "$file"
}

sed_inplace "s~@KERNEL_IMG@~${KERNEL_ABS}~g" "$TMP_ITS"
sed_inplace "s~@RESOURCE_IMG@~${RESOURCE_ABS}~g" "$TMP_ITS"
sed_inplace "s~@KERNEL_DTB@~${DEFAULT_DTB}~g" "$TMP_ITS"

for b in "${boards[@]}"; do
	[[ "$b" == "$default" ]] && continue
	path="$(dtb_path_for "$b" "$DTB_DIR")"
	sed_inplace "s~@KERNEL_DTB_${b}@~${path}~g" "$TMP_ITS"
done

if grep -q '@KERNEL_DTB_' "$TMP_ITS"; then
	die "unsubstituted @KERNEL_DTB_*@ placeholders remain in ITS — inventory/ITS mismatch"
fi

mkdir -p "$(dirname "$TARGET_IMG")"
"$MKIMAGE" -f "$TMP_ITS" -E -p 0x800 "$TARGET_IMG"
echo "pack-boot-fit-multi: $TARGET_IMG (default=$default boards=${boards[*]})"
