## 1. Spike and pin selection

- [x] 1.1 Confirm current pins (SDK/engine **3.24.4**, eLinux **db49896cf2**) and inventory fetch/build/prebuilt scripts
- [x] 1.2 Select stable Flutter **3.41.x** tip at implement time (floor ≥ 3.41.0; baseline **3.41.9** if still tip)
- [x] 1.3 Spike flutter-embedded-linux commit/tag compatible with that engine; record fork/patch plan if upstream lags
- [x] 1.4 Spike `make fetch-flutter-engine` + `build-flutter-engine` for the new version (Docker/macOS path, cache/NAS keys)
- [x] 1.5 If 3.41.x cannot build with eLinux, document fallback version and plan amendment; do not ship 3.24.4

## 2. Overlay pins and recipes

- [x] 2.1 Update `overlay/buildroot/flutter-sdk.version`, `flutter-engine.version`, `flutter-embedded-linux.version`
- [x] 2.2 Update overlay `.mk` / Config for flutter-engine, flutter-sdk-bin, flutter-embedded-linux to match pins
- [x] 2.3 `make apply-overlay` and confirm SDK package recipes reflect the new pins

## 3. Rebuild triplet and App

- [x] 3.1 `make fetch-flutter-sdk` for host (+ Linux SDK inside Docker as required)
- [x] 3.2 `FORCE=1 make build-flutter-engine` (release; profile/debug if product uses them)
- [x] 3.3 Ensure GStreamer staging `.pc` available; `FORCE=1 make build-flutter-embedded-linux` with video-player stamp
- [x] 3.4 Migrate `app/lws_hmi` + path packages to 3.41.x APIs; `flutter analyze` / tests clean
- [x] 3.5 Replace `.cursor/rules/flutter-3.24-api.mdc` with a 3.41.x pin rule
- [x] 3.6 `make build-app` succeeds; SDK/engine mismatch checks pass

## 4. Ship and accept

- [x] 4.1 `make build-rootfs` + `make upgrade` (or equivalent); confirm device engine/ICU and `flutter-wayland-client`
- [x] 4.2 Smoke: Home UI, Settings MediaMTX preview, input/orientation, boot KPI sanity
- [ ] 4.3 Verify `make push-app` and `make debug-app` / Custom Device + DevTools on the new pin
- [x] 4.4 Update `docs/flutter-linux-hmi-plan.md` P5.1 status and README/AGENTS pin references; fix stale 3.24.4 / old eLinux hash docs
- [x] 4.5 Note coordination with `gstreamer-security-upgrade` if both land (rebuild eLinux after final GStreamer)
