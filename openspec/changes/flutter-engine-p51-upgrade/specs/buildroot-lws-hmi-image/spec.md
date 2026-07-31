## MODIFIED Requirements

### Requirement: eLinux HMI and engine install from prebuilt only

Buildroot overlay packages for flutter-embedded-linux and flutter-engine SHALL copy from `prebuilt/flutter-embedded-linux/<version>/` and `prebuilt/flutter-engine/<version>/` during `make build-rootfs`. `make check-prebuilt` SHALL fail if prebuilt artifacts are missing. Host `make build-runtime-deps` (or the individual `build-flutter-engine` / `build-flutter-embedded-linux` targets) populates prebuilt directories. Active pins MUST be the P5.1 Flutter **3.41.x** triplet required by `flutter-engine-p51` (not Flutter 3.24.4).

#### Scenario: check-prebuilt gates rootfs build

- **WHEN** developer runs `make build-rootfs` without flutter prebuilt
- **THEN** build fails with `check-prebuilt` error directing to `make build-runtime-deps`

#### Scenario: engine version pinned

- **WHEN** developer inspects version pins
- **THEN** `overlay/buildroot/flutter-engine.version`, `overlay/buildroot/flutter-sdk.version`, and `overlay/buildroot/flutter-embedded-linux.version` document the active P5.1 pins (Flutter 3.41.x and matching eLinux commit/tag)
