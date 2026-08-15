#!/usr/bin/env bash
# Build dual multi-conf FIT: boot.img → rootfs_a, boot_b.img → rootfs_b.
# Image is shared; per-slot resource.img PARTLABEL (+ RSCE ENTR SHA-1) and DTBs differ.
# Slots a/b rebuild DTBs under flock, stage per-slot DTBs, then pack FITs in parallel.
# Run inside the SDK container (/work/sdk).
# See docs/ab-slot-misc.md (resource RSCE SHA-1 pitfalls).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-/work/sdk}"
FIRMWARE="$SDK/output/firmware"
INVENTORY="${FIT_BOARD_INVENTORY:-$ROOT/board/rk356x-fit-boards.txt}"
OVERLAY_DTS="$ROOT/overlay/kernel/rockchip"
DTSI_LOCK="$FIRMWARE/.kernel-dtsi.lock"
ROOT_DTSI_PATHS=()
BOARDS=()

die() {
	echo "ERROR: $*" >&2
	exit 1
}

kernel_source_dir() {
	echo "$SDK/kernel"
}

canonical_root_dtsi() {
	local board="$1"
	echo "$OVERLAY_DTS/${board}-linux-root.dtsi"
}

installed_root_dtsi() {
	local board="$1" kdir
	kdir="$(kernel_source_dir)"
	echo "$kdir/arch/arm64/boot/dts/rockchip/${board}-linux-root.dtsi"
}

read_inventory_boards() {
	local line
	BOARDS=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		[[ -z "$line" ]] && continue
		BOARDS+=("$line")
	done <"$INVENTORY"
	[[ ${#BOARDS[@]} -gt 0 ]] || die "empty FIT board inventory: $INVENTORY"
}

collect_root_dtsi_paths() {
	local b p canon
	read_inventory_boards
	ROOT_DTSI_PATHS=()
	for b in "${BOARDS[@]}"; do
		canon="$(canonical_root_dtsi "$b")"
		[[ -f "$canon" ]] || die "inventory board '$b' missing A/B root DTSI: $canon"
		p="$(installed_root_dtsi "$b")"
		[[ -f "$p" ]] || die "installed root DTSI not found at $p (run make apply-overlay)"
		ROOT_DTSI_PATHS+=("$p")
	done
}

# Patch a specific *-linux-root.dtsi copy (not the live kernel tree).
patch_root_dtsi_file() {
	local file="$1" letter="$2" from to
	case "$letter" in
	a)
		from=rootfs_b
		to=rootfs_a
		;;
	b)
		from=rootfs_a
		to=rootfs_b
		;;
	*) die "patch_root_dtsi_file: bad letter '$letter'" ;;
	esac
	[[ -f "$file" ]] || die "patch_root_dtsi_file: missing $file"
	sed -i "s/PARTLABEL=${from}/PARTLABEL=${to}/g" "$file"
}

slot_staging_dir() {
	echo "$FIRMWARE/.kernel-slot-$1"
}

slot_dtb_dir() {
	echo "$(slot_staging_dir "$1")/dtbs"
}

slot_dtsi_path() {
	local slot="$1" board="$2"
	echo "$(slot_staging_dir "$slot")/${board}-linux-root.dtsi"
}

slot_fit_path() {
	case "$1" in
	a) echo "$FIRMWARE/boot.img" ;;
	b) echo "$FIRMWARE/boot_b.img" ;;
	*) die "slot_fit_path: bad letter '$1'" ;;
	esac
}

expect_partlabel() {
	case "$1" in
	a) echo rootfs_a ;;
	b) echo rootfs_b ;;
	*) die "expect_partlabel: bad letter '$1'" ;;
	esac
}

restore_canonical_root_dtsi() {
	local b
	read_inventory_boards
	for b in "${BOARDS[@]}"; do
		local canon dest
		canon="$(canonical_root_dtsi "$b")"
		dest="$(installed_root_dtsi "$b")"
		[[ -f "$canon" ]] || continue
		[[ -d "$(dirname "$dest")" ]] || continue
		cp -f "$canon" "$dest"
	done
}

prepare_slot_dtsi() {
	local slot="$1" b dest expect
	expect="$(expect_partlabel "$slot")"
	mkdir -p "$(slot_staging_dir "$slot")"
	read_inventory_boards
	for b in "${BOARDS[@]}"; do
		dest="$(slot_dtsi_path "$slot" "$b")"
		cp -f "$(canonical_root_dtsi "$b")" "$dest"
		patch_root_dtsi_file "$dest" "$slot"
		grep -E "bootargs[[:space:]]*=[[:space:]]*\".*root=PARTLABEL=${expect}" "$dest" >/dev/null \
			|| die "$dest does not select ${expect} (bootargs)"
	done
}

install_slot_root_dtsi() {
	local slot="$1" b
	read_inventory_boards
	for b in "${BOARDS[@]}"; do
		cp -f "$(slot_dtsi_path "$slot" "$b")" "$(installed_root_dtsi "$b")"
	done
}

resolve_dtb_dirs() {
	KDIR="$(kernel_source_dir)"
	DTB_DIR="$KDIR/arch/arm64/boot/dts/rockchip"
	[[ -d "$DTB_DIR" ]] || die "kernel DTB dir missing: $DTB_DIR"
}

run_kernel_olddefconfig() {
	(
		cd "$SDK"
		./build.sh kernel-make:olddefconfig </dev/null
	)
}

# Rebuild every inventory DTB in the live kernel tree; dtsi must already match $1.
force_rebuild_inventory_dtbs() {
	local expect="${1:?usage: force_rebuild_inventory_dtbs rootfs_a|rootfs_b}"
	local b
	resolve_dtb_dirs
	read_inventory_boards
	for p in "${ROOT_DTSI_PATHS[@]}"; do
		touch "$p"
	done
	for b in "${BOARDS[@]}"; do
		rm -f "$DTB_DIR/${b}.dtb"
		echo "=== force rebuild DTB: ${b}.dtb (expect PARTLABEL=${expect}) ==="
		(
			cd "$SDK"
			./build.sh "kernel-make:rockchip/${b}.dtb" 2>/dev/null || \
				./build.sh "kernel-make:${b}.dtb" || \
				die "failed to build ${b}.dtb — is DTS installed?"
		)
		[[ -r "$DTB_DIR/${b}.dtb" ]] || die "missing ${DTB_DIR}/${b}.dtb"
		grep -aFq "PARTLABEL=${expect}" "$DTB_DIR/${b}.dtb" \
			|| die "${b}.dtb missing PARTLABEL=${expect} after rebuild"
	done
}

# Ensure every DTB blob carrying root=PARTLABEL in the FIT selects $expect.
# ynh960 U-Boot honors resource.img's embedded DTB, not only fdt-*.
assert_fit_fdt_partlabel() {
	local img="$1" expect="$2" other
	case "$expect" in
	rootfs_a) other=rootfs_b ;;
	rootfs_b) other=rootfs_a ;;
	*) die "assert_fit_fdt_partlabel: bad expect '$expect'" ;;
	esac
	python3 - "$img" "$expect" "$other" <<'PY' || die "FIT DTB PARTLABEL check failed for $img"
import struct, sys
from pathlib import Path
img, expect, other = Path(sys.argv[1]), sys.argv[2].encode(), sys.argv[3].encode()
data = img.read_bytes()
want = f"PARTLABEL={expect.decode()}".encode()
forbid = f"PARTLABEL={other.decode()}".encode()
found = []
i = 0
while True:
    j = data.find(b"\xd0\x0d\xfe\xed", i)
    if j < 0:
        break
    if j + 8 > len(data):
        break
    size = struct.unpack(">I", data[j + 4 : j + 8])[0]
    if 64 < size < 2_000_000 and j + size <= len(data):
        blob = data[j : j + size]
        if want in blob or forbid in blob:
            found.append((j, want in blob, forbid in blob))
    i = j + 4
if not found:
    print(f"ERROR: no DTB with PARTLABEL in {img}", file=sys.stderr)
    sys.exit(1)
bad = [(off, has_want, has_forbid) for off, has_want, has_forbid in found if has_forbid or not has_want]
if bad:
    print(
        f"ERROR: {img} DTB PARTLABEL mismatch for {expect.decode()}: "
        f"all DTBs must select {expect.decode()} only (bad={bad}; all={found})",
        file=sys.stderr,
    )
    sys.exit(1)
print(f"OK: {img.name} all {len(found)} DTB(s) select PARTLABEL={expect.decode()}")
PY
}

find_resource_img() {
	local c
	for c in \
		"$(kernel_source_dir)/resource.img" \
		"$SDK/kernel/resource.img" \
		"$SDK/output/resource.img" \
		"$SDK/rockdev/resource.img" \
		"$SDK/output/firmware/resource.img" \
		"$SDK/rockdev/Image/resource.img"; do
		if [[ -r "$c" ]]; then
			printf '%s\n' "$c"
			return 0
		fi
	done
	return 1
}

stage_slot_resource_img() {
	local slot="$1" expect src staging dest
	expect="$(expect_partlabel "$slot")"
	staging="$(slot_staging_dir "$slot")"
	dest="$staging/resource.img"
	src="$(find_resource_img)" || die "resource.img not found (./build.sh kernel first)"
	mkdir -p "$staging"
	cp -f "$src" "$dest"
	python3 "$ROOT/scripts/patch-resource-img-partlabel.py" "$dest" "$expect" >&2
	printf '%s\n' "$dest"
}

repack_multi_fit() {
	local target="$1" slot="$2" dtb_dir resource_img tmp expect
	expect="$(expect_partlabel "$slot")"
	dtb_dir="$(slot_dtb_dir "$slot")"
	resource_img="$(stage_slot_resource_img "$slot")"
	tmp="$(mktemp "${target}.XXXXXX")"
	FIT_DTB_DIR="$dtb_dir" SDK_DIR="$SDK" \
		bash "$ROOT/scripts/pack-boot-fit-multi.sh" "$tmp" "" "$resource_img"
	assert_fit_fdt_partlabel "$tmp" "$expect"
	# Gate: RSCE ENTR SHA-1 must match payloads (PARTLABEL patch refreshes them).
	python3 "$ROOT/scripts/patch-resource-img-partlabel.py" --verify "$tmp" "$expect" \
		|| die "FIT resource RSCE verify failed for $tmp (see docs/ab-slot-misc.md)"
	bash "$ROOT/scripts/verify-boot-fit.sh" "$(dirname "$tmp")" "$(basename "$tmp")"
	mkdir -p "$(dirname "$target")"
	rm -f "$target"
	mv -f "$tmp" "$target"
}

ensure_kernel_config_fresh() {
	local kdir dir="$ROOT/overlay/kernel/rockchip" stamp
	kdir="$(kernel_source_dir)"
	[[ -d "$kdir/arch/arm64/configs" ]] || return 0
	stamp="$(find "$dir" -name '*.config' -print0 2>/dev/null | sort -z | xargs -0 shasum -a 256 2>/dev/null | shasum -a 256 | awk '{print $1}')"
	[[ -n "$stamp" ]] || return 0
	if [[ ! -f "$kdir/.lws-kernel-fragments.stamp" ]] || [[ "$(cat "$kdir/.lws-kernel-fragments.stamp" 2>/dev/null)" != "$stamp" ]]; then
		echo "build-kernel-ab: overlay kernel fragments changed — drop $kdir/.config for clean merge"
		rm -f "$kdir/.config"
		echo "$stamp" >"$kdir/.lws-kernel-fragments.stamp"
	fi
}

install_boot_fit_its() {
	local its="${1:?usage: install_boot_fit_its <its-file>}"
	local dest_dir
	[[ -r "$its" ]] || die "missing ITS: $its"
	for dest_dir in \
		"$SDK/device/rockchip/.chips/rk3566_rk3568" \
		"$SDK/device/rockchip/rk3566_rk3568" \
		"$SDK/device/rockchip/.chip"; do
		if [[ -d "$dest_dir" ]]; then
			cp -f "$its" "$dest_dir/boot-multi.its"
		fi
	done
}

ensure_boot_fit_its() {
	local b canon
	read_inventory_boards
	for b in "${BOARDS[@]}"; do
		canon="$(canonical_root_dtsi "$b")"
		[[ -r "$canon" ]] || die "missing canonical DTSI for board '$b': $canon"
		grep -E 'bootargs[[:space:]]*=[[:space:]]*".*root=PARTLABEL=rootfs_a' "$canon" >/dev/null \
			|| die "$canon does not select rootfs_a (bootargs)"
	done
	bash "$ROOT/scripts/generate-boot-fit-its.sh" \
		"$INVENTORY" "$ROOT/board/boot-multi.its"
	install_boot_fit_its "$ROOT/board/boot-multi.its"
}

# Rockchip mk-fitimage.sh only substitutes @KERNEL_DTB@ / @KERNEL_IMG@ / @RESOURCE_IMG@.
# Multi-board placeholders (@KERNEL_DTB_<id>@) are for pack-boot-fit-multi.sh only.
# Stage a single-conf ITS so ./build.sh kernel can finish Image + resource.
stage_rockchip_image_build_its() {
	local default tmp_inv tmp_its
	read_inventory_boards
	default="${FIT_DEFAULT_BOARD:-${BOARDS[0]}}"
	mkdir -p "$ROOT/output"
	tmp_inv="$ROOT/output/.boot-image-build-boards.txt"
	tmp_its="$ROOT/output/.boot-image-build.its"
	printf '%s\n' "$default" >"$tmp_inv"
	bash "$ROOT/scripts/generate-boot-fit-its.sh" "$tmp_inv" "$tmp_its"
	install_boot_fit_its "$tmp_its"
	echo "=== Image-phase ITS: single conf ($default) for Rockchip mk-fitimage ==="
}

build_kernel_image() {
	local image
	image="$(kernel_source_dir)/arch/arm64/boot/Image"
	if [[ -r "$image" && "${FORCE_KERNEL_IMAGE:-}" != "1" ]]; then
		echo "=== kernel Image present — skip ./build.sh kernel (FORCE_KERNEL_IMAGE=1 to rebuild) ==="
		return 0
	fi
	echo "=== A/B kernel FIT: build shared Image + resource ==="
	ensure_kernel_config_fresh
	stage_rockchip_image_build_its
	# Rockchip ./build.sh kernel can exit 0 even when 10-kernel.sh fails, then we
	# would pack the previous Image. Capture the log and refuse that path.
	mkdir -p "$ROOT/output/logs"
	local klog="$ROOT/output/logs/build-sh-kernel.log"
	if ! (
		cd "$SDK"
		./build.sh kernel
	) 2>&1 | tee "$klog"; then
		ensure_boot_fit_its
		die "./build.sh kernel failed — try: bash scripts/docker-run.sh bash -lc 'make -C /work/sdk/kernel mrproper && ./build.sh kernel'"
	fi
	if grep -q 'ERROR: Running .*/10-kernel.sh' "$klog"; then
		ensure_boot_fit_its
		die "./build.sh kernel reported 10-kernel.sh failure (Image not rebuilt); see $klog"
	fi
	# Restore multi-conf ITS for pack-boot-fit-multi (A/B slots).
	ensure_boot_fit_its
	run_kernel_olddefconfig
	image="$(kernel_source_dir)/arch/arm64/boot/Image"
	[[ -r "$image" ]] || die "kernel Image missing after ./build.sh kernel"
}

stage_slot_dtbs() {
	local slot="$1" expect dtb_dir b
	expect="$(expect_partlabel "$slot")"
	dtb_dir="$(slot_dtb_dir "$slot")"
	mkdir -p "$dtb_dir"
	resolve_dtb_dirs
	read_inventory_boards
	for b in "${BOARDS[@]}"; do
		cp -f "$DTB_DIR/${b}.dtb" "$dtb_dir/${b}.dtb"
		grep -aFq "PARTLABEL=${expect}" "$dtb_dir/${b}.dtb" \
			|| die "slot $slot staged ${b}.dtb missing PARTLABEL=${expect}"
	done
}

# Rebuild DTBs under flock (shared kernel tree), copy to isolated slot staging, restore canonical dtsi.
build_kernel_slot() {
	local slot="$1" expect fit_out dtb_dir
	expect="$(expect_partlabel "$slot")"
	fit_out="$(slot_fit_path "$slot")"
	dtb_dir="$(slot_dtb_dir "$slot")"

	echo "=== A/B kernel FIT: slot ${slot} (${expect}) ==="
	prepare_slot_dtsi "$slot"
	mkdir -p "$(dirname "$DTSI_LOCK")"
	(
		flock -x 9
		collect_root_dtsi_paths
		install_slot_root_dtsi "$slot"
		force_rebuild_inventory_dtbs "$expect"
		# Stage under the same lock — live DTB_DIR must not be overwritten by the
		# sibling slot before we copy into .kernel-slot-*/dtbs/.
		stage_slot_dtbs "$slot"
		restore_canonical_root_dtsi
	) 9>"$DTSI_LOCK"

	repack_multi_fit "$fit_out" "$slot"
	echo "=== slot ${slot} FIT ready: $fit_out ==="
}

run_parallel_fail_fast() {
	local -a pids=() pid cmd fail=0
	trap 'for pid in "${pids[@]:-}"; do kill "$pid" 2>/dev/null || true; done; wait 2>/dev/null || true; trap - INT TERM; exit 130' INT TERM
	for cmd in "$@"; do
		# shellcheck disable=SC2091
		( eval "$cmd" ) &
		pids+=("$!")
	done
	for pid in "${pids[@]}"; do
		if ! wait "$pid"; then
			fail=1
			for other in "${pids[@]}"; do
				[[ "$other" == "$pid" ]] && continue
				kill "$other" 2>/dev/null || true
			done
			break
		fi
	done
	wait 2>/dev/null || true
	trap - INT TERM
	[[ "$fail" -eq 0 ]] || die "parallel kernel slot build failed"
}

publish_bare_image() {
	local image_src candidate
	image_src=""
	for candidate in \
		"$(kernel_source_dir)/arch/arm64/boot/Image" \
		"$SDK/kernel/arch/arm64/boot/Image"; do
		if [[ -r "$candidate" ]]; then
			image_src="$candidate"
			break
		fi
	done
	if [[ -n "$image_src" ]]; then
		mkdir -p "$FIRMWARE"
		rm -f "$FIRMWARE/Image"
		cp -Lf "$image_src" "$FIRMWARE/Image"
		echo "emulator kernel Image: $FIRMWARE/Image"
		bash "$ROOT/scripts/artifact-size.sh" "$FIRMWARE/Image" || true
	else
		echo "WARNING: bare Image not found under kernel/arch/arm64/boot — emulator publish skipped" >&2
	fi
}

verify_ab_fits() {
	local slot
	for slot in a b; do
		[[ -r "$(slot_fit_path "$slot")" ]] || die "missing $(slot_fit_path "$slot")"
	done
	echo "A/B multi-conf kernel FITs ready:"
	bash "$ROOT/scripts/artifact-size.sh" \
		"$FIRMWARE/boot.img" "$FIRMWARE/boot_b.img"
	bash "$ROOT/scripts/verify-boot-fit.sh" "$FIRMWARE" boot.img
	bash "$ROOT/scripts/verify-boot-fit.sh" "$FIRMWARE" boot_b.img
}

main() {
	local only="${1:-}" b
	read_inventory_boards
	for b in "${BOARDS[@]}"; do
		[[ -r "$(canonical_root_dtsi "$b")" ]] \
			|| die "missing $(canonical_root_dtsi "$b")"
	done
	trap restore_canonical_root_dtsi EXIT

	python3 "$ROOT/scripts/patch-resource-img-partlabel.py" --self-test \
		|| die "resource PARTLABEL/RSCE self-test failed"
	ensure_boot_fit_its
	build_kernel_image

	case "$only" in
	a | b)
		build_kernel_slot "$only"
		;;
	"")
		run_parallel_fail_fast \
			"build_kernel_slot a" \
			"build_kernel_slot b"
		verify_ab_fits
		;;
	*)
		die "usage: $0 [a|b]  (default: both slots in parallel)"
		;;
	esac

	trap - EXIT
	restore_canonical_root_dtsi
	publish_bare_image

	if [[ -n "$only" ]]; then
		bash "$ROOT/scripts/verify-boot-fit.sh" "$FIRMWARE" "$(basename "$(slot_fit_path "$only")")"
	fi
}

main "$@"
