#!/bin/sh
# Install /usr/bin/systemctl wrapper → systemctl-poweroff-wrapper.sh; real → systemctl.real.
# Buildroot usr-merge: /bin → usr/bin — never ln a second path that aliases the same file.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
wrapper="$TARGET_DIR/usr/libexec/hmi/systemctl-poweroff-wrapper.sh"
real="$TARGET_DIR/usr/bin/systemctl.real"
ctl="$TARGET_DIR/usr/bin/systemctl"
bin_ctl="$TARGET_DIR/bin/systemctl"
tag="${2:-install-systemctl-wrapper}"

fail() {
	echo "$tag: ERROR: $*" >&2
	exit 1
}

[ -f "$wrapper" ] || fail "missing $wrapper (run make apply-overlay)"

bin_merged_with_usr() {
	[ -L "$TARGET_DIR/bin" ] || return 1
	[ "$(readlink "$TARGET_DIR/bin")" = "usr/bin" ]
}

install_links() {
	mkdir -p "$TARGET_DIR/usr/bin" "$TARGET_DIR/bin"
	rm -f "$ctl" "$bin_ctl"
	# Relative link: ../libexec from /usr/bin → /usr/libexec (not ../../ → /libexec).
	ln -sf ../libexec/hmi/systemctl-poweroff-wrapper.sh "$ctl"
	if ! bin_merged_with_usr; then
		ln -sf ../usr/bin/systemctl "$bin_ctl"
	fi
}

wrapper_installed() {
	[ -L "$ctl" ] || return 1
	case "$(readlink "$ctl" 2>/dev/null)" in
	../libexec/hmi/systemctl-poweroff-wrapper.sh) ;;
	../../libexec/hmi/systemctl-poweroff-wrapper.sh)
		# Broken legacy link (resolves to /libexec, not /usr/libexec).
		return 1
		;;
	/usr/libexec/hmi/systemctl-poweroff-wrapper.sh)
		# Normalize legacy absolute symlink (breaks staging verify -e checks).
		return 1
		;;
	*) return 1 ;;
	esac
	[ -e "$ctl" ] || return 1
	if bin_merged_with_usr; then
		return 0
	fi
	[ -L "$bin_ctl" ] && [ "$(readlink "$bin_ctl" 2>/dev/null)" = "../usr/bin/systemctl" ]
}

if wrapper_installed && [ -x "$real" ]; then
	echo "$tag: systemctl wrapper already installed"
	exit 0
fi

if [ -x "$real" ]; then
	install_links
	echo "$tag: repaired systemctl symlinks (systemctl.real present)"
	exit 0
fi

mkdir -p "$TARGET_DIR/usr/bin"
rm -f "$bin_ctl" "$TARGET_DIR/bin/systemctl.real"

capture_real_from() {
	local cand
	for cand in "$@"; do
		[ -e "$cand" ] || [ -L "$cand" ] || continue
		rm -f "$real"
		if cp -L "$cand" "$real" 2>/dev/null; then
			chmod +x "$real"
			echo "$tag: captured systemctl from $cand"
			return 0
		fi
	done
	return 1
}

capture_real() {
	capture_real_from \
		"$ctl" \
		"$bin_ctl" \
		"$TARGET_DIR/usr/lib/systemd/systemctl" \
		"$TARGET_DIR/lib/systemd/systemctl" || \
	capture_real_from \
		"${STAGING_DIR:+$STAGING_DIR/usr/bin/systemctl}" \
		"${STAGING_DIR:+$STAGING_DIR/bin/systemctl}" \
		"${STAGING_DIR:+$STAGING_DIR/usr/lib/systemd/systemctl}" \
		"${STAGING_DIR:+$STAGING_DIR/lib/systemd/systemctl}"
}

if [ -e "$ctl" ] && [ ! -L "$ctl" ]; then
	mv "$ctl" "$real"
elif [ -e "$bin_ctl" ] && [ ! -L "$bin_ctl" ] && ! bin_merged_with_usr; then
	mv "$bin_ctl" "$real"
elif capture_real; then
	:
else
	fail "no systemctl binary under target/ or STAGING_DIR — rm -rf target and rebuild rootfs"
fi

install_links
echo "$tag: wrapped systemctl for graceful poweroff"
