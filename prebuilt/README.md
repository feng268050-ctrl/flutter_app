# prebuilt/

Git-tracked **compiled or vendored binaries** for lws-hmi. Clone this repo and run `make build-all-deps` — if artifacts here match the version pins, no recompile is needed.

| Path | Contents | Regenerate |
|------|----------|------------|
| `mediamtx/linux-arm64/` | MediaMTX static binary (P5) | `make rebuild-mediamtx` |
| `rknn-rt/` | Linux aarch64 `librknnrt.so` + header (P3 dev) | `make rebuild-rknn-rt` |
| `flutter-sdk/install/` | Host Flutter SDK + precache marker | `make rebuild-flutter-sdk` |
| `flutter-engine/<ver>/arm64-release/` | `libflutter_engine.so`, `icudtl.dat`, `gen_snapshot` | `make build-prebuilt` after `make build-rootfs` |
| `flutter-pi/<commit>/` | `/usr/bin/flutter-pi` install tree | `make build-prebuilt` after `make build-rootfs` |

**Sources** (engine tarball, flutter-pi git, OpenCV tarballs, …) stay in gitignored `.cache/` and are only downloaded when prebuilt is missing or versions change.

Large files may use **Git LFS** (see repo `.gitattributes`). Maintainers: after bumping version pins, run `make build-all-deps` then `make build-prebuilt` (Flutter) and commit `prebuilt/`.
