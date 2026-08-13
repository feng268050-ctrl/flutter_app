#!/usr/bin/env bash
# Prefetch host Flutter SDK (gitignored) with .cache/ staging.
# Install destination: DEST=… (default: <repo>/flutter-sdk) — same pattern as extract-linux-sdk.
# macOS: darwin SDK → DEST; also linux SDK → .cache/flutter-sdk/install-linux for Docker BR.
# Linux: linux SDK → DEST (+ install-linux cache).
# Consuming builds still use FLUTTER_SDK= (or default flutter-sdk/) to locate the SDK.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/buildroot/flutter-sdk.version"
VERSION="$(read_version_file "$VERSION_FILE" "3.41.9")"

CACHE_DIR="$ROOT/.cache/flutter-sdk"
DEST="${DEST:-$ROOT/flutter-sdk}"
DEST="$(bash "$ROOT/scripts/expand-path.sh" "$DEST")"
FLUTTER_INSTALL="$DEST"
MARKER=".lws-precache-done"
FORCE="${FORCE:-0}"
DOCKER_INSTALL="/work/lws-hmi/flutter-sdk"
LINUX_CACHE_INSTALL="$CACHE_DIR/install-linux"
LINUX_ARCHIVE="$CACHE_DIR/flutter_linux_${VERSION}-stable.tar.xz"
LINUX_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz"

case "$(uname -s)" in
Darwin)
	PLATFORM_TAG="darwin"
	if [[ "$(uname -m)" == arm64 ]]; then
		ARCHIVE="$CACHE_DIR/flutter_macos_arm64_${VERSION}-stable.zip"
		URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${VERSION}-stable.zip"
	else
		ARCHIVE="$CACHE_DIR/flutter_macos_${VERSION}-stable.zip"
		URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_${VERSION}-stable.zip"
	fi
	CACHE_INSTALL="$CACHE_DIR/install-darwin"
	;;
Linux)
	PLATFORM_TAG="linux"
	ARCHIVE="$LINUX_ARCHIVE"
	URL="$LINUX_URL"
	CACHE_INSTALL="$LINUX_CACHE_INSTALL"
	;;
*)
	echo "ERROR: fetch-flutter-sdk unsupported host OS: $(uname -s)" >&2
	exit 1
	;;
esac

flutter_sdk_version_ok() {
	local install="$1"
	[[ -x "$install/bin/flutter" ]] || return 1
	if [[ -f "$install/bin/cache/flutter.version.json" ]]; then
		grep -q "\"flutterVersion\": \"$VERSION\"" "$install/bin/cache/flutter.version.json" && return 0
	fi
	if [[ -f "$install/.lws-prebuilt" ]] && grep -q "$VERSION" "$install/.lws-prebuilt"; then
		return 0
	fi
	# Host-compatible fallback (darwin SDK on macOS / linux SDK on Linux).
	"$install/bin/flutter" --version 2>/dev/null | head -1 | grep -q "Flutter $VERSION"
}

flutter_sdk_usable() {
	local install="$1"
	flutter_sdk_version_ok "$install" || return 1
	# Must be runnable on this host (skip for linux tree checks on Darwin).
	"$install/bin/flutter" --version >/dev/null 2>&1
}

linux_sdk_ready() {
	local install="$1"
	[[ -f "$install/$MARKER" ]] || return 1
	[[ -x "$install/bin/cache/dart-sdk/bin/dart" ]] || return 1
	# ELF x86_64 for Docker linux/amd64 Buildroot host package.
	file "$install/bin/cache/dart-sdk/bin/dart" 2>/dev/null | grep -q 'ELF.*x86-64'
}

extract_archive_to() {
	local archive="$1"
	local dest="$2"
	local kind="$3"
	rm -rf "$dest"
	case "$kind" in
	darwin)
		rm -rf "$CACHE_DIR/flutter"
		unzip -q "$archive" -d "$CACHE_DIR"
		mv "$CACHE_DIR/flutter" "$dest"
		;;
	linux)
		mkdir -p "$dest"
		tar -xJf "$archive" -C "$dest" --strip-components=1
		;;
	*)
		echo "ERROR: unknown archive kind $kind" >&2
		exit 1
		;;
	esac
}

ensure_linux_sdk_cache() {
	# Buildroot host-flutter-sdk-bin (Docker on macOS) needs a Linux x86_64 SDK.
	if [[ "$FORCE" == "1" ]]; then
		rm -f "$LINUX_CACHE_INSTALL/$MARKER"
		rm -rf "$LINUX_CACHE_INSTALL"
	fi
	if linux_sdk_ready "$LINUX_CACHE_INSTALL" && flutter_sdk_version_ok "$LINUX_CACHE_INSTALL"; then
		echo "flutter-sdk $VERSION (linux cache): ready at $LINUX_CACHE_INSTALL"
		return 0
	fi
	mkdir -p "$CACHE_DIR"
	if [[ ! -f "$LINUX_ARCHIVE" ]]; then
		echo "flutter-sdk $VERSION (linux): downloading $LINUX_URL ..."
		curl -fL --http1.1 --retry 5 --retry-delay 2 -o "$LINUX_ARCHIVE" "$LINUX_URL"
	fi
	echo "flutter-sdk $VERSION (linux): extracting → $LINUX_CACHE_INSTALL ..."
	extract_archive_to "$LINUX_ARCHIVE" "$LINUX_CACHE_INSTALL" linux
	# Cannot run linux flutter on Darwin; stamp after extract + dart presence check.
	if [[ ! -x "$LINUX_CACHE_INSTALL/bin/cache/dart-sdk/bin/dart" ]]; then
		echo "ERROR: linux Flutter SDK missing dart at $LINUX_CACHE_INSTALL" >&2
		exit 1
	fi
	# On Linux hosts, precache; on Darwin, trust the stable archive contents.
	if [[ "$(uname -s)" == Linux ]]; then
		echo "flutter-sdk $VERSION (linux): running flutter precache ..."
		HOME="$LINUX_CACHE_INSTALL" \
			PATH="$LINUX_CACHE_INSTALL/bin:${PATH}" \
			"$LINUX_CACHE_INSTALL/bin/flutter" config --no-analytics >/dev/null
		HOME="$LINUX_CACHE_INSTALL" \
			PATH="$LINUX_CACHE_INSTALL/bin:${PATH}" \
			"$LINUX_CACHE_INSTALL/bin/flutter" precache
	fi
	touch "$LINUX_CACHE_INSTALL/$MARKER"
	prebuilt_stamp "$LINUX_CACHE_INSTALL" "$VERSION"
	if ! linux_sdk_ready "$LINUX_CACHE_INSTALL"; then
		echo "ERROR: linux Flutter SDK not ready at $LINUX_CACHE_INSTALL" >&2
		exit 1
	fi
	echo "flutter-sdk $VERSION (linux cache): ready at $LINUX_CACHE_INSTALL"
	du -sh "$LINUX_ARCHIVE" "$LINUX_CACHE_INSTALL"
}

# Inside Docker: engine compile uses install-linux via flutter-sdk-bin.mk; do not
# require the darwin flutter-sdk mount to execute.
if [[ "${DOCKER:-}" == "1" ]]; then
	if linux_sdk_ready "$LINUX_CACHE_INSTALL" && flutter_sdk_version_ok "$LINUX_CACHE_INSTALL"; then
		echo "flutter-sdk $VERSION: linux cache ready at $LINUX_CACHE_INSTALL (Docker)"
		exit 0
	fi
	if flutter_sdk_usable "$DOCKER_INSTALL"; then
		echo "flutter-sdk $VERSION: ready at $DOCKER_INSTALL (read-only mount)"
		exit 0
	fi
	cat >&2 <<EOF
ERROR: Linux Flutter SDK cache missing for Docker engine compile:
  $LINUX_CACHE_INSTALL

On macOS, fetch both host + linux SDKs:
  make fetch-flutter-sdk

Then retry:
  make build-flutter-engine
EOF
	exit 1
fi

host_ready=0
if flutter_sdk_usable "$FLUTTER_INSTALL" \
	&& prebuilt_ready "$FLUTTER_INSTALL" \
	&& [[ -f "$FLUTTER_INSTALL/$MARKER" ]] \
	&& [[ "$FORCE" != "1" ]]; then
	host_ready=1
	echo "flutter-sdk $VERSION: ready at $FLUTTER_INSTALL ($PLATFORM_TAG)"
	# Repair/verify installed tree (pass path as FLUTTER_SDK only for this child).
	FLUTTER_SDK="$FLUTTER_INSTALL" bash "$ROOT/scripts/link-flutter-sdk.sh"
fi

if [[ "$host_ready" != "1" ]]; then
	if [[ "$FORCE" == "1" ]]; then
		rm -f "$CACHE_INSTALL/$MARKER" "$FLUTTER_INSTALL/$MARKER"
		rm -rf "$CACHE_INSTALL" "$FLUTTER_INSTALL"
	fi

	mkdir -p "$CACHE_DIR"

	if [[ ! -f "$ARCHIVE" ]]; then
		echo "flutter-sdk $VERSION ($PLATFORM_TAG): downloading $URL ..."
		curl -fL --http1.1 --retry 5 --retry-delay 2 -o "$ARCHIVE" "$URL"
	fi

	install_tree="$CACHE_INSTALL"
	if ! flutter_sdk_usable "$install_tree"; then
		echo "flutter-sdk $VERSION ($PLATFORM_TAG): extracting ..."
		extract_archive_to "$ARCHIVE" "$install_tree" "$PLATFORM_TAG"
	fi

	if [[ ! -f "$install_tree/$MARKER" ]]; then
		echo "flutter-sdk $VERSION ($PLATFORM_TAG): running flutter precache ..."
		HOME="$install_tree" \
			PATH="$install_tree/bin:${PATH}" \
			"$install_tree/bin/flutter" config --no-analytics >/dev/null
		HOME="$install_tree" \
			PATH="$install_tree/bin:${PATH}" \
			"$install_tree/bin/flutter" precache
		touch "$install_tree/$MARKER"
	fi

	if ! flutter_sdk_usable "$install_tree"; then
		echo "ERROR: Flutter SDK at $install_tree is not usable after precache" >&2
		exit 1
	fi

	echo "flutter-sdk $VERSION ($PLATFORM_TAG): syncing to $FLUTTER_INSTALL ..."
	mkdir -p "$(dirname "$FLUTTER_INSTALL")"
	if command -v rsync >/dev/null 2>&1; then
		rsync -a --delete --no-owner --no-group --no-perms --omit-dir-times "$install_tree"/ "$FLUTTER_INSTALL"/
	else
		rm -rf "$FLUTTER_INSTALL"
		mkdir -p "$FLUTTER_INSTALL"
		cp -a "$install_tree"/. "$FLUTTER_INSTALL"/
	fi
	prebuilt_stamp "$FLUTTER_INSTALL" "$VERSION"
	FLUTTER_SDK="$FLUTTER_INSTALL" bash "$ROOT/scripts/link-flutter-sdk.sh"

	echo "flutter-sdk $VERSION: ready at $FLUTTER_INSTALL ($PLATFORM_TAG)"
	du -sh "$ARCHIVE" "$FLUTTER_INSTALL"
fi

# Always ensure Linux cache for Docker BR host-flutter-sdk-bin (macOS + Linux).
ensure_linux_sdk_cache
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
