#!/usr/bin/env bash
# Re-enable U-Boot compilation (Innohi SDK ships prebuilt-only mk-loader.sh).
set -euo pipefail

target="$1"
marker='lws-hmi: mk-loader compile enabled'

if grep -q "$marker" "$target" 2>/dev/null; then
  exit 0
fi

python3 - "$target" <<'PY'
import re, sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

new_fn = r'''build_uboot()
{
# lws-hmi: mk-loader compile enabled
	check_config RK_LOADER RK_UBOOT_CFG || false

	if [ -z "$DRY_RUN" ]; then
		rm -f u-boot/*.bin u-boot/*.img

		"$RK_SCRIPTS_DIR/check-loader.sh"
	fi

	UARGS_COMMON="$RK_UBOOT_OPTS \
		${RK_UBOOT_INI:+../rkbin/RKBOOT/$RK_UBOOT_INI} \
		${RK_UBOOT_TRUST_INI:+../rkbin/RKTRUST/$RK_UBOOT_TRUST_INI}"
	UARGS="$UARGS_COMMON ${RK_UBOOT_SPL:+--spl-new}"

	[ ! "$RK_SECURITY_BURN_KEY" ] || \
		UARGS="$UARGS ${RK_SECUREBOOT_FIT:+--burn-key-hash}"

	run_command cd u-boot

	run_command $UMAKE $RK_UBOOT_CFG $RK_UBOOT_CFG_FRAGMENTS $UARGS
	[ ! -z "$DRY_RUN" ] || "$RK_SCRIPTS_DIR/check-security.sh" uboot

	if [ "$RK_SECURITY_OPTEE_STORAGE_SECURITY" ]; then
		if [ -z "$(rk_partition_size security)" ]; then
			error "\"security\" partition not found in parameter"
			return 1
		fi
	fi

	if [ "$RK_SECUREBOOT_AVB" ]; then
		if [ -z "$(rk_partition_size vbmeta)" ]; then
			error "\"vbmeta\" partition not found in parameter"
			return 1
		fi
	fi

	if [ "$RK_UBOOT_SPL" ]; then
		if [ "$DRY_RUN" ] || \
			! grep -q "ROCKCHIP_FIT_IMAGE_PACK=y" .config; then
			# Repack SPL for non-FIT u-boot
			run_command $UMAKE $UARGS_COMMON --spl
		fi
	fi

	if [ "$RK_UBOOT_RAW" ]; then
		run_command $UMAKE $UARGS_COMMON --idblock
	fi

	run_command cd ..

	if [ "$DRY_RUN" ]; then
		return 0
	fi

	LOADER="$(echo u-boot/*_loader_*.bin | head -1)"
	if [ "$RK_SECUREBOOT_AVB" ]; then
	       "$RK_SCRIPTS_DIR/mk-security.sh" sign loader $LOADER \
				"$RK_FIRMWARE_DIR"/MiniLoaderAll.bin
	       "$RK_SCRIPTS_DIR/mk-security.sh" sign uboot u-boot/uboot.img \
				"$RK_FIRMWARE_DIR"/uboot.img
	       "$RK_SCRIPTS_DIR/mk-security.sh" sign trust u-boot/trust.img \
				"$RK_FIRMWARE_DIR"/trust.img
	else
		ln -rsf "$LOADER" "$RK_FIRMWARE_DIR"/MiniLoaderAll.bin
		ln -rsf u-boot/uboot.img "$RK_FIRMWARE_DIR"
		[ ! -e u-boot/trust.img ] || \
			ln -rsf u-boot/trust.img "$RK_FIRMWARE_DIR"
	fi
}'''

patched, n = re.subn(
    r"build_uboot\(\)\s*\{.*?\n\}",
    new_fn,
    text,
    count=1,
    flags=re.DOTALL,
)
if n != 1:
    raise SystemExit(f"mk-loader patch failed in {path}")

open(path, "w", encoding="utf-8").write(patched)
print(f"patched {path}: U-Boot compile enabled")
PY
