# P5.1 spike notes (implement-time)

Recorded 2026-08-04 during `/opsx-apply flutter-engine-p51-upgrade`.

## Current pins (pre-change)

| Pin | Value |
|-----|--------|
| `flutter-sdk.version` / `flutter-engine.version` | **3.24.4** |
| `flutter-embedded-linux.version` | **db49896cf2** (Sony tag → commit `9d0ff07b5e`) |
| Default repo | `https://github.com/sony/flutter-embedded-linux.git` |

Inventory (unchanged shape): `scripts/fetch-flutter-sdk.sh`, `fetch-flutter-engine.sh`, `fetch-flutter-engine-tarball.sh`, `build-flutter-engine.sh`, `br-compile-flutter.sh`, `build-prebuilt.sh`, `build-flutter-embedded-linux.sh`, `check-prebuilt.sh`, `cache-publish-flutter-engine.sh`, overlay `.mk` for `flutter-engine` / `flutter-sdk-bin` / `flutter-embedded-linux`.

## Selected Flutter tip

- Stable **3.41.x** tip at implement time: **3.41.9** (`00b0c91f0620…`, engine `42d3d75a56efe1…`).
- Overall Flutter stable has moved to 3.44.x; **P5.1 stays on 3.41.9** per design D2 / plan.

## eLinux compatibility

- Sony archived maintenance; community fork **`flutter-elinux/flutter-embedded-linux`** (+ `flutter-elinux/flutter-elinux` tools) tracks newer engines.
- `flutter-elinux/flutter-elinux` tag **3.41.9** pins engine **`42d3d75a56efe1…`**.
- Embedder release tag **`42d3d75a56`** exists and points at source commit **`a98514bf56`** (same tip as sibling engine-artifact tags).
- Shallow clone `--branch 42d3d75a56` works; product patch `0001-video-player-link-wayland-egl.patch` **applies cleanly**; video-player example tree still present for vendored `gst_video_player.{cc,h}`.

## Locked triplet (this change)

| Pin | New value |
|-----|-----------|
| SDK / engine | **3.41.9** |
| eLinux version file / prebuilt dir | **42d3d75a56** |
| eLinux default repo | `https://github.com/flutter-elinux/flutter-embedded-linux.git` |

## Implementation progress (apply session)

- Pins + `.mk` + script defaults + monorepo `dot-gclient` landed.
- Host darwin + linux SDK caches fetched; engine tarball `flutter-3.41.9.tar.gz` ready (~2.5G).
- App: `DropdownButtonFormField` → `initialValue`; agent rule → `flutter-3.41-api.mdc`; analyze has **no errors** (infos/deprecations remain).
- Fixed `br-compile-flutter.sh` nested Docker → `linux-sdk` mis-point (use `/work/sdk` when already in builder).
- Dropped obsolete gn opts from `flutter-engine.compile.mk`: `--enable-impeller-3d` and `--enable-impeller-vulkan` (removed upstream; Impeller backends always on).
- Added `--no-default-linux-sysroot`: `flutter/tools/gn` now forces `use_default_linux_sysroot=true` (overrides patch `0001`), which asserts on missing `debian_bullseye_amd64-sysroot` for host `clang_x64`.
- **Done:** `FORCE=1 make build-flutter-engine` → `prebuilt/flutter-engine/3.41.9/arm64-release` (~110M).
- **Done:** `FORCE=1 make build-flutter-embedded-linux` → `prebuilt/flutter-embedded-linux/42d3d75a56` (video-player stamp + GStreamer 1.28.5).
- **Done:** `make build-app` → `/opt/hmi` with engine **3.41.9**.
- **Done:** `make build-rootfs` → `output/firmware/lws_hmi/rootfs.img` (600 MiB); `verify-rootfs-overlay: PASS`.
- **Done:** `make upgrade` to USB-SSH board; device has `/etc/hmi/flutter-engine.version=3.41.9`, `libflutter_engine.so`, `flutter-wayland-client`, ICU symlink; `hmi.service` **active**; Home boot-self-check + MediaMTX camera paths in journal.
- Remaining: task **4.3** `make debug-app` / Custom Device + DevTools ( **`make push-app` already OK** on the new pin).

## Fallback (task 1.5)

**Not required** — community eLinux publishes 3.41.9-aligned artifacts/tags; no plan amendment to a lower 3.3x/3.4x.

## Cache / NAS keys

Engine tarball key remains `.cache/flutter-engine/flutter-<ver>.tar.gz` → `flutter-3.41.9.tar.gz`. Prebuilt dirs: `prebuilt/flutter-engine/3.41.9/…`, `prebuilt/flutter-embedded-linux/42d3d75a56/`. Old 3.24.4 / `db49896cf2` stamps must not be reused (`FORCE=1` rebuilds).

### Monorepo fetch (required for ≥3.29)

Flutter merged `flutter/engine` into `flutter/flutter`. Overlay `dot-gclient` now checks out `https://github.com/flutter/flutter.git@<ver>` (name `./`) into `scratch/src/`, matching upstream Buildroot. `flutter-engine.compile.mk` paths use `engine/src/…` (`flutter/tools/gn`, `out/linux_*`). Do **not** use legacy `flutter/engine.git@3.41.9` (ref missing).

Compile patches (`0001`–`0004`) refreshed from Buildroot master for `engine/src/…` paths; `0002` rewritten for 3.41 foreach(`_pkg_configs`) X11 entry.

## GStreamer coordination

No active `gstreamer-security-upgrade` OpenSpec change in-tree at implement time. eLinux was rebuilt against current GStreamer **1.28.5** staging. Rebuild eLinux again after any later GStreamer tip bump (design D8).
