## MODIFIED Requirements

### Requirement: make debug-app starts a physical-device Flutter debug session

The repository SHALL provide `make debug-app` that uses the pinned Flutter SDK to build the application as an ARM64 debug bundle, deploys it over USB-SSH or registered SSH to the selected physical lws-hmi device, replaces the firmware-bundled application for the session, and starts the board HMI in Flutter **debug** mode on the image’s display stack.

On `/etc/display-stack=weston` (or `wayland` / `elinux`), the target SHALL run Weston plus `flutter-wayland-client` with the cached debug-runtime engine selected via `LD_LIBRARY_PATH` (JIT assets under `/opt/hmi/data/flutter_assets/`, including `kernel_blob.bin`). On `/etc/display-stack=flutter-pi`, the target SHALL run flutter-pi with that same cached debug-runtime engine and without the `--release` runtime mode.

The target SHALL run the debug bundle with a debug-runtime engine built from the same pinned Flutter version/source as the release-runtime engine. The two runtime-mode binaries are distinct because debug requires JIT, VM Service, and hot reload while release executes AOT output. The command MUST fail before stopping the release HMI if the app bundle, engine, or version manifest is missing or incompatible. Host deploy MUST NOT refuse Weston solely because `display-stack` is not flutter-pi.

#### Scenario: Start debug session on one connected Weston board

- **WHEN** one compatible ynh960 with `/etc/display-stack=weston` is connected over USB-SSH and the developer runs `make debug-app`
- **THEN** the pinned SDK builds a debug bundle, the bundle is installed on that board, and the HMI shows the app via Weston + `flutter-wayland-client` using the cached debug engine
- **AND** the command does not require rebuilding, repacking, or flashing a firmware image
- **AND** the command does not require switching to the alternate flutter-pi rootfs

#### Scenario: Start debug session on one connected flutter-pi board

- **WHEN** one compatible ynh960 with `/etc/display-stack=flutter-pi` is connected over USB-SSH and the developer runs `make debug-app`
- **THEN** the pinned SDK builds a debug bundle, the bundle is installed on that board, and flutter-pi displays it without the `--release` runtime mode

#### Scenario: Debug runtime is incompatible

- **WHEN** the available debug engine does not match the pinned app SDK/engine version
- **THEN** `make debug-app` fails with an actionable dependency command before changing the running release application

### Requirement: The last successful app deployment remains installed

The device SHALL stage and validate a complete payload before stopping the current HMI processes (Weston client and/or flutter-pi as applicable) and atomically replacing `/opt/hmi`. Each installed payload SHALL include a validated runtime-mode manifest so `hmi.service` / `hmi-launch.sh` launches release payloads with the release engine path for that display stack, and debug payloads with the matching cached debug engine and debug runtime mode (Weston: `LD_LIBRARY_PATH` + JIT assets; flutter-pi: debug engine without `--release`).

IDE detach or stop SHALL close the debugger connection without terminating the running debug application or restoring an older release payload. A later `make debug-app` SHALL replace the installed app with a newer debug build; `make push-app` SHALL replace it with the current release build.

#### Scenario: Normal IDE stop

- **WHEN** the developer stops or detaches the debug session from VS Code or Cursor
- **THEN** the debugger connection closes and the installed debug app continues running on the device

#### Scenario: Host disconnects during a session

- **WHEN** the USB link or IDE process disappears after the debug payload was installed
- **THEN** the installed debug app continues running independently of the host connection

#### Scenario: Board reboots with debug app installed

- **WHEN** the board reboots after a debug payload was successfully installed
- **THEN** `hmi.service` selects the cached matching debug engine and starts that debug payload in debug runtime mode for the image display stack

#### Scenario: push-app replaces debug app

- **WHEN** a debug payload is installed and the developer runs `make build-app` followed by `make push-app`
- **THEN** `/opt/hmi` is replaced by the release payload and `hmi.service` starts it with the release engine path for that display stack

#### Scenario: Payload transfer fails

- **WHEN** debug app or runtime transfer fails before transaction commit
- **THEN** the currently installed debug or release app remains unchanged

## ADDED Requirements

### Requirement: Weston debug launch supplies ICU and JIT assets for eLinux

When `display-stack` is weston/wayland/elinux and `/opt/hmi/runtime-mode.json` indicates `mode=debug`, `hmi-launch.sh` SHALL ensure `/opt/hmi/data/icudtl.dat` is present (copying from the versioned debug-runtime cache if needed), SHALL require `data/flutter_assets/kernel_blob.bin`, SHALL start Weston as for release, and SHALL exec `flutter-wayland-client` with `LD_LIBRARY_PATH` set to the matching `/var/lib/hmi/debug-runtime/<engine_version>/` directory. If the debug runtime or kernel blob is missing, launch MUST fail with an actionable message and MUST NOT attempt AOT `libapp.so` as a silent fallback for that debug payload.

#### Scenario: Debug payload on Weston with cached runtime

- **WHEN** `/opt/hmi` holds a valid debug payload and `/var/lib/hmi/debug-runtime/<ver>/` contains `libflutter_engine.so` and `icudtl.dat`
- **THEN** `hmi-launch.sh` starts Weston and `flutter-wayland-client` such that the Dart VM Service becomes available for the IDE tunnel

#### Scenario: Debug payload on Weston without runtime cache

- **WHEN** `/opt/hmi` holds `mode=debug` but the matching debug-runtime directory is incomplete
- **THEN** `hmi-launch.sh` exits with an error naming the missing path and does not leave an AOT-only client running against the JIT-only tree
