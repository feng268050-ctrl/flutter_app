## Why

Developers and CI need a single, repeatable path to sign release builds with the platform key, install the system-privileged APK to the expected priv-app location, and run on-device checks—including existing `scripts/ci` smoke tests—without ad hoc commands. Today there is no standard Makefile or GitLab pipeline tying these steps together, which slows validation and risks inconsistent environments.

## What Changes

- Add a **Makefile** at the repo root with targets for build (signed with `platform.jks`), device preflight (adb `device`, writable `/system`, priv-app permissions XML), priv-app install to `/system/priv-app/LwsUI/LwsUI.apk`, and test orchestration (including UI / `scripts/ci` flows).
- Add **`.gitlab-ci.yml`** to automate build and test on suitable GitLab runners (with documented expectations for attached hardware and adb).
- Centralize **signing configuration**: default alias and passwords `android` for `platform.jks`, overridable via **`.env` and/or environment variables** (no secrets committed in plain text beyond what the team already uses for local dev).
- Implement **test gates** before any on-device test: require at least one adb device in `device` state; verify `/system` is writable (non-writable ⇒ fail fast); verify `/system/etc/permissions/privapp-permissions-com.lasercyber.lws.ui.xml` exists and grants the expected privileged permissions—otherwise fail fast.
- After a successful build, **push the APK** to `/system/priv-app/LwsUI/LwsUI.apk` on the device, then run **UI tests** and **`scripts/ci`** shell scripts as part of the documented test phase.

## Capabilities

### New Capabilities

- `build-ci-tooling`: Local and GitLab automation for building a signed system app, gating on a properly configured priv-app test device, installing to `/system/priv-app/LwsUI/LwsUI.apk`, and running UI plus `scripts/ci` tests with clear failure semantics.

### Modified Capabilities

- (none) — existing product specs for WiFi and UI are unchanged; this change adds tooling and pipeline requirements only.

## Impact

- New or updated files: `Makefile`, `.gitlab-ci.yml`, optional `.env.example` (if used), and supporting scripts under `scripts/ci/` or adjacent helpers as needed.
- Developers must have adb, a **writable `/system`** test device, and correct **priv-app permissions XML** on device to pass the test stage; CI runners must expose the same unless jobs are manual/scheduled on hardware.
- References `platform.jks` at the repo root (already present); signing defaults align with alias/password `android` unless overridden by env.
