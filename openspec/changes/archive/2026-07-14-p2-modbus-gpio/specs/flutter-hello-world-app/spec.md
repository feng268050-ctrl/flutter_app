## MODIFIED Requirements

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
