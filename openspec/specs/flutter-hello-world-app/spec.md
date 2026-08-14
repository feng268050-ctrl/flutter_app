# flutter-hello-world-app Specification

## Purpose

Flutter HMI app at `app/lws_hmi/` for the eLinux HMI ARM64 (meta-flutter layout). Launcher is product Home (`product-home-ui`); Settings and trimmed P2 Demo are named routes; engine/ICU stay on rootfs.
## Requirements
### Requirement: Flutter Hello World project exists in repository

The repository SHALL contain a Flutter application at `app/lws_hmi/` configured for the eLinux HMI ARM64 release builds (meta-flutter layout), with documentation for engine/eLinux version alignment to the P5.1 pins (Flutter **3.41.9** / eLinux **42d3d75a56** per `flutter-engine-p51`).

#### Scenario: Project structure present

- **WHEN** developer clones lws-hmi after P1 implementation
- **THEN** `app/lws_hmi/pubspec.yaml` and `lib/main.dart` exist

#### Scenario: Release build script documented

- **WHEN** developer reads app build instructions
- **THEN** steps to produce meta-flutter bundle (`lib/libapp.so`, `data/flutter_assets/`) via `hmi-bundle (flutter assemble)` are documented

#### Scenario: Version alignment docs match P5.1

- **WHEN** developer reads engine/eLinux alignment notes after P5.1
- **THEN** documented pins are Flutter 3.41.x and the matching eLinux tag (not 3.24.4 / obsolete eLinux hashes)

### Requirement: Hello World UI is minimal for boot KPI

The home screen SHALL display the **product Home** (capability `product-home-ui`) instead of a static “Hello, World!” greeting and instead of the P2 Demo scroll as the launcher. The app SHALL still avoid initializing video, WebSocket, or native AI libraries in `main()` before first frame. Modbus I/O, GPIO setup, audio engine open, and backlight sysfs access MUST NOT block first-frame paint (see `linux-modbus-rtu`, `linux-media-audio`, `linux-backlight`).

#### Scenario: First frame content

- **WHEN** eLinux HMI renders the app home route after this change
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

#### Scenario: HMI launches bundle

- **WHEN** operator runs `eLinux HMI --release -o landscape_left /opt/hmi` on device
- **THEN** the product Home UI displays without missing required Home asset errors

#### Scenario: System engine on rootfs

- **WHEN** rootfs is deployed
- **THEN** `/usr/lib/libflutter_engine.so` exists and matches the Flutter SDK version used to build `libapp.so`

### Requirement: App integrated via build-rootfs staging for P1

P1 SHALL deploy Hello World artifacts via `make build-app` → `app/lws_hmi/build/bundle/release/` (not Buildroot-compiled Dart), then `make build-rootfs` copies bundles into the SDK staging overlay and packs rootfs. Git fs-overlay MUST NOT contain `opt/hmi` app trees.

#### Scenario: Rootfs pack includes app artifacts

- **WHEN** `make build-app` has run and `make build-rootfs` completes
- **THEN** staging `target/opt/hmi/lib/libapp.so` is present before `rootfs.img` is published

### Requirement: Display orientation compatible with ynh960

The HMI launch configuration SHALL default to `-o landscape_left` for ynh960 landscape orientation, consistent with LCD params (`lcd0_rotation=90`), when no persisted orientation preference exists. When a persisted preference from the display-orientation platform module is present, `hmi-launch.sh` (or equivalent) SHALL pass the mapped `-o` (`landscape_left` or `portrait_up`) instead of a hardcoded landscape-only value.

#### Scenario: UI readable on ynh960 panel (default)

- **WHEN** the HMI runs on ynh960 via `hmi.service` with no orientation preference file
- **THEN** text is readable in the intended landscape physical orientation without manual rotation each boot

#### Scenario: Persisted portrait is honored at launch

- **WHEN** the orientation preference is portrait and HMI is started via the normal launch path
- **THEN** eLinux HMI is invoked with `-o portrait_up`

### Requirement: Host build uses hmi-bundle (flutter assemble)

The host build script SHALL use `hmi-bundle (flutter assemble) build --arch=arm64 --release` to produce the meta-flutter bundle matching Buildroot `FILESYSTEM_LAYOUT=meta-flutter`.

#### Scenario: build-app produces meta-flutter bundle

- **WHEN** developer runs `make build-app`
- **THEN** `lib/libapp.so` and `data/flutter_assets/` are installed under `app/lws_hmi/build/bundle/release/` (assembled from flutter assemble output; engine not copied into bundle)

### Requirement: Product audio assets exclude copyrighted demo tracks

The Flutter app MUST NOT ship `assets/audio/shanghai_tan.mp3` (or other copyrighted third-party demo music) in the eLinux HMI bundle. Speaker smoke and media play-test SHALL use product-owned short clips (click effects / warn loop) or Settings volume controls, not a bundled commercial track.

#### Scenario: Shanghai tan absent from bundle

- **WHEN** `make build-app` completes and the release bundle tree is inspected
- **THEN** `shanghai_tan.mp3` MUST NOT be present under the bundled flutter assets path

