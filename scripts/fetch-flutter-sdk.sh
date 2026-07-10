#!/usr/bin/env bash
# Prefetch host Flutter SDK into FLUTTER_SDK (outside git) with .cache/ staging.
# macOS: darwin SDK for make build-flutter-app; Linux: linux SDK for Docker engine compile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/buildroot/flutter-sdk.version"
VERSION="$(read_version_file "$VERSION_FILE" "3.24.4")"

CACHE_DIR="$ROOT/.cache/flutter-sdk"
FLUTTER_ROOT="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print-root)"
FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"
MARKER=".lws-precache-done"
FORCE="${FORCE:-0}"
DOCKER_INSTALL="/work/lws-hmi/flutter-sdk"

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
	ARCHIVE="$CACHE_DIR/flutter_linux_${VERSION}-stable.tar.xz"
	URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz"
	CACHE_INSTALL="$CACHE_DIR/install-linux"
	;;
*)
	echo "ERROR: fetch-flutter-sdk unsupported host OS: $(uname -s)" >&2
	exit 1
	;;
esac

flutter_sdk_usable() {
	local install="$1"
	[[ -x "$install/bin/flutter" ]] || return 1
	"$install/bin/flutter" --version 2>/dev/null | head -1 | grep -q "Flutter $VERSION"
}

extract_archive() {
	local dest="$1"
	rm -rf "$dest"
	case "$PLATFORM_TAG" in
	darwin)
		rm -rf "$CACHE_DIR/flutter"
		unzip -q "$ARCHIVE" -d "$CACHE_DIR"
		mv "$CACHE_DIR/flutter" "$dest"
		;;
	linux)
		mkdir -p "$dest"
		tar -xJf "$ARCHIVE" -C "$dest" --strip-components=1
		;;
	esac
}

# Inside Docker the host FLUTTER_SDK tree is bind-mounted read-only at flutter-sdk/.
if [[ "${LWS_HMI_DOCKER:-}" == "1" ]]; then
	if flutter_sdk_usable "$DOCKER_INSTALL"; then
		echo "flutter-sdk $VERSION: ready at $DOCKER_INSTALL (read-only mount)"
		exit 0
	fi
	cat >&2 <<EOF
ERROR: host Flutter SDK not available in Docker.

On macOS, install/precache on the host first (writes to FLUTTER_SDK outside the container):
  make fetch-flutter-sdk

Then retry:
  make build-flutter-engine
EOF
	exit 1
fi

if flutter_sdk_usable "$FLUTTER_INSTALL" \
	&& prebuilt_ready "$FLUTTER_ROOT" \
	&& [[ -f "$FLUTTER_INSTALL/$MARKER" ]] \
	&& [[ "$FORCE" != "1" ]]; then
	echo "flutter-sdk $VERSION: ready at $FLUTTER_INSTALL ($PLATFORM_TAG)"
	bash "$ROOT/scripts/link-flutter-sdk.sh"
	exit 0
fi

if [[ "$FORCE" == "1" ]]; then
	rm -f "$CACHE_INSTALL/$MARKER" "$FLUTTER_INSTALL/$MARKER"
	rm -rf "$CACHE_INSTALL" "$FLUTTER_INSTALL"
	rm -f "$FLUTTER_ROOT/.lws-prebuilt"
fi

migrate_legacy() {
	local legacy="$ROOT/prebuilt/flutter-sdk"
	if [[ -d "$legacy/install" && ! -d "$FLUTTER_INSTALL" ]]; then
		echo "flutter-sdk $VERSION: migrating legacy prebuilt/flutter-sdk -> $FLUTTER_ROOT ..."
		mkdir -p "$(dirname "$FLUTTER_ROOT")"
		mv "$legacy" "$FLUTTER_ROOT"
	fi
}
migrate_legacy

mkdir -p "$CACHE_DIR"

if [[ ! -f "$ARCHIVE" ]]; then
	echo "flutter-sdk $VERSION ($PLATFORM_TAG): downloading $URL ..."
	curl -fL --retry 3 -o "$ARCHIVE" "$URL"
fi

install_tree="$CACHE_INSTALL"
if ! flutter_sdk_usable "$install_tree"; then
	echo "flutter-sdk $VERSION ($PLATFORM_TAG): extracting ..."
	extract_archive "$install_tree"
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
mkdir -p "$FLUTTER_ROOT"
if command -v rsync >/dev/null 2>&1; then
	rsync -a --delete --no-owner --no-group --no-perms --omit-dir-times "$install_tree"/ "$FLUTTER_INSTALL"/
else
	rm -rf "$FLUTTER_INSTALL"
	mkdir -p "$FLUTTER_INSTALL"
	cp -a "$install_tree"/. "$FLUTTER_INSTALL"/
fi
prebuilt_stamp "$FLUTTER_ROOT" "$VERSION"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
bash "$ROOT/scripts/link-flutter-sdk.sh"

echo "flutter-sdk $VERSION: ready at $FLUTTER_INSTALL ($PLATFORM_TAG)"
du -sh "$ARCHIVE" "$FLUTTER_INSTALL"
