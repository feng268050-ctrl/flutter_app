# flutter-hello-world-app Specification

## Purpose

Flutter HMI app at `app/hmi/` for flutter-pi ARM64 (meta-flutter layout). P2 home is the device-info + RGB LED demo (`p2-device-demo-ui`); engine/ICU stay on rootfs.

## Requirements

### Requirement: Flutter Hello World project exists in repository

The repository SHALL contain a Flutter application at `app/hmi/` configured for flutter-pi ARM64 release builds (meta-flutter layout), with documentation for engine/flutter-pi version alignment (Flutter 3.24.4 / flutter-pi 37bd977).

#### Scenario: Project structure present

- **WHEN** developer clones lws-hmi after P1 implementation
- **THEN** `app/hmi/pubspec.yaml` and `lib/main.dart` exist

#### Scenario: Release build script documented

- **WHEN** developer reads app build instructions
- **THEN** steps to produce meta-flutter bundle (`lib/libapp.so`, `data/flutter_assets/`) via `flutterpi_tool` are documented

### Requirement: Hello World UI is minimal for boot KPI

The P2 home screen SHALL display the **device-info + RGB LED demo** (capability `p2-device-demo-ui`) instead of a static “Hello, World!” / “Hello, lws-hmi” greeting. The app SHALL still avoid initializing video, WebSocket, or native AI libraries in `main()` before first frame. Modbus I/O and GPIO setup MUST NOT block first-frame paint (see `linux-modbus-rtu`).

#### Scenario: First frame content

- **WHEN** flutter-pi renders the app home route after P2
- **THEN** the user sees the P2 device-information list and LED control rows (not a Hello World–only screen)

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
- **THEN** the P2 demo UI displays without missing asset errors

#### Scenario: System engine on rootfs

- **WHEN** rootfs is deployed
- **THEN** `/usr/lib/libflutter_engine.so` exists and matches the Flutter SDK version used to build `libapp.so`

### Requirement: App integrated via rootfs overlay for P1

P1 SHALL deploy Hello World artifacts via Buildroot rootfs overlay (not Buildroot-compiled Dart), updated by `make build-app` (or `scripts/build-app.sh`) before `make build-rootfs`.

#### Scenario: Overlay contains app artifacts

- **WHEN** lws-hmi overlay is applied and `make build-app` has run
- **THEN** `opt/hmi/lib/libapp.so` is present inside fs-overlay tree before rootfs build

### Requirement: Display orientation compatible with ynh960

The flutter-pi launch configuration in `hmi.service` SHALL use `-o landscape_left` for ynh960 landscape orientation, consistent with LCD params (`lcd0_rotation=90`).

#### Scenario: UI readable on ynh960 panel

- **WHEN** Hello World runs on ynh960 via `hmi.service`
- **THEN** text is readable in the intended physical orientation without manual rotation each boot

### Requirement: Host build uses flutterpi_tool

The host build script SHALL use `flutterpi_tool build --arch=arm64 --release` to produce the meta-flutter bundle matching Buildroot `FILESYSTEM_LAYOUT=meta-flutter`.

#### Scenario: build-app produces meta-flutter bundle

- **WHEN** developer runs `make build-app`
- **THEN** `lib/libapp.so` and `data/flutter_assets/` are installed under overlay `opt/hmi/` (assembled from `flutterpi_tool` output; engine not copied into bundle)

