#!/usr/bin/env bash
# After build-rootfs: confirm overlay files in target/ and Plan A systemd in rootfs.ext2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(bash "$ROOT/scripts/link-sdk.sh" --print 2>/dev/null || true)"
source "$ROOT/scripts/prebuilt-common.sh"

if [[ "$(uname -s)" == Darwin && "${1:-}" != "--inside-docker" ]]; then
	exec bash "$ROOT/scripts/docker-run.sh" bash -lc \
		'bash /work/lws-hmi/scripts/verify-rootfs-overlay.sh --inside-docker'
fi

check_systemd_wants() {
	local root="$1"
	local label="$2"
	local wants="$root/etc/systemd/system/multi-user.target.wants"
	local missing=0

	unit_wants_link() {
		# .wants entries use absolute symlinks (/etc/...); do not follow onto host.
		[[ -L "$wants/$1" || -f "$wants/$1" ]]
	}

	echo ""
	echo "--- $label: multi-user.target.wants ---"
	if [[ ! -d "$wants" ]]; then
		echo "FAIL: missing $wants" >&2
		return 1
	fi
	ls -la "$wants" 2>/dev/null || true

	for unit in lws-hmi-debug-boot.service mediamtx.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service; do
		if unit_wants_link "$unit"; then
			echo "FAIL: $unit still enabled in $label" >&2
			missing=1
		else
			echo "OK:  $unit not in $label wants"
		fi
	done

	for unit in hmi.service mainserver.service lws-hmi-performance.service; do
		if unit_wants_link "$unit"; then
			echo "OK:  $unit enabled in $label"
		else
			echo "FAIL: $unit missing from $label wants" >&2
			missing=1
		fi
	done

	local sysinit_wants="$root/etc/systemd/system/sysinit.target.wants"
	if [[ -d "$sysinit_wants" ]]; then
		for unit in lws-hmi-debug-boot.service wifibt-init.service log-guardian.service; do
			if [[ -L "$sysinit_wants/$unit" || -f "$sysinit_wants/$unit" ]]; then
				echo "FAIL: $unit still enabled in $label sysinit.target.wants" >&2
				missing=1
			else
				echo "OK:  $unit not in $label sysinit.target.wants"
			fi
		done
	fi

	return "$missing"
}

check_rootfs_image() {
	local out_dir="$1"
	local img="$out_dir/images/rootfs.ext2"
	local mnt
	mnt="$(mktemp -d)"

	if [[ ! -r "$img" ]]; then
		echo ""
		echo "WARN: rootfs.ext2 missing — skip flash image systemd check"
		echo "  (run: make build-rootfs to regenerate images/rootfs.ext2)"
		return 0
	fi

	if ! mount -o loop,ro "$img" "$mnt" 2>/dev/null; then
		echo ""
		echo "FAIL: could not mount $img for verification" >&2
		rmdir "$mnt" 2>/dev/null || true
		return 1
	fi

	check_systemd_wants "$mnt" "rootfs.ext2 (flash image)"
	local rc=$?
	umount "$mnt"
	rmdir "$mnt"
	return "$rc"
}

run_check() {
	local target="$1"
	local out_dir
	local helper="$target/usr/lib/lws-hmi"
	local missing=0

	out_dir="$(dirname "$target")"
	echo "=== verify-rootfs-overlay ==="
	echo "target: $target"

	if [[ ! -d "$target" ]]; then
		echo "FAIL: staging target missing — run: make build-rootfs" >&2
		echo "  (expected buildroot/output/<RK_BUILDROOT_CFG>/target, e.g. rockchip_rk3566_rk3568_lws_hmi)" >&2
		exit 1
	fi

	if [[ ! -d "$helper" ]]; then
		echo "FAIL: $helper missing — overlay not applied or wrong Buildroot profile" >&2
		exit 1
	fi

	echo ""
	echo "--- $helper ---"
	ls -la "$helper" || true

	for f in boot-verify.sh ynh960-display-init.sh set-performance-mode.sh; do
		if [[ -x "$helper/$f" ]]; then
			echo "OK:  $f"
		else
			echo "FAIL: $f missing or not executable" >&2
			missing=1
		fi
	done

	if [[ -f "$target/etc/systemd/system/hmi.service" ]]; then
		echo "OK:  hmi.service in target"
	else
		echo "FAIL: hmi.service missing from target/etc/systemd/system" >&2
		missing=1
	fi

	for f in \
		"$target/etc/systemd/system/lws-hmi-debug-boot.service" \
		"$target/etc/systemd/system/lws-hmi-boot-kpi.service" \
		"$target/usr/lib/lws-hmi/debug-boot.sh" \
		"$target/usr/lib/lws-hmi/boot-kpi-watch.sh" \
		"$target/usr/lib/lws-hmi/configure-camera-eth0.sh" \
		"$target/usr/lib/lws-hmi/enable-ssh-debug.sh"; do
		if [[ -e "$f" ]]; then
			echo "FAIL: retired artifact still in target: $f" >&2
			missing=1
		else
			echo "OK:  $(basename "$f") absent from target"
		fi
	done

	check_systemd_wants "$target" "staging target" || missing=1
	check_rootfs_image "$out_dir" || missing=1

	echo ""
	if [[ "$missing" -eq 0 ]]; then
		echo "=== verify-rootfs-overlay: PASS ==="
		exit 0
	fi
	echo "=== verify-rootfs-overlay: FAIL ===" >&2
	exit 1
}

if [[ "${1:-}" == "--inside-docker" ]]; then
	run_check "$(resolve_br_target "${LWS_HMI_SDK_DIR:-/work/sdk}")"
	exit $?
fi

if [[ -z "$SDK" || ! -d "$SDK" ]]; then
	echo "ERROR: SDK not linked. Run: make setup" >&2
	exit 1
fi

run_check "$(resolve_br_target "$SDK")"
