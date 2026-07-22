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

SYNC_ELINUX="$(dirname "$0")/sync-flutter-embedded-linux.sh"
if [ -f "$SYNC_ELINUX" ]; then
	sh "$SYNC_ELINUX" "$TARGET_DIR"
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
ln -sf /usr/libexec/hmi/change-orientation.sh "$TARGET_DIR/usr/bin/change-orientation"
ln -sf /usr/libexec/hmi/enable-ssh-debug.sh "$TARGET_DIR/usr/bin/enable-ssh-debug"
ln -sf /usr/libexec/hmi/disable-ssh-debug.sh "$TARGET_DIR/usr/bin/disable-ssh-debug"
ln -sf /usr/libexec/hmi/usb-otg-mode.sh "$TARGET_DIR/usr/bin/usb-otg-mode"
ln -sf /usr/libexec/hmi/set-performance-mode.sh "$TARGET_DIR/usr/bin/set-performance-mode"
# Deprecated iface-named path (half-upgraded boards / old callers).
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


# Retired Kind C helpers — HAL owns persist/restore for most prefs.
# apply-mouse-settings is kept: Weston needs ini rewrite + HMI restart.
rm -f \
	"$TARGET_DIR/usr/bin/change-backlight" \
	"$TARGET_DIR/usr/bin/change-volume" \
	"$TARGET_DIR/usr/bin/apply-proxy" \
	"$TARGET_DIR/usr/bin/sync-time" \
	"$TARGET_DIR/usr/libexec/hmi/restore-settings.sh" \
	"$TARGET_DIR/usr/libexec/hmi/change-backlight.sh" \
	"$TARGET_DIR/usr/libexec/hmi/change-volume.sh" \
	"$TARGET_DIR/usr/libexec/hmi/time-sync.sh" \
	"$TARGET_DIR/usr/libexec/wpa/wlan0-time-sync.sh" \
	"$TARGET_DIR/usr/libexec/network/apply-proxy.sh" \
	"$TARGET_DIR/etc/systemd/system/settings-restore.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/settings-restore.service"

# Operator symlink for mouse prefs (Weston + flutter-pi).
if [ -f "$TARGET_DIR/usr/libexec/hmi/apply-mouse-settings.sh" ]; then
	ln -sf /usr/libexec/hmi/apply-mouse-settings.sh \
		"$TARGET_DIR/usr/bin/apply-mouse-settings"
fi

# Embedder mutual exclusion. Same Buildroot output/ is reused when flipping
# between make build-rootfs (Weston) and build-rootfs-flutter-pi — leftover
# binaries from the other stack remain under target/ until purged.
#
# Intent (first match wins):
#   1) Buildroot .config next to TARGET_DIR (authoritative after lunch/defconfig)
#   2) LWS_HMI_WESTON from docker-run (default 1 = Weston)
wayland_img=0
br_config="$(dirname "$TARGET_DIR")/.config"
if [ -f "$br_config" ] && grep -qE '^BR2_PACKAGE_FLUTTER_EMBEDDED_LINUX=y' "$br_config"; then
	wayland_img=1
elif [ -f "$br_config" ] && grep -qE '^BR2_PACKAGE_FLUTTER_PI=y' "$br_config"; then
	wayland_img=0
else
	case "${LWS_HMI_WESTON:-1}" in
	0 | n | N | no | NO | false | FALSE) wayland_img=0 ;;
	*) wayland_img=1 ;;
	esac
fi

if [ "$wayland_img" -eq 1 ]; then
	rm -f "$TARGET_DIR/usr/bin/flutter-pi"
	echo "post-build: weston image — purged flutter-pi (if leftover)"
else
	rm -f \
		"$TARGET_DIR/usr/bin/weston" \
		"$TARGET_DIR/usr/bin/flutter-wayland-client"
	# Drop compositor plugins/libs so a stale weston cannot be started by hand.
	rm -rf \
		"$TARGET_DIR/usr/lib/weston" \
		"$TARGET_DIR/usr/share/weston"
	rm -f "$TARGET_DIR/usr/lib"/libweston-*.so* \
		"$TARGET_DIR/usr/lib"/libweston-desktop-*.so* 2>/dev/null || true
	echo "post-build: flutter-pi image — purged Weston/eLinux client (if leftover)"
fi

has_pi=0
has_weston=0
if [ -x "$TARGET_DIR/usr/bin/flutter-pi" ]; then
	has_pi=1
fi
if [ -x "$TARGET_DIR/usr/bin/weston" ] && \
	[ -x "$TARGET_DIR/usr/bin/flutter-wayland-client" ]; then
	has_weston=1
fi
if [ "$has_pi" -eq 1 ] && [ "$has_weston" -eq 1 ]; then
	echo "post-build: ERROR rootfs still has both flutter-pi and Weston/eLinux after purge" >&2
	exit 1
fi
mkdir -p "$TARGET_DIR/etc/hmi"
if [ "$wayland_img" -eq 1 ]; then
	if [ "$has_weston" -ne 1 ]; then
		echo "post-build: ERROR LWS_HMI_WESTON=1 but weston/flutter-wayland-client missing" >&2
		exit 1
	fi
	printf '%s\n' weston >"$TARGET_DIR/etc/hmi/display-stack"
	echo "post-build: display-stack=weston"
elif [ "$has_pi" -eq 1 ]; then
	printf '%s\n' flutter-pi >"$TARGET_DIR/etc/hmi/display-stack"
	echo "post-build: display-stack=flutter-pi"
else
	echo "post-build: ERROR default Weston image missing weston/flutter-wayland-client" >&2
	echo "post-build: after a flutter-pi build, restore with:" >&2
	echo "post-build:   bash scripts/ensure-mali-variant.sh wayland-gbm" >&2
	echo "post-build:   (or: make prepare-rootfs && make build-rootfs)" >&2
	exit 1
fi

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
