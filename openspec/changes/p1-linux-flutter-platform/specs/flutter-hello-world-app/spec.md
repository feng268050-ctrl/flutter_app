## ADDED Requirements

### Requirement: Flutter Hello World project exists in repository

The repository SHALL contain a Flutter application at `app/lws_hmi/` configured for flutter-pi ARM64 release builds, with documentation for engine/flutter-pi version alignment.

#### Scenario: Project structure present

- **WHEN** developer clones lws-hmi after P1 implementation
- **THEN** `app/lws_hmi/pubspec.yaml` and `lib/main.dart` exist

#### Scenario: Release build script documented

- **WHEN** developer reads app build instructions
- **THEN** steps to produce `app.so` and `flutter_assets/` for flutter-pi are documented

### Requirement: Hello World UI is minimal for boot KPI

The P1 home screen SHALL display a simple full-screen greeting (e.g. "Hello, lws-hmi") with no video, WebSocket, FFI, or network initialization in `main()` before first frame.

#### Scenario: First frame content

- **WHEN** flutter-pi renders the P1 app home route
- **THEN** user-visible text confirms lws-hmi Hello World

#### Scenario: No heavy plugins on startup

- **WHEN** app `main()` executes
- **THEN** no video_player, WebSocket, or native AI libraries are initialized before `runApp`

### Requirement: Release artifacts deploy to /opt/hmi

Cross-compiled release output SHALL be installed on target at:

```
/opt/hmi/app.so
/opt/hmi/icudtl.dat
/opt/hmi/flutter_assets/
```

#### Scenario: Bundle layout on device

- **WHEN** P1 rootfs or overlay is deployed
- **THEN** `/opt/hmi/app.so` and `/opt/hmi/flutter_assets/` exist

#### Scenario: flutter-pi launches bundle

- **WHEN** operator runs `flutter-pi --release /opt/hmi` on device
- **THEN** Hello World UI displays without missing asset errors

### Requirement: App integrated via rootfs overlay for P1

P1 SHALL deploy Hello World artifacts via Buildroot rootfs overlay (not Buildroot-compiled Dart), updated by host build script or CI step before `make build-rootfs`.

#### Scenario: Overlay contains app artifacts

- **WHEN** lws-hmi overlay is applied and rootfs built
- **THEN** `opt/hmi/app.so` is present inside fs-overlay tree before build

### Requirement: Display orientation compatible with ynh960

The flutter-pi launch configuration (service flags or embedder config) SHALL support ynh960 landscape orientation (`landscape_left` or 90° rotation) consistent with LCD params.

#### Scenario: UI readable on ynh960 panel

- **WHEN** Hello World runs on ynh960 via `hmi.service`
- **THEN** text is readable in the intended physical orientation without manual rotation each boot
