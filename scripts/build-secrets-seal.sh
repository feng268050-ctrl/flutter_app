#!/usr/bin/env bash
# Cross-build OP-TEE seal TA + secrets-seal-ca → prebuilt/ + rootfs overlay.
# TA signed with optee_os 3.13 default_ta.pem (matches many Rockchip engineering
# BL32 builds; production keys may need TA_SIGN_KEY override).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

OPTEE_OS_VER="${OPTEE_OS_VER:-3.13.0}"
FORCE="${FORCE:-0}"
CACHE="$(cache_root "$ROOT")/optee"
OS_DIR="$CACHE/optee_os-${OPTEE_OS_VER}"
OUT_DIR="$ROOT/prebuilt/secrets_seal/aarch64"
OVERLAY_ROOT="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay"
TA_UUID="b8e4f2a1-9c3d-4e6f-8a1b-2c3d4e5f6071"
TA_NAME="${TA_UUID}.ta"
STAMP_VER="seal-${OPTEE_OS_VER}-$(date -u +%Y%m%d 2>/dev/null || echo 0)"

ensure_optee_os() {
	mkdir -p "$CACHE"
	if [[ ! -d "$OS_DIR" ]]; then
		local tar="$CACHE/optee_os-${OPTEE_OS_VER}.tar.gz"
		if [[ ! -f "$tar" ]]; then
			echo "build-secrets-seal: fetch optee_os ${OPTEE_OS_VER} ..."
			curl -fL --retry 3 --retry-delay 2 -o "$tar" \
				"https://github.com/OP-TEE/optee_os/archive/refs/tags/${OPTEE_OS_VER}.tar.gz"
		fi
		tar -xzf "$tar" -C "$CACHE"
	fi
}

find_cross_prefix() {
	local sdk="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
	local cand br
	for cand in \
		"$sdk/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-" \
		"$sdk/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"
	do
		if [[ -x "${cand}gcc" ]]; then
			echo "$cand"
			return 0
		fi
	done
	br="$(resolve_br_output_dir "$sdk" 2>/dev/null || true)"
	if [[ -n "$br" && -d "$br/host/bin" ]]; then
		for cand in "$br/host/bin/"*-linux-gnu-gcc "$br/host/bin/"*-linux-gcc; do
			[[ -x "$cand" ]] || continue
			echo "${cand%gcc}"
			return 0
		done
	fi
	return 1
}

resolve_teec() {
	local sdk="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
	local br staging
	br="$(resolve_br_output_dir "$sdk")"
	staging="$br/staging"
	if [[ ! -f "$staging/usr/include/tee_client_api.h" && \
		! -f "$staging/usr/include/tee/tee_client_api.h" ]]; then
		# Common layout: include/tee_client_api.h
		if [[ ! -f "$staging/usr/include/tee_client_api.h" ]]; then
			echo "ERROR: tee_client_api.h missing in $staging — build optee-client first:" >&2
			echo "  bash scripts/br-make-packages.sh optee optee-client" >&2
			exit 1
		fi
	fi
	if [[ ! -e "$staging/usr/lib/libteec.so" && ! -e "$staging/lib/libteec.so" ]]; then
		echo "ERROR: libteec.so missing in staging — build optee-client first" >&2
		exit 1
	fi
	echo "$staging"
}

sync_overlay() {
	mkdir -p "$OVERLAY_ROOT/usr/lib/optee_armtz" \
		"$OVERLAY_ROOT/usr/libexec/hmi"
	install -m 0644 "$OUT_DIR/$TA_NAME" \
		"$OVERLAY_ROOT/usr/lib/optee_armtz/$TA_NAME"
	install -m 0755 "$OUT_DIR/secrets-seal-ca" \
		"$OVERLAY_ROOT/usr/libexec/hmi/secrets-seal-ca"
	# Buildroot merged-/usr rejects overlay top-level /lib.
	rm -f "$OVERLAY_ROOT/lib/optee_armtz/$TA_NAME"
	rmdir "$OVERLAY_ROOT/lib/optee_armtz" 2>/dev/null || true
	rmdir "$OVERLAY_ROOT/lib" 2>/dev/null || true
	echo "build-secrets-seal: synced → overlay usr/lib/optee_armtz + secrets-seal-ca"
}

do_build() {
	local cross prefix staging ta_dev_kit jobs
	ensure_optee_os
	prefix="$(find_cross_prefix)" || {
		echo "ERROR: aarch64 cross gcc not found" >&2
		exit 1
	}
	cross="${prefix}"
	staging="$(resolve_teec)"
	jobs="${BUILD_JOBS:-8}"
	ta_dev_kit="$CACHE/export-ta_arm64-${OPTEE_OS_VER}"

	echo "build-secrets-seal: CROSS_COMPILE=$cross"
	echo "build-secrets-seal: building ta_dev_kit (${OPTEE_OS_VER}) ..."
	# sign_encrypt.py needs PyCryptodome (or Crypto).
	python3 -m pip install --user -q pycryptodome 2>/dev/null || \
		pip3 install --user -q pycryptodome 2>/dev/null || \
		true
	export PATH="${HOME}/.local/bin:${PATH}"
	# Platform only needed to emit export-ta_arm64; skip in-tree early TAs
	# that also need signing (avb/pkcs11/trusted_keys).
	make -C "$OS_DIR" -j"$jobs" \
		PLATFORM=vexpress-qemu_armv8a \
		CFG_ARM64_core=y \
		CFG_USER_TA_TARGETS=ta_arm64 \
		CROSS_COMPILE_core="${cross}" \
		CROSS_COMPILE_ta_arm64="${cross}" \
		CFG_TEE_CORE_LOG_LEVEL=1 \
		CFG_TEE_TA_LOG_LEVEL=1 \
		CFG_IN_TREE_EARLY_TAS= \
		CFG_PKCS11_TA=n \
		O="$CACHE/optee_os_out-${OPTEE_OS_VER}" \
		ta_dev_kit

	local export_src
	export_src="$CACHE/optee_os_out-${OPTEE_OS_VER}/export-ta_arm64"
	[[ -d "$export_src" ]] || \
		export_src="$(find "$CACHE/optee_os_out-${OPTEE_OS_VER}" -type d -name export-ta_arm64 | head -1)"
	[[ -d "$export_src" ]] || {
		echo "ERROR: export-ta_arm64 missing after optee_os build" >&2
		exit 1
	}
	rm -rf "$ta_dev_kit"
	mkdir -p "$(dirname "$ta_dev_kit")"
	cp -a "$export_src" "$ta_dev_kit"

	echo "build-secrets-seal: building TA ..."
	make -C "$ROOT/native/secrets_seal/ta" clean \
		TA_DEV_KIT_DIR="$ta_dev_kit" O=out >/dev/null 2>&1 || true
	make -C "$ROOT/native/secrets_seal/ta" -j"$jobs" \
		CROSS_COMPILE="${cross}" \
		TA_DEV_KIT_DIR="$ta_dev_kit" \
		${TA_SIGN_KEY:+TA_SIGN_KEY="$TA_SIGN_KEY"} \
		O=out

	local ta_bin
	ta_bin="$(find "$ROOT/native/secrets_seal/ta" -name "$TA_NAME" | head -1)"
	[[ -f "$ta_bin" ]] || {
		echo "ERROR: $TA_NAME not produced" >&2
		find "$ROOT/native/secrets_seal/ta" -type f | head -40 >&2
		exit 1
	}

	echo "build-secrets-seal: building CA ..."
	local cc="${cross}gcc"
	local sysroot="$staging"
	local cflags=(-O2 -Wall -Wextra
		"--sysroot=$sysroot"
		"-I$ROOT/native/secrets_seal/include"
		"-I$staging/usr/include")
	local ldflags=("--sysroot=$sysroot"
		"-L$staging/usr/lib" "-L$staging/lib" -lteec)
	# Prefer rpath-less dynamic link; device has libteec in /lib.
	"$cc" "${cflags[@]}" -o "$CACHE/secrets-seal-ca" \
		"$ROOT/native/secrets_seal/host/secrets_seal_ca.c" \
		"${ldflags[@]}"

	mkdir -p "$OUT_DIR"
	install -m 0444 "$ta_bin" "$OUT_DIR/$TA_NAME"
	install -m 0755 "$CACHE/secrets-seal-ca" "$OUT_DIR/secrets-seal-ca"
	prebuilt_stamp "$OUT_DIR" "$STAMP_VER"
	sync_overlay
	bash "$ROOT/scripts/sync-prebuilt-manifest.sh" 2>/dev/null || true
	file "$OUT_DIR/secrets-seal-ca" "$OUT_DIR/$TA_NAME" || true
	echo "build-secrets-seal: done → $OUT_DIR"
}

if [[ "$FORCE" != "1" ]] && prebuilt_ready "$OUT_DIR" && \
	[[ -f "$OUT_DIR/$TA_NAME" && -x "$OUT_DIR/secrets-seal-ca" ]]; then
	echo "build-secrets-seal: prebuilt ready (FORCE=1 to rebuild)"
	sync_overlay
	exit 0
fi

if [[ "$FORCE" == "1" ]]; then
	rm -rf "$OUT_DIR"
	rm -f "$OVERLAY_ROOT/usr/lib/optee_armtz/$TA_NAME" \
		"$OVERLAY_ROOT/lib/optee_armtz/$TA_NAME" \
		"$OVERLAY_ROOT/usr/libexec/hmi/secrets-seal-ca"
fi

# macOS: compile inside builder (linux/amd64) with SDK toolchain.
if [[ "$(uname -s)" == Darwin ]] && [[ "${LWS_HMI_DOCKER:-}" != "1" ]]; then
	exec env LWS_HMI_SKIP_OVERLAY=1 FORCE="$FORCE" OPTEE_OS_VER="$OPTEE_OS_VER" \
		BUILD_JOBS="${BUILD_JOBS:-8}" TA_SIGN_KEY="${TA_SIGN_KEY:-}" \
		bash "$ROOT/scripts/docker-run.sh" \
		bash /work/lws-hmi/scripts/build-secrets-seal.sh
fi

do_build
