## 1. Validate and Pin the Debug Toolchain

- [x] 1.1 Use the pinned Flutter 3.24.4 SDK to validate Custom Devices support, generated config schema, install/run/stop command interpolation, VM Service discovery, and SSH `forwardPort` behavior.
- [x] 1.2 Validate historical `flutterpi_tool` releases with Flutter 3.24.4 on ARM64 meta-flutter, record the exact debug bundle and IDE workflow, and pin the compatible tool version in repository setup.
- [x] 1.3 If no compatible 3.24.4 toolchain provides Custom Device debugging and DevTools, stop this implementation and propose advancing P3.5 as a separate prerequisite.
- [x] 1.4 Build or obtain an `arm64-debug` engine from the same Flutter version/source as the release engine and verify flutter-pi engine/ICU selection without modifying the release runtime.

## 2. Build Shared Host Debug Infrastructure

- [x] 2.1 Refactor only the reusable device-selection, reachability, SSH/SCP, and interface-binding pieces needed by both release push and debug adapters while preserving `make push-app` behavior.
- [x] 2.2 Add a debug bundle preparation command that always uses the pinned SDK, rejects release artifacts or version mismatches, and emits the validated ARM64 meta-flutter debug layout.
- [x] 2.3 Add debug runtime manifest/hash generation and host checks that locate the matching engine/ICU prebuilt or fail with the exact prerequisite command.
- [x] 2.4 Add host adapter commands for custom-device discovery, payload installation, debug launch, stop, log streaming, and SSH port forwarding, all honoring `.env` and `SERIAL`.
- [x] 2.5 Add host-side tests for single/multiple device selection, shared target IP interface binding, missing prerequisites, manifest cache hits, and failure before release-service interruption.

## 3. Implement Persistent Debug Deployment Lifecycle

- [x] 3.1 Add rootfs-overlay helpers and directories to stage and validate the debug app/runtime before stopping `hmi.service`.
- [x] 3.2 Implement versioned debug engine/ICU caching under `/var/lib/hmi/debug-runtime/` without overwriting release engine or ICU paths.
- [x] 3.3 Implement atomic `/opt/hmi` replacement and a validated runtime-mode manifest for both debug and release payloads, without retaining an automatic backup of the previous app.
- [x] 3.4 Add a mode-aware `hmi.service` launcher that selects release engine plus `--release` for release payloads and the matching cached debug engine for debug payloads.
- [x] 3.5 Make IDE detach/stop close debugging and forwarding without terminating debug flutter-pi; make the next `debug-app` or `push-app` stop and replace the currently installed app.
- [x] 3.6 Add shell/static tests for incomplete transfer, invalid/missing mode manifest, debug/release mode selection, repeated replacement, and reboot with either payload type installed.

## 4. Add Make and Flutter Custom Device Entry Points

- [x] 4.1 Add an idempotent setup/doctor script that enables Custom Devices in the pinned Flutter SDK and installs or updates the stable `lws-hmi` user-scoped device definition using repository adapter commands.
- [x] 4.2 Add `make debug-app` with `.env` loading so it validates setup, selects the physical board, and invokes the pinned Flutter CLI in debug mode on the `lws-hmi` custom device.
- [x] 4.3 Add any narrowly required debug setup/stop targets and update Makefile `.PHONY` declarations and `make help` text for every new target.
- [x] 4.4 Update `.env.example` with debug configuration only where no existing variable applies, keeping credentials and per-user paths out of committed IDE files.

## 5. Integrate VS Code and Cursor

- [x] 5.1 Add checked-in repo-root `.vscode/launch.json` Flutter configuration that launches the `lws-hmi` custom device from Run & Debug using the pinned SDK (workspace: `lws-hmi` root).
- [x] 5.2 Add minimal workspace settings/tasks needed for Cursor and VS Code to resolve the pinned Flutter SDK and run setup/doctor without duplicating `.env` device configuration.
- [x] 5.3 Verify IDE start, source breakpoints, pause/step, hot reload, hot restart, log output, widget inspection, and Flutter DevTools against the physical ynh960.
- [x] 5.4 Verify IDE stop closes the SSH tunnel while the debug app continues running, and verify a later IDE session can reconnect or replace it.

## 6. End-to-End Device Verification

- [x] 6.1 Verify first-session runtime upload and subsequent manifest cache hit on a flashed P1 ynh960.
- [x] 6.2 Run repeated release → debug → release cycles as regression coverage for the already-validated DRM GEM teardown fix and confirm the new path reuses the bounded restart behavior.
- [x] 6.3 Interrupt debug at app upload, runtime upload, launch, active session, and USB disconnect points; verify a pre-commit failure leaves the previously installed app unchanged and a post-launch disconnect leaves debug running.
- [x] 6.4 Reboot once with a debug payload and once with a release payload installed; verify the mode-aware launcher selects the matching engine and runtime mode.
- [x] 6.5 Connect multiple physical boards sharing `192.168.55.1` and verify `SERIAL` confines deployment, debug control, logs, and VM Service forwarding to the selected ECM interface.
- [x] 6.6 Run `verify-boot` and relevant rootfs-overlay verification after the final firmware change.
- [x] 6.7 Run `make push-app` after debugging and verify it replaces the debug payload and returns the device to the release app.

## 7. Documentation and Plan Alignment

- [x] 7.1 Update README Make command documentation, app debugging instructions, prerequisites, first-run engine cost, DevTools workflow, persistent debug behavior, release replacement, and troubleshooting.
- [x] 7.2 Update `AGENTS.md` rebuild guidance for new debug-related targets and ensure user-facing commands remain one command per line.
- [x] 7.3 Update `docs/flutter-pi-hmi-plan.md` to mark only the implemented physical-device `debug-app` and IDE items complete while leaving Linux emulator items deferred.
- [x] 7.4 Verify no `make emulator`, VM launcher, or emulator deployment branch was introduced by this change.
