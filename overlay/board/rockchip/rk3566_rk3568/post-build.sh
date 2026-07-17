#!/bin/sh
# Run on Buildroot staging target/ before rootfs images are packed (BR2_ROOTFS_POST_BUILD_SCRIPT).
# sshd is disabled at boot — host keys must be baked in at build time.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
LWS_HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"

PURGE="$(dirname "$0")/purge-retired-rootfs-artifacts.sh"
if [ -f "$PURGE" ]; then
	sh "$PURGE" "$TARGET_DIR"
else
	echo "post-build: purge-retired-rootfs-artifacts.sh missing" >&2
	exit 1
fi

ensure_script="$TARGET_DIR/usr/libexec/hmi/ensure-sshd-hostkeys.sh"
if [ ! -f "$ensure_script" ]; then
	ensure_script="$LWS_HMI_ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/ensure-sshd-hostkeys.sh"
fi

if [ ! -f "$ensure_script" ]; then
	echo "post-build: ensure-sshd-hostkeys.sh missing" >&2
	exit 1
fi

sh "$ensure_script" "$TARGET_DIR"

STRIP_FSTAB="$(dirname "$0")/strip-fstab.sh"
if [ -f "$STRIP_FSTAB" ]; then
	bash "$STRIP_FSTAB" "$TARGET_DIR"
fi

SYNC_ENGINE="$(dirname "$0")/sync-flutter-engine.sh"
if [ -f "$SYNC_ENGINE" ]; then
	sh "$SYNC_ENGINE" "$TARGET_DIR"
fi

# Install operator-facing device commands before rootfs image copies are made.
BUILD_LOADER="$LWS_HMI_ROOT/scripts/build-reboot-rockusb-loader.sh"
if [ ! -f "$BUILD_LOADER" ]; then
	echo "post-build: build-reboot-rockusb-loader.sh missing" >&2
	exit 1
fi
bash "$BUILD_LOADER" "$TARGET_DIR"

mkdir -p "$TARGET_DIR/usr/bin"
ln -sf /usr/libexec/hmi/boot-verify.sh "$TARGET_DIR/usr/bin/verify-boot"
ln -sf /usr/libexec/hmi/env-verify.sh "$TARGET_DIR/usr/bin/verify-env"
ln -sf /usr/libexec/hmi/diagnose-hmi.sh "$TARGET_DIR/usr/bin/diagnose-hmi"
ln -sf /usr/libexec/hmi/usb-plug-ssh-diag.sh "$TARGET_DIR/usr/bin/diagnose-usb-ssh"
ln -sf /usr/libexec/hmi/read-device-serial.sh "$TARGET_DIR/usr/bin/read-serial"
ln -sf /usr/libexec/hmi/usb-plug-ssh-start.sh "$TARGET_DIR/usr/bin/start-usb-ssh"
ln -sf /usr/libexec/hmi/usb-plug-ssh-stop.sh "$TARGET_DIR/usr/bin/stop-usb-ssh"
ln -sf /usr/libexec/hmi/usb-plug-ssh-recover.sh "$TARGET_DIR/usr/bin/recover-usb-ssh"
ln -sf /usr/libexec/hmi/reboot-loader "$TARGET_DIR/usr/bin/reboot-loader"
ln -sf /usr/libexec/hmi/change-backlight.sh "$TARGET_DIR/usr/bin/change-backlight"
ln -sf /usr/libexec/hmi/change-volume.sh "$TARGET_DIR/usr/bin/change-volume"
ln -sf /usr/libexec/hmi/change-orientation.sh "$TARGET_DIR/usr/bin/change-orientation"
ln -sf /usr/libexec/hmi/apply-mouse-settings.sh "$TARGET_DIR/usr/bin/apply-mouse-settings"
ln -sf /usr/libexec/hmi/enable-ssh-debug.sh "$TARGET_DIR/usr/bin/enable-ssh-debug"
ln -sf /usr/libexec/hmi/disable-ssh-debug.sh "$TARGET_DIR/usr/bin/disable-ssh-debug"
ln -sf /usr/libexec/hmi/usb-otg-mode.sh "$TARGET_DIR/usr/bin/usb-otg-mode"
ln -sf /usr/libexec/hmi/set-performance-mode.sh "$TARGET_DIR/usr/bin/set-performance-mode"
ln -sf /usr/libexec/wpa/wlan0-time-sync.sh "$TARGET_DIR/usr/bin/sync-time"
rm -f \
	"$TARGET_DIR/usr/bin/boot-verify" \
	"$TARGET_DIR/usr/bin/env-verify" \
	"$TARGET_DIR/usr/bin/read-device-serial" \
	"$TARGET_DIR/usr/bin/reboot-rockusb-loader" \
	"$TARGET_DIR/usr/bin/lws-hmi-backlight-apply"

# App bundle must not ship engine/icu (system paths only).
rm -f \
	"$TARGET_DIR/opt/hmi/lib/libflutter_engine.so" \
	"$TARGET_DIR/opt/hmi/data/icudtl.dat"

# Retired helper scripts (Buildroot overlay copy does not delete removed files).
rm -f \
	"$TARGET_DIR/usr/libexec/hmi/ab-upgrade-app-only.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-backlight-apply.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-eth0-apply.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-wpa-run.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-settings-restore.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-prefs-bind.sh"

# Baked etc/ must not reference removed monolithic helper/state dirs.
stale_refs=""
if command -v grep >/dev/null 2>&1; then
	stale_refs="$(grep -r '/usr/lib/lws-hmi\|/var/lib/lws-hmi' "$TARGET_DIR/etc" 2>/dev/null || true)"
fi
if [ -n "$stale_refs" ]; then
	echo "post-build: ERROR stale lws-hmi paths still baked under etc/:" >&2
	printf '%s\n' "$stale_refs" >&2
	echo "post-build: run make apply-overlay && make build-rootfs (purge lws-hmi-fs-overlay)" >&2
	exit 1
fi
stale_etc_names=""
if command -v find >/dev/null 2>&1; then
	for f in $(find "$TARGET_DIR/etc" -name '*lws-hmi*' 2>/dev/null); do
		[ -n "$f" ] || continue
		stale_etc_names="${stale_etc_names:+$stale_etc_names }${f#$TARGET_DIR/}"
	done
fi
if [ -n "$stale_etc_names" ]; then
	echo "post-build: ERROR retired *lws-hmi* etc basenames still present:" >&2
	printf '%s\n' "$stale_etc_names" >&2
	exit 1
fi

# Rockchip bluez-alsa.mk uses --enable-debug; configure then links -lSegFault when
# glibc's libSegFault.so is in the sysroot. Buildroot does not install that .so
# on target → bluealsa exits 127 ("cannot open shared object file").
# Copy from staging/sysroot until/unless the package is rebuilt without -lSegFault.
if [ -x "$TARGET_DIR/usr/bin/bluealsa" ]; then
	if [ ! -e "$TARGET_DIR/usr/lib/libSegFault.so" ] && \
		[ ! -e "$TARGET_DIR/lib/libSegFault.so" ]; then
		seg_src=""
		for cand in \
			"${STAGING_DIR:-}/usr/lib/libSegFault.so" \
			"${STAGING_DIR:-}/lib/libSegFault.so" \
			"$(dirname "$TARGET_DIR")/host/aarch64-buildroot-linux-gnu/sysroot/usr/lib/libSegFault.so"
		do
			if [ -f "$cand" ]; then
				seg_src="$cand"
				break
			fi
		done
		if [ -n "$seg_src" ]; then
			mkdir -p "$TARGET_DIR/usr/lib"
			cp -a "$seg_src" "$TARGET_DIR/usr/lib/libSegFault.so"
			echo "post-build: installed usr/lib/libSegFault.so (bluealsa)"
		else
			echo "post-build: WARN libSegFault.so not found — bluealsa may fail" >&2
		fi
	fi
fi

sh "$(dirname "$0")/install-systemctl-wrapper.sh" "$TARGET_DIR" post-build
