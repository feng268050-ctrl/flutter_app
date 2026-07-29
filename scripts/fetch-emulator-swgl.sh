#!/usr/bin/env bash
# Fetch aarch64 Mesa virtio_gpu (+ patched Weston modules) into prebuilt/emulator-swgl.
# Used only via QEMU 9p (mount tag lws_gl) — NOT copied into device rootfs.
# Host path: virtio-gpu-gl + VirGL only (no guest softpipe/swrast).
#
# MUST match Buildroot glibc (currently 2.33): use Debian bullseye (glibc 2.31),
# NOT bookworm (Mesa needs GLIBC_2.34+).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/prebuilt/emulator-swgl"
TMP="$ROOT/.cache/emulator-swgl-debs"
MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"
SUITE="${EMULATOR_MESA_SUITE:-bullseye}"
ARCH=arm64
ROOTFS_IMG="${EMULATOR_ROOTFS_IMG:-$ROOT/output/firmware/emulator/rootfs.img}"

# Mesa + runtime deps for Wayland EGL + virtio_gpu (VirGL).
PKGS=(
	libglvnd0
	libgl1
	libegl1
	libgles2
	libgl1-mesa-dri
	libglapi-mesa
	libegl-mesa0
	libgles2-mesa
	libgbm1
	libdrm2
	libdrm-amdgpu1
	libdrm-radeon1
	libdrm-nouveau2
	libexpat1
	libzstd1
	libllvm11
	libsensors5
	libwayland-egl1
	libx11-xcb1
	libxcb1
	libx11-6
	libxau6
	libxdmcp6
	libxcb-dri2-0
	libxcb-dri3-0
	libxcb-present0
	libxcb-sync1
	libxcb-xfixes0
	libxshmfence1
	libbsd0
	libmd0
	libffi7
	libedit2
	libtinfo6
	libelf1
	libz3-4
	libvulkan1
)

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "fetch-emulator-swgl: $*"; }

command -v curl >/dev/null || die "curl required"
command -v dpkg-deb >/dev/null || die "dpkg-deb required (brew install dpkg)"
command -v patchelf >/dev/null || die "patchelf required (brew install patchelf)"

# Build into a staging tree then atomically replace $OUT so a running
# QEMU 9p share is not left pointing at a deleted inode (empty mount).
STAGING="$OUT.staging.$$"
rm -rf "$TMP" "$STAGING"
mkdir -p "$TMP" "$STAGING/lib/dri" "$STAGING/lib" "$STAGING/bin" "$STAGING/lib/libweston-14"
OUT_REAL="$OUT"
OUT="$STAGING"

PACKAGES_GZ="$TMP/Packages.gz"
curl -fsSL "$MIRROR/dists/$SUITE/main/binary-$ARCH/Packages.gz" -o "$PACKAGES_GZ"
gunzip -c "$PACKAGES_GZ" >"$TMP/Packages"

resolve_deb() {
	local pkg="$1"
	awk -v pkg="$pkg" '
		/^Package: / { p=$2; ver=""; arch=""; file=""; }
		/^Version: / { ver=$2 }
		/^Architecture: / { arch=$2 }
		/^Filename: / { file=$2 }
		/^$/ {
			if (p==pkg && arch=="arm64" && file!="") { print file; exit }
		}
	' "$TMP/Packages"
}

for pkg in "${PKGS[@]}"; do
	rel="$(resolve_deb "$pkg" || true)"
	if [[ -z "$rel" ]]; then
		log "skip missing package $pkg"
		continue
	fi
	url="$MIRROR/$rel"
	base="$(basename "$rel")"
	log "get $pkg ← $base"
	curl -fsSL "$url" -o "$TMP/$base"
	dpkg-deb -x "$TMP/$base" "$TMP/root"
done

if [[ -d "$TMP/root/usr/lib/aarch64-linux-gnu" ]]; then
	cp -a "$TMP/root/usr/lib/aarch64-linux-gnu/." "$OUT/lib/"
fi
if [[ -d "$TMP/root/lib/aarch64-linux-gnu" ]]; then
	cp -a "$TMP/root/lib/aarch64-linux-gnu/." "$OUT/lib/"
fi

# Never override Buildroot libc / libgcc / libstdc++.
# Prefer guest libexpat + core libdrm.so + wayland (avoid ABI / weston clashes).
rm -f "$OUT/lib"/libc.so* "$OUT/lib"/ld-linux* "$OUT/lib"/libpthread* "$OUT/lib"/libdl* \
	"$OUT/lib"/libm.so* "$OUT/lib"/libresolv* "$OUT/lib"/librt* "$OUT/lib"/libanl* \
	"$OUT/lib"/libnss_* "$OUT/lib"/libBrokenLocale* "$OUT/lib"/libpcprofile* \
	"$OUT/lib"/libgcc_s.so* "$OUT/lib"/libstdc++.so* \
	"$OUT/lib"/libthread_db* "$OUT/lib"/libutil* "$OUT/lib"/libc_malloc* \
	"$OUT/lib"/libnsl* "$OUT/lib"/libmemusage* "$OUT/lib"/libexpatw* \
	"$OUT/lib"/libexpat.so* \
	"$OUT/lib"/libdrm.so.2* \
	"$OUT/lib"/libwayland-client.so* "$OUT/lib"/libwayland-server.so*
rm -rf "$OUT/lib/gconv"

# VirGL only: keep virtio_gpu DRI mega-driver (no swrast/softpipe aliases).
if [[ -d "$OUT/lib/dri" ]]; then
	mkdir -p "$OUT/lib/dri-keep"
	[[ -f "$OUT/lib/dri/virtio_gpu_dri.so" ]] || die "missing virtio_gpu_dri.so after extract"
	cp -a "$OUT/lib/dri/virtio_gpu_dri.so" "$OUT/lib/dri-keep/"
	rm -rf "$OUT/lib/dri"
	mv "$OUT/lib/dri-keep" "$OUT/lib/dri"
fi

[[ -f "$OUT/lib/dri/virtio_gpu_dri.so" ]] || die "missing virtio_gpu_dri.so"
[[ -f "$OUT/lib/libEGL.so.1" || -f "$OUT/lib/libEGL.so.1.1.0" ]] || die "missing libEGL in Mesa tree"
[[ -f "$OUT/lib/libX11-xcb.so.1" || -f "$OUT/lib/libX11-xcb.so.1.0.0" ]] || die "missing libX11-xcb (EGL_mesa dep)"

# glvnd ICD metadata
mkdir -p "$OUT/share/glvnd/egl_vendor.d"
if [[ -d "$TMP/root/usr/share/glvnd/egl_vendor.d" ]]; then
	cp -a "$TMP/root/usr/share/glvnd/egl_vendor.d/." "$OUT/share/glvnd/egl_vendor.d/"
fi
if [[ ! -f "$OUT/share/glvnd/egl_vendor.d/50_mesa.json" ]]; then
	cat >"$OUT/share/glvnd/egl_vendor.d/50_mesa.json" <<'EOF'
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "libEGL_mesa.so.0"
    }
}
EOF
fi

patch_drop_mali() {
	local bin="$1"
	chmod +w "$bin"
	patchelf --remove-needed libmali-hook.so.1 "$bin" 2>/dev/null || true
	if patchelf --print-needed "$bin" | grep -qx 'libmali.so.1'; then
		patchelf --remove-needed libmali.so.1 "$bin"
	fi
	patchelf --add-needed libEGL.so.1 "$bin" 2>/dev/null || true
	patchelf --add-needed libGLESv2.so.2 "$bin" 2>/dev/null || true
	patchelf --add-needed libgbm.so.1 "$bin" 2>/dev/null || true
	patchelf --set-rpath '/run/lws-gl/lib:/run/lws-gl-cache/lib' "$bin"
}

# Product Weston DRM/GL modules are Mali-linked — retarget to Mesa for VirGL.
extract_weston_mod() {
	local guest_path="$1" dest="$2"
	if command -v debugfs >/dev/null 2>&1 && [[ -f "$ROOTFS_IMG" ]]; then
		debugfs -R "dump $guest_path $dest" "$ROOTFS_IMG" 2>/dev/null || return 1
		[[ -s "$dest" ]]
		return
	fi
	# macOS: debugfs via Docker alpine
	if command -v docker >/dev/null 2>&1 && [[ -f "$ROOTFS_IMG" ]]; then
		local base dest_rel
		base="$(basename "$dest")"
		dest_rel="${dest#"$ROOT"/}"
		docker run --rm --platform linux/amd64 -v "$ROOT:/work" -w /work alpine:3.20 \
			sh -c "apk add --no-cache e2fsprogs-extra >/dev/null && debugfs -R \"dump $guest_path $dest_rel\" \"${ROOTFS_IMG#"$ROOT"/}\"" \
			|| return 1
		[[ -s "$dest" ]]
		return
	fi
	return 1
}

for mod in gl-renderer.so drm-backend.so; do
	dest="$OUT/lib/libweston-14/$mod"
	if extract_weston_mod "/usr/lib/libweston-14/$mod" "$dest"; then
		patch_drop_mali "$dest"
		log "patched Weston module $mod → Mesa (no libmali)"
	else
		die "cannot extract /usr/lib/libweston-14/$mod from $ROOTFS_IMG (make build-rootfs / build-emulator first)"
	fi
done

# Core libweston + libexec_weston also Mali-linked.
if extract_weston_mod "/usr/lib/libweston-14.so.0.0.1" "$OUT/lib/libweston-14.so.0.0.1"; then
	cp -f "$OUT/lib/libweston-14.so.0.0.1" "$OUT/lib/libweston-14.so.0"
	patch_drop_mali "$OUT/lib/libweston-14.so.0.0.1"
	patch_drop_mali "$OUT/lib/libweston-14.so.0"
	log "patched libweston-14.so → Mesa"
else
	die "cannot extract libweston-14.so.0.0.1 from $ROOTFS_IMG"
fi
if extract_weston_mod "/usr/lib/weston/libexec_weston.so.0.0.0" "$OUT/lib/libexec_weston.so.0.0.0"; then
	cp -f "$OUT/lib/libexec_weston.so.0.0.0" "$OUT/lib/libexec_weston.so.0"
	patch_drop_mali "$OUT/lib/libexec_weston.so.0.0.0"
	patch_drop_mali "$OUT/lib/libexec_weston.so.0"
	log "patched libexec_weston.so → Mesa"
else
	die "cannot extract libexec_weston.so.0.0.0 from $ROOTFS_IMG"
fi

FWC_SRC="$(ls -t "$ROOT"/prebuilt/flutter-embedded-linux/*/usr/bin/flutter-wayland-client 2>/dev/null | head -1 || true)"
[[ -n "$FWC_SRC" && -x "$FWC_SRC" ]] || die "missing prebuilt flutter-wayland-client (make build-flutter-embedded-linux)"

cp -f "$FWC_SRC" "$OUT/bin/flutter-wayland-client"
patch_drop_mali "$OUT/bin/flutter-wayland-client"
patchelf --add-needed libwayland-egl.so.1 "$OUT/bin/flutter-wayland-client" 2>/dev/null || true
log "patched emulator flutter-wayland-client → Mesa GLES + wayland-egl"

# Stub libmali-hook: mali_injected BSS + GBM shims Rockchip weston needs.
# Image must be aarch64 Debian bullseye-class (glibc ≤ Buildroot). Override when
# Docker Hub times out, e.g.:
#   EMULATOR_STUB_IMAGE=docker.m.daocloud.io/arm64v8/debian:bullseye-slim
STUB_SRC="$ROOT/scripts/emulator-mali-hook-stub.c"
STUB_IMAGE="${EMULATOR_STUB_IMAGE:-arm64v8/debian:bullseye-slim}"
[[ -f "$STUB_SRC" ]] || die "missing $STUB_SRC"
if command -v docker >/dev/null 2>&1; then
	log "building aarch64 libmali-hook stub (GBM shims) image=$STUB_IMAGE"
	if ! docker image inspect "$STUB_IMAGE" >/dev/null 2>&1; then
		log "pulling $STUB_IMAGE (Docker Hub often times out — set EMULATOR_STUB_IMAGE to a mirror)"
		docker pull --platform linux/arm64 "$STUB_IMAGE" \
			|| die "docker pull failed for $STUB_IMAGE
  Retry with a mirror, e.g.:
    EMULATOR_STUB_IMAGE=docker.m.daocloud.io/arm64v8/debian:bullseye-slim make fetch-emulator-swgl
  Or configure Docker Desktop → Docker Engine → registry-mirrors, then:
    docker pull --platform linux/arm64 arm64v8/debian:bullseye-slim"
	fi
	docker run --rm --platform linux/arm64 \
		-v "$STUB_SRC:/src/stub.c:ro" \
		-v "$OUT/lib:/out" \
		"$STUB_IMAGE" bash -c \
		'apt-get update -qq && apt-get install -y -qq gcc >/dev/null && gcc -shared -fPIC -o /out/libmali-hook.so.1 /src/stub.c'
else
	die "docker required to build aarch64 libmali-hook stub"
fi
[[ -f "$OUT/lib/libmali-hook.so.1" ]] || die "failed to build libmali-hook.so.1"
ln -sfn libmali-hook.so.1 "$OUT/lib/libmali-hook.so"
# Weston modules need the stub (not real Mali).
for mod in \
	"$OUT/lib/libweston-14/gl-renderer.so" \
	"$OUT/lib/libweston-14/drm-backend.so" \
	"$OUT/lib/libweston-14.so.0" \
	"$OUT/lib/libweston-14.so.0.0.1" \
	"$OUT/lib/libexec_weston.so.0" \
	"$OUT/lib/libexec_weston.so.0.0.0"
do
	[[ -f "$mod" ]] || continue
	patchelf --add-needed libmali-hook.so.1 "$mod" 2>/dev/null || true
	patchelf --remove-needed libmali.so.1 "$mod" 2>/dev/null || true
done
log "installed VirGL mali-hook stub + GBM shims"

cat >"$OUT/README.txt" <<EOF
P3.2 guest Mesa + Mali-free Weston modules for QEMU VirGL (Debian $SUITE $ARCH).
9p mount tag lws_gl → /run/lws-gl (not baked into device rootfs).
Requires: qemu virtio-gpu-gl + host VirGL (make setup-emulator-qemu).
No guest softpipe/swrast path.
EOF

log "dri: $(ls "$OUT/lib/dri" | tr '\n' ' ')"
log "weston: $(ls "$OUT/lib/libweston-14" | tr '\n' ' ')"
log "libs: $(ls "$OUT/lib" | wc -l | tr -d ' ') files"
rm -rf "$OUT_REAL"
mv "$OUT" "$OUT_REAL"
OUT="$OUT_REAL"
log "OK → $OUT ($(du -sh "$OUT" | awk '{print $1}'))"
log "note: restart QEMU after refetch so 9p sees the new tree"
