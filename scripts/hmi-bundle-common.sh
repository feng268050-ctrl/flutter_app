#!/usr/bin/env bash
# Shared helpers for host HMI bundle builds (Sony eLinux / meta-flutter layout).
# Uses pinned Flutter SDK: `flutter assemble` + linux-arm64 gen_snapshot.
# Does not use flutterpi_tool or flutter-elinux CLI.
#
# shellcheck shell=bash

# Resolve and print the pinned Flutter SDK install root; die on mismatch.
# Sets: FLUTTER_INSTALL, FLUTTER, PINNED_VER, ENGINE_VER (caller must set ROOT).
hmi_bundle_init_flutter() {
	local purpose="${1:-build}"
	PINNED_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-sdk.version" "3.24.4")"
	ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "$PINNED_VER")"

	FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"
	FLUTTER="$FLUTTER_INSTALL/bin/flutter"
	if [[ ! -x "$FLUTTER" ]]; then
		die "pinned Flutter SDK missing at $FLUTTER_INSTALL

Run on host (not Docker):
  make fetch-flutter-sdk

Or set FLUTTER_SDK to the SDK root with bin/flutter (must match engine $ENGINE_VER)."
	fi

	export PATH="$FLUTTER_INSTALL/bin:${HOME}/.pub-cache/bin:$PATH"

	local flutter_version_line
	flutter_version_line="$("$FLUTTER" --version 2>/dev/null | head -1 || true)"
	if [[ "$flutter_version_line" != *"$PINNED_VER"* ]]; then
		local path_flutter
		path_flutter="$(command -v flutter 2>/dev/null || true)"
		die "Flutter SDK version mismatch (${purpose} must match rootfs engine $ENGINE_VER).

  Pinned:  Flutter $PINNED_VER ($FLUTTER)
  Active:  ${flutter_version_line:-<flutter --version failed>}
  PATH:    ${path_flutter:-<not found>}

Do not use system/PATH flutter (e.g. 3.41.x). Run:
  make fetch-flutter-sdk
  make ${purpose}"
	fi
}

# Write a host wrapper that runs a Linux ELF gen_snapshot via Docker.
# Absolute host paths are bind-mounted at the same path so flutter assemble
# argv works unchanged. NEVER use Android gen_snapshot here — it emits
# `android compressed-pointers` AOT that aborts on eLinux
# (`linux no-compressed-pointers`).
hmi_bundle_install_gen_snapshot_docker_wrapper() {
	local dest="$1"
	local elf="$2"
	local image platform
	image="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
	platform="${DOCKER_PLATFORM:-linux/amd64}"

	[[ -x "$elf" ]] || die "gen_snapshot ELF missing: $elf"
	command -v docker >/dev/null 2>&1 \
		|| die "docker required to run Linux gen_snapshot on $(uname -s)

ELF: $elf
Or set HMI_GEN_SNAPSHOT to a host-native linux-target gen_snapshot."

	# Embed resolved paths; keep wrapper self-contained for flutter assemble.
	cat >"$dest" <<EOF
#!/usr/bin/env bash
set -euo pipefail
ROOT=$(printf '%q' "$ROOT")
ELF=$(printf '%q' "$elf")
IMAGE=$(printf '%q' "$image")
PLATFORM=$(printf '%q' "$platform")
FLUTTER_INSTALL=$(printf '%q' "$FLUTTER_INSTALL")
TMP="\${TMPDIR:-/tmp}"
exec docker run --rm --platform "\$PLATFORM" \\
	-v "\$ROOT:\$ROOT" \\
	-v "\$FLUTTER_INSTALL:\$FLUTTER_INSTALL" \\
	-v "\$TMP:\$TMP" \\
	-w "\$ROOT" \\
	"\$IMAGE" \\
	"\$ELF" "\$@"
EOF
	chmod +x "$dest"
	echo "hmi-bundle: gen_snapshot → Docker wrapper → $elf"
}

# Install a host-runnable gen_snapshot where flutter assemble looks for
# linux-arm64-{release,debug}/gen_snapshot (Sony / custom-embedder path).
hmi_bundle_ensure_gen_snapshot() {
	local mode="${1:-release}" # release|debug
	local engine_cache gen_dir dest candidate

	engine_cache="$FLUTTER_INSTALL/bin/cache/artifacts/engine"
	gen_dir="$engine_cache/linux-arm64-${mode}"
	dest="$gen_dir/gen_snapshot"
	mkdir -p "$gen_dir"

	if [[ -n "${HMI_GEN_SNAPSHOT:-}" && -x "${HMI_GEN_SNAPSHOT}" ]]; then
		cp -f "$HMI_GEN_SNAPSHOT" "$dest"
		chmod +x "$dest"
		return 0
	fi

	# Prefer prebuilt host gen_snapshot (Linux CI / native).
	candidate="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${mode}/host/bin/gen_snapshot"
	if [[ ! -x "$candidate" ]]; then
		candidate="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-release/host/bin/gen_snapshot"
	fi
	if [[ -x "$candidate" ]] && "$candidate" --help >/dev/null 2>&1; then
		cp -f "$candidate" "$dest"
		chmod +x "$dest"
		return 0
	fi

	# macOS: prebuilt is Linux x86_64 ELF — wrap via Docker (never Android GS).
	if [[ -x "$candidate" ]]; then
		hmi_bundle_install_gen_snapshot_docker_wrapper "$dest" "$candidate"
		return 0
	fi

	die "linux-target gen_snapshot not found for mode=${mode}.

Need prebuilt flutter-engine host gen_snapshot (linux AOT, not Android):
  $ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-release/host/bin/gen_snapshot

Fix:
  make build-flutter-engine   # or ensure prebuilt/ is populated
  # optional: HMI_GEN_SNAPSHOT=/path/to/linux-target gen_snapshot
  # on macOS: Docker image ${DOCKER_IMAGE:-lws-hmi-builder:22.04} must exist"
}

# Newest file under a directory matching a basename (by mtime).
hmi_bundle_newest_file() {
	local dir="$1" name="$2"
	local newest="" newest_m=0 path m
	# Avoid mapfile / process substitution for macOS /bin/bash 3.2.
	while IFS= read -r path; do
		[[ -f "$path" ]] || continue
		m="$(stat -f '%m' "$path" 2>/dev/null || stat -c '%Y' "$path" 2>/dev/null || echo 0)"
		if [[ -z "$newest" || "$m" -ge "$newest_m" ]]; then
			newest="$path"
			newest_m="$m"
		fi
	done <<EOF
$(find "$dir" -name "$name" -type f 2>/dev/null)
EOF
	[[ -n "$newest" ]] || return 1
	printf '%s\n' "$newest"
}

# Run flutter assemble for linux-arm64; args after mode are extra targets.
# Usage: hmi_bundle_assemble release|debug <target> [target...]
hmi_bundle_assemble() {
	local mode="$1"
	shift
	local out_dir="$APP_DIR/build/hmi_bundle/${mode}"
	local track_widgets=false
	local tree_shake=true
	if [[ "$mode" == "debug" ]]; then
		track_widgets=false
		tree_shake=false
	fi

	hmi_bundle_ensure_gen_snapshot "$mode"
	mkdir -p "$out_dir"
	rm -rf "$out_dir"
	mkdir -p "$out_dir"

	echo "Building HMI ${mode} bundle (Flutter $PINNED_VER, linux-arm64)..."
	"$FLUTTER" assemble \
		-dTargetPlatform=linux-arm64 \
		-dBuildMode="$mode" \
		-dTrackWidgetCreation="$track_widgets" \
		-dTreeShakeIcons="$tree_shake" \
		-dDartObfuscation=false \
		-dTargetFile=lib/main.dart \
		--output="$out_dir" \
		"$@"
}

# Install release layout into DEST (/opt/hmi overlay): lib/libapp.so + data/flutter_assets.
hmi_bundle_install_release() {
	local assets_src="$APP_DIR/build/hmi_bundle/release"
	local app_so build_root

	build_root="$APP_DIR/.dart_tool/flutter_build"
	app_so="$(hmi_bundle_newest_file "$build_root" "app.so")" \
		|| die "missing app.so under $build_root after aot_elf_release"
	[[ -f "$assets_src/AssetManifest.bin" || -f "$assets_src/AssetManifest.json" ]] \
		|| die "missing Flutter assets under $assets_src"

	rm -rf "$DEST"
	mkdir -p "$DEST/lib" "$DEST/data/flutter_assets"
	cp -f "$app_so" "$DEST/lib/libapp.so"

	# Assets only — engine + icudtl live on rootfs.
	local item base
	for item in "$assets_src"/*; do
		[[ -e "$item" ]] || continue
		base="$(basename "$item")"
		case "$base" in
		.last_build_id | app.so | libapp.so | libflutter_engine.so | icudtl.dat | flutter-pi) continue ;;
		esac
		cp -a "$item" "$DEST/data/flutter_assets/"
	done

	rm -f \
		"$DEST/lib/libflutter_engine.so" \
		"$DEST/data/icudtl.dat" \
		"$DEST/data/flutter_assets/libflutter_engine.so" \
		"$DEST/data/flutter_assets/icudtl.dat" \
		"$DEST/data/flutter_assets/app.so" \
		"$DEST/data/flutter_assets/kernel_blob.bin"

	printf '%s\n' "{\"mode\":\"release\",\"engine_version\":\"${ENGINE_VER}\"}" >"$DEST/runtime-mode.json"
}

# Stage debug JIT assets + debug-runtime engine/icu for make debug-app.
# Uses prebuilt arm64-debug (or prior staging) — not flutterpi_tool cache.
hmi_bundle_install_debug_staging() {
	local assets_src="$APP_DIR/build/hmi_bundle/debug"
	local staging hmi_staging runtime_staging engine_src icu_src

	[[ -f "$assets_src/kernel_blob.bin" ]] \
		|| die "missing $assets_src/kernel_blob.bin (HMI debug build failed)"

	# shellcheck source=debug-runtime-common.sh
	source "$ROOT/scripts/debug-runtime-common.sh"
	staging="$(debug_runtime_staging_dir "$ROOT")"
	hmi_staging="$staging/opt/hmi"
	runtime_staging="$staging/debug-runtime/$ENGINE_VER"

	local paths engine icu snap
	paths="$(debug_runtime_resolve_host_paths "$ROOT")" \
		|| die "debug engine/ICU not resolved (see message above)"
	engine="$(printf '%s\n' "$paths" | sed -n '1p')"
	icu="$(printf '%s\n' "$paths" | sed -n '2p')"
	[[ -f "$engine" && -f "$icu" ]] \
		|| die "debug engine/ICU paths invalid: engine=$engine icu=$icu"

	# Snapshot before wipe when sources live under staging.
	snap=""
	if [[ "$engine" == "$staging"/* || "$icu" == "$staging"/* ]]; then
		snap="$(mktemp -d "${TMPDIR:-/tmp}/hmi-debug-runtime.XXXXXX")"
		cp -f "$engine" "$snap/libflutter_engine.so"
		cp -f "$icu" "$snap/icudtl.dat"
		engine="$snap/libflutter_engine.so"
		icu="$snap/icudtl.dat"
	fi
	engine_src="$engine"
	icu_src="$icu"

	rm -rf "$staging"
	mkdir -p "$hmi_staging/data/flutter_assets" "$runtime_staging"

	local item base
	for item in "$assets_src"/*; do
		[[ -e "$item" ]] || continue
		base="$(basename "$item")"
		case "$base" in
		.last_build_id | libflutter_engine.so | icudtl.dat | flutter-pi | app.so | libapp.so) continue ;;
		esac
		cp -a "$item" "$hmi_staging/data/flutter_assets/"
	done

	cat >"$hmi_staging/runtime-mode.json" <<EOF
{"mode":"debug","engine_version":"${ENGINE_VER}"}
EOF

	debug_runtime_write_manifest "$runtime_staging" "$engine_src" "$icu_src" "$ENGINE_VER"

	# eLinux DartProject expects ICU at <bundle>/data/icudtl.dat.
	mkdir -p "$hmi_staging/data"
	cp -f "$icu_src" "$hmi_staging/data/icudtl.dat"

	echo "Debug staging ready at $staging"
	echo "  app:     $hmi_staging/data/flutter_assets/kernel_blob.bin"
	echo "  icu:     $hmi_staging/data/icudtl.dat"
	echo "  runtime: $runtime_staging/libflutter_engine.so"
	[[ -z "$snap" ]] || rm -rf "$snap"
}
