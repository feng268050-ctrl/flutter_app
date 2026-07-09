#!/bin/bash -e

# Plan A: enable hmi.service only; disable non-critical units at image build time.

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

WANTS="$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
SYSINIT_WANTS="$TARGET_DIR/etc/systemd/system/sysinit.target.wants"
SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"
mkdir -p "$WANTS" "$SYSINIT_WANTS"

# Units that must not auto-start at boot (§3.6.0 / §6.4). Include sshd.socket — OpenSSH
# often enables socket activation instead of sshd.service.
DISABLE_AT_BOOT=(
	lws-hmi-debug-boot.service
	mediamtx.service
	sshd.service
	sshd.socket
	bluetooth.service
)

link_unit() {
	local unit="$1"
	local path="/etc/systemd/system/$unit"
	ln -sf "$path" "$WANTS/$unit"
}

disable_boot_unit() {
	local unit="$1"
	local wants_dir link
	for wants_dir in "$SYSTEMD_DIR"/*.wants; do
		[ -d "$wants_dir" ] || continue
		link="$wants_dir/$unit"
		if [ -e "$link" ] || [ -L "$link" ]; then
			rm -f "$link"
			echo "lws-hmi-systemd: removed ${link#$TARGET_DIR/}"
		fi
	done
}

# KPI path: display init early; flutter-pi after local-fs.
if [ -f "$TARGET_DIR/etc/systemd/system/param-update.service" ]; then
	ln -sf "/etc/systemd/system/param-update.service" \
		"$SYSINIT_WANTS/param-update.service"
	echo "lws-hmi-systemd: enabled param-update.service (sysinit.target)"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/mainserver.service" ]; then
	link_unit mainserver.service
	echo "lws-hmi-systemd: enabled mainserver.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-performance.service" ]; then
	link_unit lws-hmi-performance.service
	echo "lws-hmi-systemd: enabled lws-hmi-performance.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/hmi.service" ]; then
	link_unit hmi.service
	echo "lws-hmi-systemd: enabled hmi.service"
fi

# Do not block boot KPI; start after home or from App (§6.4).
for unit in "${DISABLE_AT_BOOT[@]}"; do
	if [ -f "$TARGET_DIR/etc/systemd/system/$unit" ] || \
		[ -f "$TARGET_DIR/lib/systemd/system/$unit" ] || \
		[ -f "$TARGET_DIR/usr/lib/systemd/system/$unit" ]; then
		disable_boot_unit "$unit"
	fi
done

# Retired single-image debug path — remove if stale overlay sync left files on disk.
rm -f \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-debug-boot.service" \
	"$TARGET_DIR/usr/lib/lws-hmi/debug-boot.sh"
disable_boot_unit lws-hmi-debug-boot.service

# Plan A: no kernel cmdline ip= and no networkd — mask noisy generator unit.
if [ -d "$SYSTEMD_DIR" ]; then
	ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"
	echo "lws-hmi-systemd: masked systemd-network-generator.service"
fi

# Install usr/lib/lws-hmi/*.sh from SDK buildroot board overlay (synced by apply-overlay).
# Do not rely on LWS_HMI_ROOT — Rockchip post-hooks may not inherit it from docker-run.
install_lws_hmi_helper_scripts() {
	local sdk_dir overlay_scripts script
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -z "$sdk_dir" ]; then
		sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
	fi
	overlay_scripts="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/usr/lib/lws-hmi"
	if [ ! -d "$overlay_scripts" ]; then
		echo "lws-hmi-systemd: skip helper scripts (missing $overlay_scripts — run make apply-overlay)"
		return 0
	fi
	install -d "$TARGET_DIR/usr/lib/lws-hmi"
	for script in "$overlay_scripts"/*.sh; do
		[ -f "$script" ] || continue
		install -m 0755 "$script" "$TARGET_DIR/usr/lib/lws-hmi/$(basename "$script")"
		echo "lws-hmi-systemd: installed /usr/lib/lws-hmi/$(basename "$script")"
	done
}
install_lws_hmi_helper_scripts
