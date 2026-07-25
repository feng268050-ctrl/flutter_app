# flutter-hello-world-app Specification

## Purpose

Flutter HMI app at `app/lws_hmi/` for flutter-pi ARM64 (meta-flutter layout). Launcher is product Home (`product-home-ui`); Settings and trimmed P2 Demo are named routes; engine/ICU stay on rootfs.
## Requirements
### Requirement: Flutter Hello World project exists in repository

The repository SHALL contain a Flutter application at `app/lws_hmi/` configured for flutter-pi ARM64 release builds (meta-flutter layout), with documentation for engine/flutter-pi version alignment (Flutter 3.24.4 / flutter-pi 37bd977).

#### Scenario: Project structure present

- **WHEN** developer clones lws-hmi after P1 implementation
- **THEN** `app/lws_hmi/pubspec.yaml` and `lib/main.dart` exist

#### Scenario: Release build script documented

- **WHEN** developer reads app build instructions
- **THEN** steps to produce meta-flutter bundle (`lib/libapp.so`, `data/flutter_assets/`) via `flutterpi_tool` are documented

### Requirement: Hello World UI is minimal for boot KPI

The home screen SHALL display the **product Home** (capability `product-home-ui`) instead of a static “Hello, World!” greeting and instead of the P2 Demo scroll as the launcher. The app SHALL still avoid initializing video, WebSocket, or native AI libraries in `main()` before first frame. Modbus I/O, GPIO setup, audio engine open, and backlight sysfs access MUST NOT block first-frame paint (see `linux-modbus-rtu`, `linux-media-audio`, `linux-backlight`).

#### Scenario: First frame content

- **WHEN** flutter-pi renders the app home route after this change
- **THEN** the user sees the product Home backdrop and Settings entry (not a Hello World–only screen and not the P2 Demo as the launcher)

#### Scenario: No heavy plugins on startup

- **WHEN** app `main()` executes
- **THEN** no video_player, WebSocket, or native AI libraries are initialized before `runApp`

### Requirement: Release artifacts deploy to /opt/hmi (meta-flutter layout)

Cross-compiled release output SHALL be installed on target at:

```
/opt/hmi/lib/libapp.so
/opt/hmi/data/flutter_assets/
```

Flutter engine and ICU data SHALL be on rootfs only (not duplicated in the app bundle):

```
/usr/lib/libflutter_engine.so
/usr/share/flutter/release/data/icudtl.dat
```

#### Scenario: Bundle layout on device

- **WHEN** rootfs or overlay is deployed after P2 app build
- **THEN** `/opt/hmi/lib/libapp.so` and `/opt/hmi/data/flutter_assets/` exist; `/opt/hmi/lib/libflutter_engine.so` is absent

#### Scenario: flutter-pi launches bundle

- **WHEN** operator runs `flutter-pi --release -o landscape_left /opt/hmi` on device
- **THEN** the product Home UI displays without missing required Home asset errors

#### Scenario: System engine on rootfs

- **WHEN** rootfs is deployed
- **THEN** `/usr/lib/libflutter_engine.so` exists and matches the Flutter SDK version used to build `libapp.so`

### Requirement: App integrated via rootfs overlay for P1

P1 SHALL deploy Hello World artifacts via Buildroot rootfs overlay (not Buildroot-compiled Dart), updated by `make build-app` (or `scripts/build-app.sh`) before `make build-rootfs`.

#### Scenario: Overlay contains app artifacts

- **WHEN** lws-hmi overlay is applied and `make build-app` has run
- **THEN** `opt/hmi/lib/libapp.so` is present inside fs-overlay tree before rootfs build

### Requirement: Display orientation compatible with ynh960

The flutter-pi launch configuration SHALL default to `-o landscape_left` for ynh960 landscape orientation, consistent with LCD params (`lcd0_rotation=90`), when no persisted orientation preference exists. When a persisted preference from the display-orientation platform module is present, `hmi-launch.sh` (or equivalent) SHALL pass the mapped `-o` (`landscape_left` or `portrait_up`) instead of a hardcoded landscape-only value.

#### Scenario: UI readable on ynh960 panel (default)

- **WHEN** the HMI runs on ynh960 via `hmi.service` with no orientation preference file
- **THEN** text is readable in the intended landscape physical orientation without manual rotation each boot

#### Scenario: Persisted portrait is honored at launch

- **WHEN** the orientation preference is portrait and HMI is started via the normal launch path
- **THEN** flutter-pi is invoked with `-o portrait_up`

### Requirement: Host build uses flutterpi_tool

The host build script SHALL use `flutterpi_tool build --arch=arm64 --release` to produce the meta-flutter bundle matching Buildroot `FILESYSTEM_LAYOUT=meta-flutter`.

#### Scenario: build-app produces meta-flutter bundle

- **WHEN** developer runs `make build-app`
- **THEN** `lib/libapp.so` and `data/flutter_assets/` are installed under overlay `opt/hmi/` (assembled from `flutterpi_tool` output; engine not copied into bundle)

### Requirement: Shanghai tan test track is bundled as a Flutter asset

The Flutter app SHALL ship `assets/audio/shanghai_tan.mp3` (sourced from lws-ui `res/raw/shanghai_tan.mp3`) in the flutter-pi bundle so the demo can play it offline on device.

#### Scenario: Asset present in bundle

- **WHEN** `make build-app` completes and the overlay `/opt/hmi` tree is inspected
- **THEN** the shanghai tan mp3 is present under the bundled flutter assets path

