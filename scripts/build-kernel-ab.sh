#!/usr/bin/env bash
# Build dual multi-conf FIT: boot.img → rootfs_a, boot_b.img → rootfs_b.
# Image + resource.img are shared; only DTB bootargs (PARTLABEL) differ per slot.
# Slots a/b rebuild DTBs under flock, stage per-slot DTBs, then pack FITs in parallel.
# Run inside the SDK container (/work/sdk).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-/work/sdk}"
FIRMWARE="$SDK/output/firmware"
INVENTORY="${FIT_BOARD_INVENTORY:-$ROOT/board/rk356x-fit-boards.txt}"
CANONICAL_DTSI="$ROOT/overlay/kernel/rockchip/ynh960-linux-root.dtsi"
DTSI_LOCK="$FIRMWARE/.kernel-dtsi.lock"
ROOT_DTSI=""
ROOT_DTSI_PATHS=()

die() {
	echo "ERROR: $*" >&2
	exit 1
}

kernel_source_dir() {
	echo "$SDK/kernel"
}

collect_root_dtsi_paths() {
	local kdir p
	kdir="$(kernel_source_dir)"
	p="$kdir/arch/arm64/boot/dts/rockchip/ynh960-linux-root.dtsi"
	[[ -f "$p" ]] || die "installed ynh960 root DTSI not found at $p (run make apply-overlay)"
	ROOT_DTSI_PATHS=("$p")
	ROOT_DTSI="$p"
}

# Patch a specific ynh960-linux-root.dtsi copy (not the live kernel tree).
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
	echo "$(slot_staging_dir "$1")/ynh960-linux-root.dtsi"
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
	collect_root_dtsi_paths
	cp -f "$CANONICAL_DTSI" "$ROOT_DTSI"
}

prepare_slot_dtsi() {
	local slot="$1" dest
	dest="$(slot_dtsi_path "$slot")"
	mkdir -p "$(slot_staging_dir "$slot")"
	cp -f "$CANONICAL_DTSI" "$dest"
	patch_root_dtsi_file "$dest" "$slot"
	local expect
	expect="$(expect_partlabel "$slot")"
	grep -E "bootargs[[:space:]]*=[[:space:]]*\".*root=PARTLABEL=${expect}" "$dest" >/dev/null \
		|| die "$dest does not select ${expect} (bootargs)"
}

resolve_dtb_dirs() {
	KDIR="$(kernel_source_dir)"
	DTB_DIR="$KDIR/arch/arm64/boot/dts/rockchip"
	[[ -d "$DTB_DIR" ]] || die "kernel DTB dir missing: $DTB_DIR"
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

# Ensure the FIT's fdt-* blob(s) select $expect. resource.img may still carry
# the factory letter (rootfs_a) from the shared Image build — that is OK as
# long as fdt-* matches the slot (U-Boot uses the FIT configuration FDT).
assert_fit_fdt_partlabel() {
	local img="$1" expect="$2" other
	case "$expect" in
	rootfs_a) other=rootfs_b ;;
	rootfs_b) other=rootfs_a ;;
	*) die "assert_fit_fdt_partlabel: bad expect '$expect'" ;;
	esac
	python3 - "$img" "$expect" "$other" <<'PY' || die "FIT fdt PARTLABEL check failed for $img"
import struct, sys
from pathlib import Path
img, expect, other = Path(sys.argv[1]), sys.argv[2].encode(), sys.argv[3].encode()
data = img.read_bytes()
want = f"PARTLABEL={expect.decode()}".encode()
forbid = f"PARTLABEL={other.decode()}".encode()
# External FIT: kernel then resource then fdt-*. Prefer the last DTB that
# carries a PARTLABEL=rootfs_* bootargs — that is fdt-* after resource.
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
# Last matching DTB = FIT fdt-* (resource embeds an earlier copy).
_off, has_want, has_forbid = found[-1]
if not has_want or has_forbid:
    print(
        f"ERROR: {img} fdt PARTLABEL mismatch: expect {expect.decode()} only "
        f"(last DTB @ {_off} want={has_want} other={has_forbid}; all={found})",
        file=sys.stderr,
    )
    sys.exit(1)
print(f"OK: {img.name} fdt selects PARTLABEL={expect.decode()}")
PY
}

repack_multi_fit() {
	local target="$1" dtb_dir="${2:-}" tmp
	tmp="$(mktemp "${target}.XXXXXX")"
	if [[ -n "$dtb_dir" ]]; then
		FIT_DTB_DIR="$dtb_dir" LWS_HMI_SDK_DIR="$SDK" \
			bash "$ROOT/scripts/pack-boot-fit-multi.sh" "$tmp"
	else
		LWS_HMI_SDK_DIR="$SDK" bash "$ROOT/scripts/pack-boot-fit-multi.sh" "$tmp"
	fi
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

ensure_boot_fit_its() {
	[[ -r "$CANONICAL_DTSI" ]] || die "missing canonical DTSI: $CANONICAL_DTSI"
	grep -E 'bootargs[[:space:]]*=[[:space:]]*".*root=PARTLABEL=rootfs_a' "$CANONICAL_DTSI" >/dev/null \
		|| die "$CANONICAL_DTSI does not select rootfs_a (bootargs)"
	bash "$ROOT/scripts/generate-boot-fit-its.sh" \
		"$INVENTORY" "$ROOT/board/boot-multi.its"
	for dest_dir in \
		"$SDK/device/rockchip/.chips/rk3566_rk3568" \
		"$SDK/device/rockchip/rk3566_rk3568"; do
		if [[ -d "$dest_dir" ]]; then
			cp -f "$ROOT/board/boot-multi.its" "$dest_dir/boot-multi.its"
		fi
	done
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
	if ! (
		cd "$SDK"
		./build.sh kernel
	); then
		die "./build.sh kernel failed — try: bash scripts/docker-run.sh bash -lc 'make -C /work/sdk/kernel mrproper && ./build.sh kernel'"
	fi
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
		cp -f "$(slot_dtsi_path "$slot")" "$ROOT_DTSI"
		force_rebuild_inventory_dtbs "$expect"
		# Stage under the same lock — live DTB_DIR must not be overwritten by the
		# sibling slot before we copy into .kernel-slot-*/dtbs/.
		stage_slot_dtbs "$slot"
		restore_canonical_root_dtsi
	) 9>"$DTSI_LOCK"

	repack_multi_fit "$fit_out" "$dtb_dir"
	# resource.img (shared) may still embed rootfs_a; fdt-* must match the slot.
	assert_fit_fdt_partlabel "$fit_out" "$expect"
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
	local only="${1:-}"
	[[ -r "$CANONICAL_DTSI" ]] || die "missing $CANONICAL_DTSI"
	trap restore_canonical_root_dtsi EXIT

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
