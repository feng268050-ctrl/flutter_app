## Context

P1 cross-builds a release AOT bundle with the pinned Flutter 3.24.4 SDK, installs it at `/opt/hmi`, and starts it through `hmi.service` using the release engine. `make push-app` already selects a physical board by `SERIAL`, binds SSH/SCP to the matching USB ECM interface, stages a release payload, and safely restarts flutter-pi.

A Flutter debug session is not just a different `libapp.so`: it uses a JIT kernel bundle, a debug-runtime engine, and a Dart VM Service connection. Debug and release engines SHALL come from the same pinned Flutter version/source, but they are distinct runtime-mode binaries: debug provides JIT/VM Service/hot reload, while release executes the AOT payload. The current image contains only the release-runtime binary. The IDE also needs a device known to the pinned Flutter CLI; invoking `flutterpi_tool run` in an unrelated terminal does not by itself give the VS Code / Cursor Flutter extension ownership of the debug session.

The design must retain the one-firmware-image principle, reuse USB plug-SSH and the DRM teardown fix, work with one or multiple attached boards, and avoid persistent network debug exposure.

## Goals / Non-Goals

**Goals:**

- Make `make debug-app` build, deploy, and run the app in Flutter debug mode on a selected physical ynh960.
- Make the same target available from VS Code / Cursor Run & Debug through the Flutter extension, including breakpoints, hot reload/restart, widget inspection, and DevTools.
- Keep the pinned SDK, device selection, credentials, and USB interface routing consistent across Make, scripts, and the IDE.
- Replace the installed app persistently, leave the debug app running after IDE detach, and let `make push-app` explicitly replace it with a release app.
- Avoid repeated transfer of the large debug engine when an identical runtime is already cached on the board.

**Non-Goals:**

- Linux emulator or virtual-machine construction, discovery, deployment, or debugging.
- Android debugging, profile/release IDE modes, or remote debugging over production LAN.
- A separate debug firmware/overlay variant or an always-on VM Service.
- Changing the release `make build-app` / `make push-app` workflow.

## Decisions

### 1. Use a Flutter Custom Device as the IDE contract

The pinned Flutter SDK's Custom Devices feature will be enabled and configured with a stable logical device ID such as `lws-hmi`. A repository script will idempotently install/update that user-scoped device definition; generated commands will call repository-owned adapters rather than embedding addresses, passwords, or duplicated deployment logic in editor JSON.

The custom device's discovery, install, run, stop, and SSH port-forward commands will delegate to the same USB-SSH selection layer used by `make push-app`. `SERIAL` remains authoritative when multiple boards are attached, and all commands bind to the selected ECM interface even though boards share `192.168.55.1`.

The repository will check in Flutter launch configuration under repo-root `.vscode/` (workspace opened at `lws-hmi`, with `cwd` pointing at `app/hmi`). Run & Debug launches the named custom device through the Flutter extension, so the extension owns the `flutter run` protocol and can expose normal debug actions and DevTools.

Alternative considered: start `flutterpi_tool run` as a generic pre-launch task and attach later. This leaves VM URI hand-off and debugger lifecycle outside the Flutter extension and makes a one-click Run & Debug flow fragile.

### 2. Keep `make debug-app` and IDE launch on one underlying path

`make debug-app` will load `.env`, validate/install the custom-device definition, select the board, and invoke the pinned Flutter CLI in debug mode for `app/hmi`. The custom-device adapter performs the actual debug bundle install and flutter-pi launch. Starting the checked-in IDE launch configuration invokes the same custom-device definition directly, not a second bespoke deployment implementation.

The build must use the pinned Flutter SDK and a meta-flutter-compatible ARM64 debug layout. The implementation will first validate the exact Flutter 3.24.4 custom-device contract and a compatible historical `flutterpi_tool` release (whose changelog includes Flutter 3.24 run support) on the target; tests will lock down the resulting file mapping so later tool upgrades fail clearly rather than silently installing a release bundle.

P3.5 is not advanced preemptively. If this validation proves that Flutter 3.24.4 cannot provide the required Custom Device, debugger, and DevTools workflow, implementation stops and proposes the SDK/engine/flutter-pi upgrade as a separate prerequisite with its own full platform regression. Upgrading Flutter would improve tooling compatibility but would not remove the need for separate debug- and release-runtime engine binaries.

Alternative considered: extend `scripts/build-app.sh` with a mode flag and make the IDE parse a manually printed VM URI. Separate release and debug lifecycles are easier to reason about, and Flutter CLI ownership removes custom debugger hand-off.

### 3. Provision the same-version debug runtime on demand

The production rootfs continues to use `/usr/lib/libflutter_engine.so` as the release-runtime binary. A matching ARM64 debug-runtime binary built from the same Flutter version/source, plus ICU data, will be obtained through the existing pinned prebuilt/cache workflow and uploaded to a versioned directory under `/var/lib/hmi/debug-runtime/`. The host compares a version/hash manifest and skips the runtime upload when the target already has the exact runtime.

The debug launch adapter sets an isolated engine/library/data path for flutter-pi; it must never overwrite the release engine. If no matching local debug runtime can be obtained, `make debug-app` fails before stopping `hmi.service` and prints the exact dependency command.

Alternative considered: co-install the debug engine in every rootfs. That makes first launch faster but permanently increases the production image and exposes debug-only runtime code. On-demand caching preserves the single production image and pays the transfer cost only once per engine version/device.

### 4. Make the last successful deployment the installed app

The host uploads into a dedicated staging directory. A root-owned device helper validates the complete payload and runtime before stopping the current flutter-pi process, then atomically replaces `/opt/hmi` with the debug payload and writes a runtime-mode manifest. No backup copy of the previous app is retained.

`hmi.service` will launch through a small mode-aware wrapper. Release payloads use the existing release engine and `--release`; debug payloads use the cached matching debug engine without `--release`. Missing or invalid manifests default safely to the existing release behavior. This lets either the last `make debug-app` or the last `make push-app` remain the installed version and start correctly after a service restart or board reboot.

IDE detach/stop closes the debugger and SSH forwarding but deliberately does not terminate debug flutter-pi. A later `make debug-app` stops and replaces the current app with a new debug build. `make push-app` remains the explicit way to replace it with the current release build and restart `hmi.service`.

Alternative considered: preserve and automatically restore the release payload when debugging ends. That adds backup, recovery, and lifecycle complexity while contradicting the expected development workflow in which the latest pushed build remains installed.

### 5. Tunnel VM Service through the selected SSH link

The debug engine binds its VM Service on the target loopback interface. The Flutter custom device uses its port-forward command to create an SSH tunnel over the selected USB ECM interface, and reports the forwarded host port through Flutter's expected success regex. The VM Service is therefore reachable by the Flutter extension and DevTools without binding an unauthenticated service to `0.0.0.0`.

IDE stop or USB unplug closes the SSH tunnel. The debug app and its loopback-only VM Service may continue running so a later IDE session can reconnect or a new deployment can replace it. A release app installed by `make push-app` does not start a VM Service.

Alternative considered: bind a fixed VM Service port on all USB interfaces and use a fixed attach URI. That is simpler, but weakens isolation and does not handle multiple boards cleanly.

### 6. Treat debug tooling as host-side setup, not a firmware flavor

The Makefile will expose `debug-app` and any narrowly required setup/stop helper targets, update `make help`, and load existing `.env` values through `WITH_DOTENV`. Documentation will distinguish the one-time debug runtime prerequisite from the per-session command and explain device selection, IDE setup, DevTools, persistent debug behavior, and replacement with `make push-app`.

Linux emulator tasks in the broader P1.5 plan remain unchecked and explicitly deferred.

## Risks / Trade-offs

- **Flutter 3.24.4 custom-device command semantics may differ from current documentation** → Validate the pinned SDK with a compatible historical `flutterpi_tool`; if the required IDE workflow is impossible, stop and advance P3.5 as a separate prerequisite instead of mixing a platform upgrade into this change.
- **Debug engine and app mode mismatch can hang or report an invalid kernel binary** → Match both to the repository engine version and require a target manifest/hash before stopping the release service.
- **Interrupted replacement can leave the new payload incomplete** → Stage and validate everything before atomically replacing `/opt/hmi`; leave the currently installed app untouched on pre-commit failure.
- **A new debug replacement path could regress the already-fixed DRM teardown behavior** → Reuse the same stop/restart path validated by `make push-app` and keep repeated debug/release replacement as regression coverage, not as an unresolved platform risk.
- **The first debug session transfers a large engine** → Cache by version/hash under `/var/lib`; subsequent sessions transfer only the app payload.
- **User-scoped Flutter custom-device state can drift** → Provide an idempotent repository setup/doctor command and make both CLI and IDE entry points validate it.
- **Password-based SSH appears in process arguments through `sshpass`** → Reuse the current development-only USB-SSH model, avoid persisting credentials in IDE files, and keep VM Service loopback-only.

## Migration Plan

1. Validate Flutter 3.24.4 plus a compatible `flutterpi_tool`; continue only if the required IDE/DevTools workflow works, otherwise propose advancing P3.5 separately.
2. Add and test host custom-device setup/adapters without changing the release deployment path.
3. Add atomic install and mode-aware launch helpers to the normal rootfs overlay and verify release boot remains unchanged.
4. Produce/cache the same-version debug-runtime engine, then test first-time and cached runtime deployment on ynh960.
5. Verify CLI debug build, install, VM Service tunnel, hot reload, IDE detach with the debug app still running, and reboot of both debug and release payloads.
6. Add checked-in IDE configuration and verify Cursor/VS Code Flutter extension launch, breakpoints, widget inspection, and DevTools.
7. Update Make/README/app documentation and mark only the physical-device P1.5 items complete.

Rollback is to remove the host custom-device definition and run `make build-app` followed by `make push-app`, or reflash the normal image.

## Open Questions

- Which exact historical `flutterpi_tool` version compatible with Flutter 3.24.4 should be pinned after validating its debug bundle and IDE workflow?
- Which flutter-pi/engine flags and custom-device success regex are required by the pinned toolchain for VM Service discovery?
- What measured first-session debug runtime size and upload time are acceptable over USB ECM?
