## Why

Product HMI still pins **Flutter SDK / engine 3.24.4** and **flutter-embedded-linux `db49896cf2`**, with App Dart code and agent rules locked to the 3.24.4 API surface. That generation is far behind the **2026 stable line** targeted by roadmap **P5.1** (`docs/flutter-linux-hmi-plan.md`: **3.24 → 3.41**). Staying on 3.24 blocks Dart/Flutter framework fixes, tooling (analyze/debug), and embedder API evolution already assumed by later CyberUI / P4 work; embedder-migration notes also allow combining engine upgrade with Weston/eLinux tuning when Animator/vsync limits remain.

## What Changes

- Upgrade the **triplet in lockstep**: host/SDK pin (`overlay/buildroot/flutter-sdk.version` + `fetch-flutter-sdk`), Buildroot/prebuilt **flutter-engine** (`flutter-engine.version` + `make build-flutter-engine`), and **flutter-embedded-linux** (new compatible tag/commit + `make build-flutter-embedded-linux`, including GStreamer video player stamp).
- Target Flutter **3.41.x** per P5.1 (floor **≥ 3.41.0**; prefer newest **3.41.x** tip at implement time, currently **3.41.9** on stable). Re-pin package `.mk` values and prebuilt directory names accordingly.
- Migrate `app/lws_hmi/` (+ path packages as needed) off 3.24-only APIs; update `.cursor/rules/flutter-3.24-api.mdc` (or replace) to the new pin; keep `make build-app` / `debug-app` / `push-app` working.
- Refresh docs/specs that hardcode **3.24.4** / obsolete eLinux commits; mark P5.1 done in the roadmap table when acceptance lands.
- **Out of scope:** P5.0 Android APK/YNHAPI; replacing Weston+eLinux with another embedder; enabling Impeller on eLinux unless spike proves it; unrelated CVE package upgrades (OpenSSL/GStreamer/BlueZ/kernel) except shared eLinux rebuild ordering.

## Capabilities

### New Capabilities

- `flutter-engine-p51`: P5.1 triplet upgrade (SDK + engine + eLinux), version floor, App/API migration, prebuilt rebuild contract, device/debug acceptance, and roadmap/docs pin updates.

### Modified Capabilities

- `buildroot-lws-hmi-image`: Prebuilt engine/eLinux pins MUST be the P5.1 versions (not 3.24.4 / stale eLinux tags).
- `flutter-hello-world-app`: Documented and verified alignment with the new Flutter/eLinux pins; bundle still uses rootfs engine/ICU.
- `host-debug-hmi`: Debug/Custom Device workflow validated against the upgraded SDK/engine (retire 3.24.4-only gate language).
- `linux-sdk-own-tree`: Confirm flutter-engine / flutter-sdk-bin / flutter-embedded-linux overlay recipes stay on the always-injected sync path.

## Impact

- Overlay pins: `flutter-sdk.version`, `flutter-engine.version`, `flutter-embedded-linux.version`; `overlay/buildroot/package/flutter-{engine,sdk-bin,embedded-linux}/`.
- Build: `make fetch-flutter-sdk`, `make fetch-flutter-engine`, `FORCE=1 make build-flutter-engine`, `make build-flutter-embedded-linux` (after GStreamer staging if video plugin required), `make build-app`, `make build-rootfs`, `make upgrade` / `push-app`.
- App: Dart SDK / Material API churn across `app/lws_hmi` and `packages/cyber_*`; agent Flutter API rule.
- Runtime: `libflutter_engine.so`, `flutter-wayland-client`, `libvideo_player_plugin.so`, ICU path, boot KPI / Settings preview / debug-app.
- Coordination: may sequence after or with `gstreamer-security-upgrade` when rebuilding eLinux GStreamer plugin; independent of P5.0.
