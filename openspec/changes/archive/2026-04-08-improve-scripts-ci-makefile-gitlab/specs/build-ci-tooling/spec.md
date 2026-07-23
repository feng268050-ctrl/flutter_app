## ADDED Requirements

### Requirement: Makefile provides build, device gate, install, and test targets

The repository SHALL include a root `Makefile` (or equivalent documented entry) that exposes targets to: (1) produce a **release** APK signed with the platform keystore; (2) run **device preflight** before any on-device step; (3) install the built APK to the **priv-app path** on the device; (4) run **instrumentation/UI tests** via Gradle; (5) execute **shell scripts** under `scripts/ci/` that are part of the agreed test suite.

#### Scenario: Developer runs the full local test flow

- **WHEN** the developer runs the documented target(s) for full validation on a configured machine with adb
- **THEN** the flow SHALL execute device preflight, then install, then UI tests, then `scripts/ci` scripts in the order defined in `tasks.md` / Makefile help without requiring undocumented manual steps

#### Scenario: Developer builds only

- **WHEN** the developer runs the documented build-only target
- **THEN** the system SHALL produce a release build signed according to the signing configuration without requiring a connected device

### Requirement: Signing uses platform keystore with env-based configuration

Build signing SHALL use the keystore file `platform.jks` at the repository root by default, with key alias and store/key passwords defaulting to `android` when not overridden. The same credentials SHALL be loadable from **system environment variables** and/or a **`.env`** file at the repository root (documented variable names); implementations MUST NOT require passwords to be committed in source control.

#### Scenario: CI passes signing via environment

- **WHEN** a CI job sets the documented environment variables for store path, alias, and passwords
- **THEN** the release build SHALL sign successfully without reading a committed secret file

#### Scenario: Local developer uses .env

- **WHEN** a developer creates a `.env` file with the documented keys matching the CI variable names
- **THEN** the documented workflow SHALL apply those values for local `make` or Gradle invocations

### Requirement: GitLab CI automates build and test

The repository SHALL include a `.gitlab-ci.yml` that defines automated **build** and **test** stages (or equivalent jobs) such that: the build job produces the application artifact; the test job depends on that artifact and runs the same logical steps as local testing (preflight, install, UI tests, `scripts/ci`).

#### Scenario: Pipeline runs build

- **WHEN** the pipeline executes the build job on a compatible runner
- **THEN** the job SHALL complete successfully and expose the built APK as an artifact for downstream jobs

#### Scenario: Pipeline runs tests with a device-backed runner

- **WHEN** the test job runs on a runner with adb access to a device that passes preflight
- **THEN** the test job SHALL execute device preflight, install, UI tests, and `scripts/ci` scripts and SHALL fail the pipeline if any step fails

### Requirement: Device preflight enforces adb device state

Before any on-device test or install step, automation SHALL verify that **adb** reports at least one connected device whose state is exactly **`device`** (not `offline`, `unauthorized`, or other states). If this check fails, the process SHALL exit with a non-zero status and SHALL NOT proceed to install or tests.

#### Scenario: No usable adb device

- **WHEN** no adb device is in `device` state
- **THEN** the command SHALL fail immediately with a clear error and SHALL NOT run install or tests

### Requirement: Device preflight enforces writable /system

Before any on-device test or install step, automation SHALL verify via adb that **`/system`** is writable on the target device (for example after remount, consistent with the device image). If `/system` is not writable, the process SHALL exit with a non-zero status and SHALL NOT proceed to install or tests.

#### Scenario: /system is read-only

- **WHEN** the device does not allow writing under `/system`
- **THEN** the command SHALL fail immediately with a clear error and SHALL NOT run install or tests

### Requirement: Device preflight enforces priv-app permissions XML

Before any on-device test or install step, automation SHALL verify that the file `/system/etc/permissions/privapp-permissions-com.lasercyber.lws.ui.xml` exists on the device and that its content grants **`android.permission.NETWORK_SETTINGS`** to package **`com.lasercyber.lws.ui`**. If the file is missing or the grant is incorrect, the process SHALL exit with a non-zero status and SHALL NOT proceed to install or tests.

#### Scenario: Permissions file missing

- **WHEN** the file is absent on the device
- **THEN** the command SHALL fail immediately with a clear error

#### Scenario: NETWORK_SETTINGS not granted to Lws UI

- **WHEN** the file exists but does not correctly grant `android.permission.NETWORK_SETTINGS` to `com.lasercyber.lws.ui`
- **THEN** the command SHALL fail immediately with a clear error

### Requirement: Release APK is installed to the priv-app path

After a successful release build and successful preflight, automation SHALL install the built APK to **`/system/priv-app/LwsUI/LwsUI.apk`** on the target device (overwriting or replacing as required by the platform), such that subsequent UI and `scripts/ci` tests run against this installation.

#### Scenario: Install completes before tests

- **WHEN** preflight succeeds
- **THEN** the APK SHALL be placed at `/system/priv-app/LwsUI/LwsUI.apk` before instrumentation or `scripts/ci` tests execute
