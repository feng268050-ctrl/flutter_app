## Why

P1 currently supports release-mode app rebuild and replacement, but developers cannot use breakpoints, hot reload, VM Service, or Flutter DevTools against the application running on a physical ynh960. P1.5 needs a single, repository-managed workflow that turns the existing USB-SSH device path into a Flutter IDE debugging target without creating a separate debug firmware.

## What Changes

- Add `make debug-app` to build the pinned Flutter application in debug mode, transfer the debug payload to the selected physical device, replace the firmware-bundled app, and launch it with the debug-runtime engine built from the same Flutter version/source as the release engine.
- Expose the Dart VM Service over the existing USB-SSH network and report connection metadata in a machine-readable form suitable for IDE attachment.
- Add checked-in VS Code / Cursor Run & Debug configuration so the Flutter extension can start the device workflow directly, attach to the running application, and open Flutter DevTools.
- Reuse repository `.env` and environment variables, including `FLUTTER_SDK` and `SERIAL`, so Make, scripts, and the IDE share one device and SDK configuration.
- Preserve the last successfully deployed app on the device: IDE detach closes the debug connection but leaves the debug app running; a later `make debug-app` replaces it with another debug build and `make push-app` explicitly replaces it with a release build.
- Preserve production behavior: no debug firmware variant and no VM Service exposed beyond the USB-SSH development path.
- Document setup, use, troubleshooting, and the distinction between release `make push-app` and debug `make debug-app`.
- Validate Flutter 3.24.4 with a compatible historical `flutterpi_tool` first; only propose advancing the P3.5 Flutter SDK/engine/flutter-pi upgrade as a separate prerequisite if the pinned stack cannot provide the required IDE and DevTools workflow.
- Exclude Linux emulator construction and emulator deployment from this change.

## Capabilities

### New Capabilities

- `host-debug-hmi`: Physical-device Flutter debug build, USB-SSH deployment, debug runtime lifecycle, IDE launch/attach integration, and DevTools connectivity.

### Modified Capabilities

None.

## Impact

- Host build and deployment entry points: `Makefile`, app build/debug scripts, shared USB-SSH helpers, and `.env.example`.
- Device runtime and rootfs overlay: debug engine availability, installed-app runtime-mode selection, VM Service exposure, and safe replacement between debug and release payloads.
- IDE integration under the repository/app workspace for VS Code and Cursor Flutter tooling.
- Developer documentation and P1.5 plan/checklist alignment.
- The device keeps separate release and debug runtime-mode engine binaries from the same pinned Flutter version; the debug binary is provisioned on demand rather than added to the firmware image.

## Non-goals

- `make emulator`, Linux virtual-machine support, or Linux emulator targets for `push-app` / `debug-app`.
- Android debugging, production remote debugging, or a separate debug firmware image.
