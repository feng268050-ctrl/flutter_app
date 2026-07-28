#!/usr/bin/env bash
# Install macOS QEMU with VirGL (ANGLE→Metal) for P3.2 emulator host GPU forwarding.
# Stock `brew install qemu` has OpenGL disabled — Flutter/Weston need virtio-gpu-gl.
#
# Keeps stock `qemu` keg installed; prefers Cellar path for qemu-virgl (no brew link fight).
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "setup-emulator-qemu: $*"; }

[[ "$(uname -s)" == "Darwin" ]] || die "this helper is for macOS (Linux: use distro QEMU with virgl + -device virtio-gpu-gl-pci)"

command -v brew >/dev/null || die "Homebrew required"

TAP=startergo/qemu-virgl
FORMULA="$TAP/qemu-virgl"

if ! brew tap-info "$TAP" &>/dev/null; then
	log "tapping $TAP"
	brew tap "$TAP"
fi

# Homebrew 4.x may refuse untrusted taps.
if brew trust --help &>/dev/null; then
	brew trust "$TAP" >/dev/null 2>&1 || true
	brew trust --formula "$FORMULA" >/dev/null 2>&1 || true
fi

if ! brew list --versions qemu-virgl &>/dev/null; then
	log "installing $FORMULA (bottles preferred)"
	HOMEBREW_NO_AUTO_UPDATE=1 brew install "$FORMULA" || true
fi

QEMU_BIN="$(brew --prefix qemu-virgl 2>/dev/null)/bin/qemu-system-aarch64"
[[ -x "$QEMU_BIN" ]] || QEMU_BIN="$(ls -d /opt/homebrew/Cellar/qemu-virgl/*/bin/qemu-system-aarch64 2>/dev/null | tail -1 || true)"
[[ -x "${QEMU_BIN:-}" ]] || die "qemu-virgl installed but binary missing — try: brew reinstall $FORMULA"

# Bottle may link libjpeg.9 while current jpeg keg is .10 — shim if needed.
JPG_LIB="$(brew --prefix jpeg 2>/dev/null)/lib"
if [[ -d "$JPG_LIB" && -f "$JPG_LIB/libjpeg.10.dylib" && ! -e "$JPG_LIB/libjpeg.9.dylib" ]]; then
	log "shim libjpeg.9.dylib → libjpeg.10.dylib (qemu-virgl bottle ABI)"
	ln -sf libjpeg.10.dylib "$JPG_LIB/libjpeg.9.dylib"
fi

# Smoke: binary runs and exposes GL device.
"$QEMU_BIN" -version >/dev/null || die "qemu-virgl failed to start (dylib?) — check: otool -L $QEMU_BIN"
"$QEMU_BIN" -device help 2>&1 | grep -q 'virtio-gpu-gl-pci' || die "qemu-virgl lacks virtio-gpu-gl-pci"

# Confirm cocoa,gl=es is accepted (parse-only via help error path is flaky; try short boot).
if ! "$QEMU_BIN" -machine virt -cpu cortex-a55 -m 64 -display cocoa,gl=es -device virtio-gpu-gl-pci -monitor none -serial none -S 2>/tmp/lws-qemu-gl-check.err &
then
	:
fi
QG=$!
sleep 1
if kill -0 "$QG" 2>/dev/null; then
	kill "$QG" 2>/dev/null || true
	wait "$QG" 2>/dev/null || true
	log "OK: cocoa,gl=es + virtio-gpu-gl-pci accepted"
else
	wait "$QG" 2>/dev/null || true
	if grep -qi 'OpenGL support was not enabled' /tmp/lws-qemu-gl-check.err 2>/dev/null; then
		die "OpenGL still disabled in this QEMU build"
	fi
	# Window may have exited for other reasons; device presence is enough.
	log "warning: short GL smoke exit — check /tmp/lws-qemu-gl-check.err if emulator fails"
	cat /tmp/lws-qemu-gl-check.err 2>/dev/null || true
fi

log "use: QEMU=$QEMU_BIN make emulator"
log "or:  make emulator   # run-emulator.sh prefers qemu-virgl keg"
echo "$QEMU_BIN"
