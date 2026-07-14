## MODIFIED Requirements

### Requirement: Display orientation compatible with ynh960

The flutter-pi launch configuration SHALL default to `-o landscape_left` for ynh960 landscape orientation, consistent with LCD params (`lcd0_rotation=90`), when no persisted orientation preference exists. When a persisted preference from the display-orientation platform module is present, `hmi-launch.sh` (or equivalent) SHALL pass the mapped `-o` (`landscape_left` or `portrait_up`) instead of a hardcoded landscape-only value.

#### Scenario: UI readable on ynh960 panel (default)

- **WHEN** the HMI runs on ynh960 via `hmi.service` with no orientation preference file
- **THEN** text is readable in the intended landscape physical orientation without manual rotation each boot

#### Scenario: Persisted portrait is honored at launch

- **WHEN** the orientation preference is portrait and HMI is started via the normal launch path
- **THEN** flutter-pi is invoked with `-o portrait_up`

### Requirement: Hello World UI is minimal for boot KPI

The home screen SHALL display the **device-info + RGB LED + P2.1 I/O demo** (capability `p2-device-demo-ui`) instead of a static “Hello, World!” / “Hello, lws-hmi” greeting. The app SHALL still avoid initializing video, WebSocket, or native AI libraries in `main()` before first frame. Modbus I/O, GPIO setup, audio engine open, and backlight sysfs access MUST NOT block first-frame paint (see `linux-modbus-rtu`, `linux-media-audio`, `linux-backlight`).

#### Scenario: First frame content

- **WHEN** flutter-pi renders the app home route after this change
- **THEN** the user sees the device-information list, LED control rows, and the audio / brightness / orientation demo controls (not a Hello World–only screen)

#### Scenario: No heavy plugins on startup

- **WHEN** app `main()` executes
- **THEN** no video_player, WebSocket, or native AI libraries are initialized before `runApp`

## ADDED Requirements

### Requirement: Shanghai tan test track is bundled as a Flutter asset

The Flutter app SHALL ship `assets/audio/shanghai_tan.mp3` (sourced from lws-ui `res/raw/shanghai_tan.mp3`) in the flutter-pi bundle so the demo can play it offline on device.

#### Scenario: Asset present in bundle

- **WHEN** `make build-app` completes and the overlay `/opt/hmi` tree is inspected
- **THEN** the shanghai tan mp3 is present under the bundled flutter assets path
