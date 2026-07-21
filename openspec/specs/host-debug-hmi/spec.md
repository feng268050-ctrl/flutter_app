# host-debug-hmi Specification

## Purpose

Host-side physical-device Flutter debugging over USB-SSH, including debug deployment, runtime isolation, IDE integration, DevTools, and hot reload.

## Requirements


### Requirement: make debug-app starts a physical-device Flutter debug session

The repository SHALL provide `make debug-app` that uses the pinned Flutter SDK to build the application as an ARM64 debug bundle, deploys it over USB-SSH to the selected physical lws-hmi device, replaces the firmware-bundled application for the session, and starts flutter-pi in debug mode.

The target SHALL run the debug bundle with a debug-runtime engine built from the same pinned Flutter version/source as the release-runtime engine. The two runtime-mode binaries are distinct because debug requires JIT, VM Service, and hot reload while release executes AOT output. The command MUST fail before stopping the release HMI if the app bundle, engine, or version manifest is missing or incompatible.

#### Scenario: Start debug session on one connected board

- **WHEN** one compatible ynh960 is connected over USB-SSH and the developer runs `make debug-app`
- **THEN** the pinned SDK builds a debug bundle, the bundle is installed on that board, and flutter-pi displays it without the `--release` runtime mode
- **AND** the command does not require rebuilding, repacking, or flashing a firmware image

#### Scenario: Debug runtime is incompatible

- **WHEN** the available debug engine does not match the pinned app SDK/engine version
- **THEN** `make debug-app` fails with an actionable dependency command before changing the running release application

### Requirement: Debug deployment uses existing repository device selection

Debug host commands SHALL reuse `.env` and the shared device selection contract used by other repository commands, including `FLUTTER_SDK`, `SN` / `LWS_HMI_SN`, `IP` / `LWS_HMI_IP` (SSH registry only), USB/SSH target credentials, reachability timeout, and transport-appropriate SSH/SCP routing (ECM bind for USB-SSH; unbound TCP for registered SSH).

#### Scenario: Multiple boards without SN

- **WHEN** multiple USB-SSH boards are connected and no serial or IP is configured
- **THEN** the debug command fails with instructions to run `make devices` and set `SN` or `IP`

#### Scenario: SN selects one board

- **WHEN** multiple boards share target address `192.168.55.1` and `SN=<sn|chipid>` selects one board
- **THEN** all debug upload, launch, stop, and port-forward traffic uses only the ECM interface associated with that board

#### Scenario: IP selects registered SSH board

- **WHEN** a remote SSH device is registered and `IP=<ip> make debug-app` is run
- **THEN** all debug upload, launch, stop, and port-forward traffic targets that IP over unbound SSH

#### Scenario: Configuration loaded from dotenv

- **WHEN** the developer configures the pinned SDK and board serial in the repository `.env`
- **THEN** `make debug-app` and the IDE device adapter use those values without a second IDE-specific copy
### Requirement: Same-version debug runtime is cached without replacing the release engine

The host workflow SHALL provision the matching debug-runtime engine and ICU data into a versioned debug-runtime directory on the target and SHALL skip uploading unchanged runtime files when a manifest/hash confirms an exact match. The debug and release engine binaries MUST be built from the same pinned Flutter version/source, and the debug workflow MUST NOT replace the release-runtime binary or ICU data used for release payloads.

#### Scenario: First debug session on a device

- **WHEN** the selected board has no matching cached debug runtime
- **THEN** the host uploads and validates the pinned debug engine and ICU data before starting the debug app

#### Scenario: Subsequent debug session

- **WHEN** the selected board already contains a cached runtime with the expected version and hashes
- **THEN** the host deploys the changed debug app without retransferring the unchanged engine payload

#### Scenario: Release service starts after debugging

- **WHEN** a debug session has ended and `hmi.service` starts
- **THEN** it still uses the original release engine and release runtime paths

### Requirement: The last successful app deployment remains installed

The device SHALL stage and validate a complete payload before stopping the current flutter-pi process and atomically replacing `/opt/hmi`. Each installed payload SHALL include a validated runtime-mode manifest so `hmi.service` launches release payloads with the release engine and `--release`, and debug payloads with the matching cached debug engine and debug runtime mode.

IDE detach or stop SHALL close the debugger connection without terminating the running debug application or restoring an older release payload. A later `make debug-app` SHALL replace the installed app with a newer debug build; `make push-app` SHALL replace it with the current release build.

#### Scenario: Normal IDE stop

- **WHEN** the developer stops or detaches the debug session from VS Code or Cursor
- **THEN** the debugger connection closes and the installed debug app continues running on the device

#### Scenario: Host disconnects during a session

- **WHEN** the USB link or IDE process disappears after the debug payload was installed
- **THEN** the installed debug app continues running independently of the host connection

#### Scenario: Board reboots with debug app installed

- **WHEN** the board reboots after a debug payload was successfully installed
- **THEN** `hmi.service` selects the cached matching debug engine and starts that debug payload without `--release`

#### Scenario: push-app replaces debug app

- **WHEN** a debug payload is installed and the developer runs `make build-app` followed by `make push-app`
- **THEN** `/opt/hmi` is replaced by the release payload and `hmi.service` starts it with the release engine and `--release`

#### Scenario: Payload transfer fails

- **WHEN** debug app or runtime transfer fails before transaction commit
- **THEN** the currently installed debug or release app remains unchanged

### Requirement: Flutter IDE exposes lws-hmi as a custom debug device

The repository SHALL provide an idempotent setup/doctor path for the pinned Flutter SDK's Custom Devices feature and SHALL define a stable lws-hmi device whose commands delegate to repository USB-SSH adapters.

The repository SHALL include VS Code / Cursor Flutter launch configuration that can be selected in Run & Debug and starts the application on that custom device through the Flutter extension.

Implementation SHALL first validate Flutter 3.24.4 with a compatible historical `flutterpi_tool`. If that pinned stack cannot provide the required debugger and DevTools workflow, this change MUST stop before partial device integration and identify the P3.5 SDK/engine/flutter-pi upgrade as a separate prerequisite.

#### Scenario: First-time IDE setup

- **WHEN** a developer completes the documented setup with the pinned Flutter SDK
- **THEN** Flutter device discovery and the VS Code / Cursor Flutter extension show the lws-hmi custom device

#### Scenario: Start from Run and Debug

- **WHEN** the developer selects the checked-in lws-hmi Flutter launch configuration and starts debugging
- **THEN** the Flutter extension builds, installs, and launches the app on the selected physical board and binds source breakpoints

#### Scenario: Custom device configuration drifts

- **WHEN** the user-scoped custom-device definition is missing or differs from the repository definition
- **THEN** the setup/doctor path restores it idempotently or reports the exact corrective action

#### Scenario: Pinned toolchain cannot support IDE debugging

- **WHEN** validation proves Flutter 3.24.4 and compatible historical `flutterpi_tool` releases cannot provide the required Custom Device, debugger, and DevTools behavior
- **THEN** implementation stops without mixing a Flutter platform upgrade into this change and records advancing P3.5 as a separate prerequisite

### Requirement: Flutter DevTools connects through a session-scoped VM Service tunnel

The debug process SHALL expose the Dart VM Service on target loopback only, and the custom device SHALL establish an SSH port forward over the selected USB ECM interface. The Flutter extension SHALL receive the forwarded service endpoint so Flutter DevTools, hot reload, hot restart, widget inspection, logging, and debugger controls operate on the device application.

The SSH tunnel MUST end when the IDE disconnects. The loopback-only VM Service MAY remain alive with the installed debug app so a later session can reconnect. A release payload installed by `make push-app` MUST NOT start a VM Service.

#### Scenario: Open DevTools during IDE session

- **WHEN** the application is running from the lws-hmi Flutter launch configuration and the developer opens Flutter DevTools
- **THEN** DevTools connects to that device session and can inspect its widget tree and runtime state

#### Scenario: Hot reload

- **WHEN** the developer changes Dart UI code and invokes hot reload in the IDE
- **THEN** the running device application updates without rebuilding rootfs, repacking an image, flashing, or restarting the board

#### Scenario: Debug session ends

- **WHEN** the developer stops or detaches the IDE debug session
- **THEN** the SSH port forward closes while the debug app continues running with no VM Service exposed beyond target loopback

### Requirement: Linux emulator is excluded from this debug workflow

This capability SHALL target physical lws-hmi boards over USB-SSH only. It SHALL NOT add `make emulator`, Linux virtual-machine discovery, or emulator branches to `make debug-app`.

#### Scenario: Proposal implementation is reviewed

- **WHEN** the P1.5 physical-device debug change is implemented
- **THEN** no emulator target, VM image launcher, or emulator deployment path is introduced by this change
