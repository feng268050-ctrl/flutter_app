#!/bin/sh
# Mode-aware HMI launcher: Weston + flutter-wayland-client (eLinux).
set -eu

# Match systemd IgnoreSIGPIPE=yes. Outside hmi.service (make debug-app via
# start-stop-daemon) a SIGPIPE from Wayland/DBus/helper teardown would exit
# the embedder with code 141 and tear down Weston.
trap '' PIPE

. /usr/libexec/board/paths.sh 2>/dev/null || true

BUNDLE=/opt/hmi
MODE_FILE="$BUNDLE/runtime-mode.json"
MODE=release
DISPLAY_CONF="${VAR_HAL:-/var/lib/hal}/display.conf"
LEGACY_ORIENTATION_FILE=/var/lib/hmi/display-orientation
LEGACY_ORIENTATION_HAL=/var/lib/hal/display-orientation
ELINUX_CLIENT=/usr/bin/flutter-wayland-client

# Last-resort removed: orientation MUST come from display.conf or OEM screen.env.
HMI_ORIENTATION=
SCREEN_ENV="${RUN_HMI:-/run/hmi}/screen.env"

# RK809 speaker path (ParamUpdate also sets this; re-assert before HMI audio smoke).
if command -v amixer >/dev/null 2>&1; then
	amixer -q sset 'Playback Path' 'RING_SPK_HP' 2>/dev/null || true
fi

# Align lock LEDs with a fresh xkb_state (all clear) before embedder opens input.
# Stale LED-on + Mod2-off looks like an inverted keypad.
for led in /sys/class/leds/input*::numlock /sys/class/leds/input*::capslock \
	/sys/class/leds/input*::scrolllock; do
	[ -w "$led/brightness" ] || continue
	echo 0 >"$led/brightness" 2>/dev/null || true
done

# curl/OpenSSL tools. Dart HttpClient loads the same path explicitly in-app.
if [ -s /etc/ssl/certs/ca-certificates.crt ]; then
	export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
	export SSL_CERT_DIR=/etc/ssl/certs
fi

read_json_field() {
	file="$1"
	key="$2"
	grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
		| sed 's/.*"\([^"]*\)"$/\1/' \
		| head -1
}

conf_get() {
	# usage: conf_get <file> <key>
	file="$1"
	key="$2"
	[ -f "$file" ] || return 0
	grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]'
}

upsert_conf_key() {
	conf="$1"
	key="$2"
	value="$3"
	mkdir -p "$(dirname "$conf")"
	tmp="$(mktemp "${conf}.XXXXXX")"
	if [ -f "$conf" ]; then
		grep -vE "^${key}=" "$conf" >"$tmp" 2>/dev/null || true
	else
		: >"$tmp"
	fi
	printf '%s=%s\n' "$key" "$value" >>"$tmp"
	mv -f "$tmp" "$conf"
}

# Resolve orientation: operator display.conf → OEM screen.env (no silent default).
token="$(conf_get "$DISPLAY_CONF" orientation | tr '[:upper:]' '[:lower:]')"
if [ -z "$token" ]; then
	for legacy in "$LEGACY_ORIENTATION_HAL" "$LEGACY_ORIENTATION_FILE"; do
		if [ -f "$legacy" ]; then
			token="$(tr -d '[:space:]' <"$legacy" | tr '[:upper:]' '[:lower:]')"
			case "$token" in
			portrait | landscape)
				upsert_conf_key "$DISPLAY_CONF" orientation "$token"
				rm -f "$legacy"
				;;
			*)
				token=""
				;;
			esac
			break
		fi
	done
fi
orient_src=display.conf
if [ -z "$token" ]; then
	[ -f "$SCREEN_ENV" ] || {
		echo "hmi-launch: missing $SCREEN_ENV — oem-compose must succeed first" >&2
		exit 1
	}
	# shellcheck source=/dev/null
	. "$SCREEN_ENV"
	token="$(printf '%s' "${SCREEN_DEFAULT_ORIENTATION:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
	orient_src="$SCREEN_ENV"
fi
[ -n "$token" ] || {
	echo "hmi-launch: empty orientation (display.conf and SCREEN_DEFAULT_ORIENTATION) — fix OEM screen.json" >&2
	exit 1
}
case "$token" in
portrait | portrait_up)
	HMI_ORIENTATION=portrait_up
	;;
landscape | landscape_left)
	HMI_ORIENTATION=landscape_left
	;;
landscape_right)
	HMI_ORIENTATION=landscape_right
	;;
portrait_down)
	HMI_ORIENTATION=portrait_down
	;;
*)
	echo "hmi-launch: unknown orientation '$token' from $orient_src" >&2
	exit 1
	;;
esac
echo "hmi-launch: orientation=$HMI_ORIENTATION (from $orient_src)" >&2

if [ -f "$MODE_FILE" ]; then
	MODE="$(read_json_field "$MODE_FILE" mode)"
	MODE="${MODE:-release}"
fi

if [ ! -x /usr/bin/weston ] || [ ! -x "$ELINUX_CLIENT" ]; then
	echo "hmi-launch: weston or flutter-wayland-client missing" >&2
	exit 1
fi

# Debug: same client binary + cached debug engine via LD_LIBRARY_PATH (Sony).
# Fail closed — never fall back to AOT libapp.so against a JIT-only tree.
ELINUX_LD_LIBRARY_PATH=
if [ "$MODE" = "debug" ]; then
	VER="$(read_json_field "$MODE_FILE" engine_version)"
	RT="/var/lib/hmi/debug-runtime/${VER}"
	if [ -z "$VER" ]; then
		echo "hmi-launch: debug mode missing engine_version in $MODE_FILE" >&2
		exit 1
	fi
	if [ ! -f "$RT/libflutter_engine.so" ] || [ ! -f "$RT/icudtl.dat" ]; then
		echo "hmi-launch: debug runtime incomplete at $RT" >&2
		echo "hmi-launch: need libflutter_engine.so and icudtl.dat (make debug-app)" >&2
		exit 1
	fi
	if [ ! -f "$BUNDLE/data/flutter_assets/kernel_blob.bin" ]; then
		echo "hmi-launch: missing debug kernel $BUNDLE/data/flutter_assets/kernel_blob.bin" >&2
		exit 1
	fi
	# eLinux DartProject expects ICU at <bundle>/data/icudtl.dat.
	# Symlink (not copy) so /opt/hmi does not carry a payload duplicate.
	mkdir -p "$BUNDLE/data"
	rm -f "$BUNDLE/data/icudtl.dat"
	ln -sf "$RT/icudtl.dat" "$BUNDLE/data/icudtl.dat" || {
		echo "hmi-launch: failed to link $BUNDLE/data/icudtl.dat → $RT/icudtl.dat" >&2
		exit 1
	}
	ELINUX_LD_LIBRARY_PATH="$RT"
else
	if [ ! -f "$BUNDLE/lib/libapp.so" ]; then
		echo "hmi-launch: missing release AOT $BUNDLE/lib/libapp.so" >&2
		exit 1
	fi
	# eLinux looks for ICU under bundle/data/; point at rootfs system ICU.
	icu_src=
	for icu in \
		/usr/share/flutter/release/data/icudtl.dat \
		/usr/share/flutter/icudtl.dat; do
		if [ -e "$icu" ]; then
			icu_src="$icu"
			break
		fi
	done
	if [ -n "$icu_src" ]; then
		mkdir -p "$BUNDLE/data"
		# Replace a prior cp payload with a symlink (verify-env forbids a real file).
		rm -f "$BUNDLE/data/icudtl.dat"
		ln -sf "$icu_src" "$BUNDLE/data/icudtl.dat" || {
			echo "hmi-launch: failed to link $BUNDLE/data/icudtl.dat → $icu_src" >&2
			exit 1
		}
	fi
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# GStreamer (Sony video_player) expects a writable cache for the plugin
# registry. systemd does not set HOME for hmi.service.
export HOME="${HOME:-/root}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$XDG_CACHE_HOME"

# Dart/Flutter DateTime.now() follows TZ / libc localtime. Prefer product prefs,
# then /etc/localtime, then Asia/Shanghai (ynh960 default). Without this, ICU may
# stay on UTC and Settings/status clocks read eight hours behind CST.
resolve_hmi_tz() {
	if [ -n "${TZ:-}" ]; then
		printf '%s\n' "$TZ"
		return 0
	fi
	if [ -f /var/lib/hal/datetime.conf ]; then
		t=$(sed -n 's/^timezone=//p' /var/lib/hal/datetime.conf 2>/dev/null | head -n1 | tr -d '\r')
		if [ -n "$t" ]; then
			printf '%s\n' "$t"
			return 0
		fi
	fi
	if [ -L /etc/localtime ]; then
		target=$(readlink /etc/localtime 2>/dev/null || true)
		case "$target" in
		*/zoneinfo/*)
			printf '%s\n' "${target##*/zoneinfo/}"
			return 0
			;;
		esac
	fi
	printf '%s\n' "Asia/Shanghai"
}
export TZ="$(resolve_hmi_tz)"

# Rockchip post-hook 10-weston overwrites /etc/xdg/weston/weston.ini.
# Own config via --config under XDG_RUNTIME_DIR (transform + mouse prefs).
BOARD_ID=""
if [ -f "${RUN_HMI:-/run/hmi}/oem.env" ]; then
	# shellcheck disable=SC1090
	. "${RUN_HMI:-/run/hmi}/oem.env" 2>/dev/null || true
	BOARD_ID="${BOARD_ID:-}"
fi
case "$HMI_ORIENTATION" in
portrait_up)
	WESTON_TRANSFORM=normal
	;;
*)
	# Device panel is portrait-native → rotate-270 for landscape UI.
	# Emulator virt screen is already landscape (sim_virt screen.json).
	if [ "$BOARD_ID" = "sim" ] || grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null; then
		WESTON_TRANSFORM=normal
	else
		WESTON_TRANSFORM=rotate-270
	fi
	;;
esac

# shellcheck source=/dev/null
. /usr/libexec/display/weston-hmi-config.sh
WESTON_INI="$XDG_RUNTIME_DIR/weston.ini"
weston_write_hmi_ini "$WESTON_INI" "$WESTON_TRANSFORM"

is_emulator=0
if [ "$BOARD_ID" = "sim" ] || grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null; then
	is_emulator=1
fi

WESTON_RENDERER_ARGS=""
EMU_MESA_LIB=""
EMU_MESA_SRC=""
if [ "$is_emulator" -eq 1 ]; then
	# Host VirGL only: virtio-gpu-gl + Mesa virtio_gpu (no softpipe / pixman GLES).
	# Prefer debugfs (stable); dmesg can miss the early line after ring wrap / dmesg -c.
	echo "hmi-launch: emulator — DRM: $(ls /sys/class/drm 2>/dev/null | tr '\n' ' ')" >&2
	if ! grep -q 'virgl[[:space:]]*:[[:space:]]*yes' \
		/sys/kernel/debug/dri/*/virtio-gpu-features 2>/dev/null \
		&& ! dmesg 2>/dev/null | grep -q 'features: +virgl'; then
		echo "hmi-launch: ERROR: virtio-gpu has no VirGL (need qemu-virgl + virtio-gpu-gl)" >&2
		echo "hmi-launch: ERROR: host: make setup-emulator-qemu && make emulator" >&2
		exit 1
	fi
	# Stale 9p (host rm -rf while QEMU held the share) leaves an empty mount.
	if mountpoint -q /run/lws-gl 2>/dev/null || grep -q ' /run/lws-gl ' /proc/mounts 2>/dev/null; then
		if [ ! -d /run/lws-gl/lib ]; then
			echo "hmi-launch: emulator — stale empty 9p at /run/lws-gl; remounting" >&2
			umount /run/lws-gl 2>/dev/null || umount -l /run/lws-gl 2>/dev/null || true
		fi
	fi
	if [ -d /run/lws-gl/lib ]; then
		EMU_MESA_SRC=/run/lws-gl
	else
		mkdir -p /run/lws-gl
		if mount -t 9p -o trans=virtio,version=9p2000.L,msize=262144 lws_gl /run/lws-gl 2>/dev/null \
			|| mount -t 9p -o trans=virtio,version=9p2000.L lws_gl /run/lws-gl 2>/dev/null; then
			EMU_MESA_SRC=/run/lws-gl
			echo "hmi-launch: emulator — mounted 9p lws_gl → /run/lws-gl" >&2
		fi
	fi
	if [ -z "$EMU_MESA_SRC" ] || [ ! -d "$EMU_MESA_SRC/lib/dri" ]; then
		echo "hmi-launch: ERROR: no guest Mesa (9p lws_gl) — host: make fetch-emulator-swgl" >&2
		exit 1
	fi
	if [ ! -f "$EMU_MESA_SRC/lib/libweston-14/gl-renderer.so" ] \
		|| [ ! -f "$EMU_MESA_SRC/lib/libweston-14/drm-backend.so" ]; then
		echo "hmi-launch: ERROR: missing Mesa-patched Weston modules under $EMU_MESA_SRC/lib/libweston-14" >&2
		echo "hmi-launch: ERROR: host: make fetch-emulator-swgl" >&2
		exit 1
	fi
	WESTON_RENDERER_ARGS="--renderer=gl"
fi

# Cache 9p Mesa → tmpfs; bind-mount Mesa over Mali stubs; LD_PRELOAD GBM shims.
EMU_MESA_DRI=""
EMU_EGL_VENDOR=""
EMU_LD_PRELOAD=""
if [ "$is_emulator" -eq 1 ]; then
	EMU_MESA_CACHE=/run/lws-gl-cache
	if [ ! -f "$EMU_MESA_CACHE/lib/dri/virtio_gpu_dri.so" ]; then
		echo "hmi-launch: emulator — caching Mesa $EMU_MESA_SRC → $EMU_MESA_CACHE" >&2
		rm -rf "$EMU_MESA_CACHE"
		mkdir -p "$EMU_MESA_CACHE"
		cp -a "$EMU_MESA_SRC/lib" "$EMU_MESA_CACHE/"
		cp -a "$EMU_MESA_SRC/bin" "$EMU_MESA_CACHE/" 2>/dev/null || true
		if [ -d "$EMU_MESA_SRC/share/glvnd" ]; then
			mkdir -p "$EMU_MESA_CACHE/share"
			cp -a "$EMU_MESA_SRC/share/glvnd" "$EMU_MESA_CACHE/share/"
		fi
	fi
	GL_ROOT="$EMU_MESA_CACHE"
	EMU_MESA_LIB="$GL_ROOT/lib"
	EMU_MESA_DRI="$GL_ROOT/lib/dri"
	if [ -d "$GL_ROOT/share/glvnd/egl_vendor.d" ]; then
		EMU_EGL_VENDOR="$GL_ROOT/share/glvnd/egl_vendor.d"
	fi
	if [ ! -f "$EMU_MESA_LIB/libmali-hook.so.1" ]; then
		echo "hmi-launch: ERROR: missing VirGL mali-hook stub ($EMU_MESA_LIB/libmali-hook.so.1)" >&2
		echo "hmi-launch: ERROR: host: make fetch-emulator-swgl" >&2
		exit 1
	fi
	# Overlay Mali-linked product binaries/libs with Mesa-patched copies.
	emu_bind() {
		src="$1"
		dst="$2"
		[ -f "$src" ] && [ -e "$dst" ] || return 0
		umount "$dst" 2>/dev/null || true
		mount --bind "$src" "$dst"
	}
	emu_bind "$EMU_MESA_LIB/libweston-14/gl-renderer.so" /usr/lib/libweston-14/gl-renderer.so
	emu_bind "$EMU_MESA_LIB/libweston-14/drm-backend.so" /usr/lib/libweston-14/drm-backend.so
	emu_bind "$EMU_MESA_LIB/libweston-14.so.0" /usr/lib/libweston-14.so.0
	emu_bind "$EMU_MESA_LIB/libweston-14.so.0.0.1" /usr/lib/libweston-14.so.0.0.1
	emu_bind "$EMU_MESA_LIB/libexec_weston.so.0" /usr/lib/weston/libexec_weston.so.0
	emu_bind "$EMU_MESA_LIB/libexec_weston.so.0.0.0" /usr/lib/weston/libexec_weston.so.0.0.0
	emu_bind "$EMU_MESA_LIB/libEGL.so.1" /usr/lib/libEGL.so.1
	emu_bind "$EMU_MESA_LIB/libGLESv2.so.2" /usr/lib/libGLESv2.so.2
	emu_bind "$EMU_MESA_LIB/libgbm.so.1" /usr/lib/libgbm.so.1
	emu_bind "$EMU_MESA_LIB/libmali-hook.so.1" /lib/libmali-hook.so.1
	emu_bind "$EMU_MESA_LIB/libmali-hook.so.1" /usr/lib/libmali-hook.so.1
	EMU_LD_PRELOAD="$EMU_MESA_LIB/libmali-hook.so.1"
	echo "hmi-launch: emulator — Mesa VirGL from $GL_ROOT (dri=virtio_gpu)" >&2
	if [ -x "$GL_ROOT/bin/flutter-wayland-client" ]; then
		ELINUX_CLIENT="$GL_ROOT/bin/flutter-wayland-client"
		echo "hmi-launch: emulator — using $ELINUX_CLIENT (Mesa GLES)" >&2
	fi
fi

# desktop-shell.so: paints boot-splash.png until Flutter covers it.
# VirGL + cocoa,gl=es requires GL renderer scanouts (pixman stays invisible).
HMI_BOOT_SPLASH="${HMI_BOOT_SPLASH:-/usr/share/hmi/boot-splash.png}"
if [ ! -f "$HMI_BOOT_SPLASH" ]; then
	echo "hmi-launch: ERROR: boot splash missing: $HMI_BOOT_SPLASH (Weston falls back to white; logo bridge broken)" >&2
else
	echo "hmi-launch: splash=$HMI_BOOT_SPLASH" >&2
fi

# shellcheck disable=SC2086
if [ "$is_emulator" -eq 1 ] && [ -n "$EMU_MESA_LIB" ]; then
	env LD_LIBRARY_PATH="$EMU_MESA_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
		LD_PRELOAD="$EMU_LD_PRELOAD${LD_PRELOAD:+:$LD_PRELOAD}" \
		LIBGL_DRIVERS_PATH="$EMU_MESA_DRI" \
		MESA_LOADER_DRIVER_OVERRIDE=virtio_gpu \
		__EGL_VENDOR_LIBRARY_DIRS="${EMU_EGL_VENDOR:-}" \
		__EGL_VENDOR_LIBRARY_FILENAMES="${EMU_EGL_VENDOR:+$EMU_EGL_VENDOR/50_mesa.json}" \
		weston --config="$WESTON_INI" --backend=drm-backend.so \
		--shell=desktop-shell.so --idle-time=0 $WESTON_RENDERER_ARGS &
else
	weston --config="$WESTON_INI" --backend=drm-backend.so \
		--shell=desktop-shell.so --idle-time=0 $WESTON_RENDERER_ARGS &
fi
WESTON_PID=$!
i=0
while [ "$i" -lt 50 ]; do
	if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
		break
	fi
	if [ "$is_emulator" -eq 1 ] && ! kill -0 "$WESTON_PID" 2>/dev/null; then
		echo "hmi-launch: ERROR: weston GL/VirGL exited — see journal; no softpipe fallback" >&2
		exit 1
	fi
	sleep 0.1 2>/dev/null || sleep 1
	i=$((i + 1))
done
if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
	echo "hmi-launch: weston Wayland socket missing at $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" >&2
	kill "$WESTON_PID" 2>/dev/null || true
	exit 1
fi

# Socket ready ≠ splash painted: desktop-shell client loads background-image
# asynchronously. Starting Flutter earlier covers DRM with an opaque black
# surface before boot-splash.png appears.
# Note: /proc/*/comm is TASK_COMM_LEN (15 chars) → "weston-desktop" only.
desktop_shell_ready=0
i=0
while [ "$i" -lt 20 ]; do
	if pidof weston-desktop-shell >/dev/null 2>&1 \
		|| pgrep -x weston-desktop-shell >/dev/null 2>&1; then
		desktop_shell_ready=1
		break
	fi
	# BusyBox without pidof/pgrep: match truncated comm or cmdline.
	for proc in /proc/[0-9]*; do
		[ -r "$proc/comm" ] || continue
		comm="$(cat "$proc/comm" 2>/dev/null || true)"
		case "$comm" in
		weston-desktop*)
			desktop_shell_ready=1
			break
			;;
		esac
		if [ -r "$proc/cmdline" ] \
			&& tr '\0' ' ' <"$proc/cmdline" 2>/dev/null | grep -q 'weston-desktop-shell'; then
			desktop_shell_ready=1
			break
		fi
	done
	[ "$desktop_shell_ready" -eq 1 ] && break
	if ! kill -0 "$WESTON_PID" 2>/dev/null; then
		echo "hmi-launch: ERROR: weston exited before desktop-shell ready" >&2
		exit 1
	fi
	sleep 0.1 2>/dev/null || sleep 1
	i=$((i + 1))
done
if [ "$desktop_shell_ready" -eq 1 ]; then
	# Brief settle so the first background buffer can commit.
	sleep 0.15 2>/dev/null || sleep 1
	echo "hmi-launch: desktop-shell ready splash=$HMI_BOOT_SPLASH" >&2
else
	echo "hmi-launch: WARNING: weston-desktop-shell not seen within timeout; starting Flutter anyway" >&2
fi

if [ "$is_emulator" -eq 1 ]; then
	echo "hmi-launch: emulator — weston=gl dri=virtio_gpu" >&2
fi

# Keep shell as main PID so we can stop Weston when the client exits.
# Do NOT use --force-scale-factor: on this board it presents FPS but the
# frame is composited black. Visual DPR is done in Dart (LwsHmiApp).
set +e
if [ "$is_emulator" -eq 1 ] && [ -n "${EMU_MESA_LIB:-}" ]; then
	env LD_LIBRARY_PATH="$EMU_MESA_LIB${ELINUX_LD_LIBRARY_PATH:+:$ELINUX_LD_LIBRARY_PATH}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
		LD_PRELOAD="$EMU_LD_PRELOAD${LD_PRELOAD:+:$LD_PRELOAD}" \
		LIBGL_DRIVERS_PATH="$EMU_MESA_DRI" \
		MESA_LOADER_DRIVER_OVERRIDE=virtio_gpu \
		__EGL_VENDOR_LIBRARY_DIRS="${EMU_EGL_VENDOR:-}" \
		__EGL_VENDOR_LIBRARY_FILENAMES="${EMU_EGL_VENDOR:+$EMU_EGL_VENDOR/50_mesa.json}" \
		"$ELINUX_CLIENT" --bundle="$BUNDLE" --fullscreen
elif [ -n "$ELINUX_LD_LIBRARY_PATH" ]; then
	env LD_LIBRARY_PATH="$ELINUX_LD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
		"$ELINUX_CLIENT" --bundle="$BUNDLE" --fullscreen
else
	"$ELINUX_CLIENT" --bundle="$BUNDLE" --fullscreen
fi
status=$?
set -e
if [ "$status" -ne 0 ]; then
	echo "hmi-launch: flutter-wayland-client exited $status" >&2
fi
# On emulator, keep Weston up so the cocoa window is not stuck on
# "Display output is not active" after a Flutter EGL failure.
if [ "$is_emulator" -eq 1 ] && [ "$status" -ne 0 ]; then
	echo "hmi-launch: emulator — leaving Weston running (Flutter failed); fix GLES then: systemctl restart hmi" >&2
	wait "$WESTON_PID" 2>/dev/null || true
	exit "$status"
fi
kill "$WESTON_PID" 2>/dev/null || true
wait "$WESTON_PID" 2>/dev/null || true
exit "$status"
