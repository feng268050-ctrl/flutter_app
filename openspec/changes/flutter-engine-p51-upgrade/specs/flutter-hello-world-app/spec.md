## MODIFIED Requirements

### Requirement: Flutter Hello World project exists in repository

The repository SHALL contain a Flutter application at `app/lws_hmi/` configured for the eLinux HMI ARM64 release builds (meta-flutter layout), with documentation for engine/eLinux version alignment to the P5.1 pins (Flutter **3.41.x** / matching `flutter-embedded-linux` commit per `flutter-engine-p51`).

#### Scenario: Project structure present

- **WHEN** developer clones lws-hmi after P1 implementation
- **THEN** `app/lws_hmi/pubspec.yaml` and `lib/main.dart` exist

#### Scenario: Release build script documented

- **WHEN** developer reads app build instructions
- **THEN** steps to produce meta-flutter bundle (`lib/libapp.so`, `data/flutter_assets/`) via `hmi-bundle (flutter assemble)` are documented

#### Scenario: Version alignment docs match P5.1

- **WHEN** developer reads engine/eLinux alignment notes after P5.1
- **THEN** documented pins are Flutter 3.41.x and the matching eLinux tag (not 3.24.4 / obsolete eLinux hashes)
