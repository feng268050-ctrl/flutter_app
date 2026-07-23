## Purpose

Define build/test tooling behavior for local and GitLab CI workflows, including signing configuration, device preflight, privileged install path, and scripted validation steps.
## Requirements
### Requirement: Makefile provides build, device gate, install, and test targets

The repository SHALL include a root `Makefile` (or equivalent documented entry) that exposes targets to: (1) produce a **release** APK signed with the platform keystore; (2) run **device preflight** before any on-device step; (3) install the built APK to the **priv-app path** on the device; (4) run **instrumentation/UI tests** via Gradle; (5) execute **shell scripts** under `scripts/ci/` that are part of the agreed test suite; (6) print the current app version (`make version`); (7) bump `versionName` and `versionCode` in `app/build.gradle.kts` (`make version-bump VERSION=x.y.z+build`); (8) trigger a demo alarm popup on a connected device (`make alarm CODE=<alarm-code>`).

#### Scenario: Developer runs the full local test flow

- **WHEN** the developer runs the documented target(s) for full validation on a configured machine with adb
- **THEN** the flow SHALL execute device preflight, then install, then UI tests, then `scripts/ci` scripts in the order defined in `tasks.md` / Makefile help without requiring undocumented manual steps

#### Scenario: Developer builds only

- **WHEN** the developer runs the documented build-only target
- **THEN** the system SHALL produce a release build signed according to the signing configuration without requiring a connected device

#### Scenario: Developer prints app version

- **WHEN** the developer runs `make version`
- **THEN** the Makefile SHALL print `versionName+versionCode` sourced from `app/build.gradle.kts` without requiring a connected device

#### Scenario: Developer bumps app version before release

- **WHEN** the developer runs `make version-bump VERSION=x.y.z+build` with a valid version per project digit rules
- **THEN** `app/build.gradle.kts` SHALL be updated before the next `make build` or pack workflow uses the new `versionName`

#### Scenario: Developer triggers demo alarm on device

- **WHEN** the developer runs `make alarm CODE=<alarm-code>` with a connected adb device in `device` state and a non-empty code
- **THEN** the Makefile SHALL send the documented adb broadcast to the LWS UI package to trigger the corresponding demo alarm popup
- **AND** SHALL fail fast with a clear message when `CODE` is missing or adb preflight fails

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

### Requirement: make emulator syncs host LAN IP into model.properties every run

The `make emulator` workflow (via `scripts/emulator-launch.sh` and shared helpers) SHALL, after successful adb remount on the target emulator, update `/system/etc/model.properties` on the guest **on every invocation**, without requiring `REBUILD_IMAGE=1` or AVD recreation.

When a host LAN IPv4 can be resolved, the sync SHALL write property `host_ip=<ipv4>`. When resolution fails and env `HOST_IP` is unset or empty, the sync MUST NOT add or overwrite `host_ip` with a placeholder. When env `HOST_IP` is set to a non-empty value, that value MUST be written as `host_ip`.

The sync MUST preserve existing keys in the on-device file (e.g. `model`, `sn`, `camera_ip`, `camera_type`, `focus_scale_ref`) unless overridden by corresponding env vars (`MODEL`, `SN`, `CAMERA_IP`, `CAMERA_TYPE`, `FOCUS_SCALE_REF`) or explicit merge rules documented in the emulator scripts.

Env **`CAMERA_TYPE`** SHALL accept `1` or `2`. When set, the sync MUST write `camera_type=<value>`. When unset, the sync MUST retain an existing on-device `camera_type` if present; otherwise MUST write `camera_type=1`. Invalid `CAMERA_TYPE` values MUST cause the emulator workflow to fail before push.

Env **`FOCUS_SCALE_REF`** SHALL accept a signed integer. When set, the sync MUST write `focus_scale_ref=<value>`. When unset, the sync MUST retain an existing on-device `focus_scale_ref` if present; otherwise MUST write `focus_scale_ref=0`. Invalid `FOCUS_SCALE_REF` values MUST cause the emulator workflow to fail before push.

#### Scenario: Host IP detected on emulator launch

- **WHEN** the developer runs `make emulator` and the host resolves LAN IPv4 `192.168.1.50`
- **THEN** `/system/etc/model.properties` on the emulator MUST contain `host_ip=192.168.1.50` after remount completes

#### Scenario: Reused AVD without REBUILD_IMAGE still updates host_ip

- **WHEN** the developer runs `make emulator` on an existing AVD without `REBUILD_IMAGE=1`
- **AND** the host LAN IPv4 changes or is newly detectable
- **THEN** the on-device `host_ip` property MUST reflect the current detected value after that run

#### Scenario: HOST_IP env override wins over auto-detect

- **WHEN** the developer runs `make emulator` with `HOST_IP=10.0.0.8` set
- **THEN** `/system/etc/model.properties` MUST contain `host_ip=10.0.0.8` regardless of auto-detected addresses

#### Scenario: CAMERA_TYPE written on emulator launch

- **WHEN** the developer runs `CAMERA_TYPE=2 make emulator`
- **THEN** `/system/etc/model.properties` on the emulator MUST contain `camera_type=2` after sync completes

#### Scenario: Emulator defaults camera_type when unset

- **WHEN** the developer runs `make emulator` without `CAMERA_TYPE`
- **AND** the on-device file has no `camera_type` key
- **THEN** the synced file MUST contain `camera_type=1`

#### Scenario: FOCUS_SCALE_REF written on emulator launch

- **WHEN** the developer runs `FOCUS_SCALE_REF=-4 make emulator`
- **THEN** `/system/etc/model.properties` on the emulator MUST contain `focus_scale_ref=-4` after sync completes

#### Scenario: Emulator defaults focus_scale_ref when unset

- **WHEN** the developer runs `make emulator` without `FOCUS_SCALE_REF`
- **AND** the on-device file has no `focus_scale_ref` key
- **THEN** the synced file MUST contain `focus_scale_ref=0`

### Requirement: Emulator local HTTP forward restarts adb server on all interfaces

Before establishing `adb forward tcp:5580 tcp:5580` for an emulator serial (`emulator-*`), automation SHALL execute `adb kill-server` followed by `adb -a server start` using the same SDK `adb` binary used for the forward.

This prelude MUST run in the shared forward helper invoked by `make emulator`, `make install` when the adb target is an emulator, and `make emulator-forward`.

#### Scenario: Emulator launch forward uses adb -a

- **WHEN** `make emulator` completes boot and remount and sets up local HTTP forward
- **THEN** automation MUST restart the adb server with `-a` before creating the `tcp:5580` forward mapping

#### Scenario: make install on emulator restarts adb before forward

- **WHEN** `make install` targets serial `emulator-5554` and re-applies the `:5580` forward after reboot
- **THEN** automation MUST run `adb kill-server` and `adb -a server start` before forward setup

#### Scenario: Physical device install does not require adb -a prelude

- **WHEN** `make install` targets a non-emulator adb serial
- **THEN** the adb `-a` restart prelude for emulator forward MUST NOT be required for that install path

### Requirement: make prepare writes camera_type to model.properties

The `make prepare` workflow (via `scripts/ci/prepare-device.sh`) SHALL support env var **`CAMERA_TYPE`** with allowed values `1` or `2`. When model config is written to `/system/etc/model.properties`, the script MUST include `camera_type=<value>`.

When `CAMERA_TYPE` is unset and the script writes model config keys, `camera_type` MUST default to `1`.

When `CAMERA_TYPE` is set to a value other than `1` or `2`, the script MUST fail with a non-zero exit and a clear error message.

#### Scenario: Prepare with explicit red light

- **WHEN** the developer runs `CAMERA_TYPE=2 make prepare` with other required env set
- **THEN** `/system/etc/model.properties` on the device MUST contain `camera_type=2`

#### Scenario: Prepare without CAMERA_TYPE defaults to one

- **WHEN** the developer runs `make prepare` with `MODEL` or `SN` set but `CAMERA_TYPE` unset
- **THEN** the pushed `model.properties` MUST contain `camera_type=1`

#### Scenario: Invalid CAMERA_TYPE rejected

- **WHEN** the developer runs `CAMERA_TYPE=3 make prepare`
- **THEN** prepare MUST exit non-zero before modifying the device

### Requirement: Makefile documents CAMERA_TYPE for prepare and emulator

The root `Makefile` help text SHALL document `CAMERA_TYPE=<1|2>` for `make prepare` and `make emulator`, noting default `1` (BLUE_LIGHT) and `2` (RED_LIGHT).

#### Scenario: make help lists camera type

- **WHEN** the developer runs `make help` (or equivalent documented help target)
- **THEN** output MUST mention `CAMERA_TYPE` alongside `CAMERA_IP` and `HOST_IP`

### Requirement: make prepare writes focus_scale_ref to model.properties

The `make prepare` workflow (via `scripts/ci/prepare-device.sh`) SHALL support env var **`FOCUS_SCALE_REF`** as a signed integer. When model config is written to `/system/etc/model.properties`, the script MUST include `focus_scale_ref=<value>`.

When `FOCUS_SCALE_REF` is unset and the script writes model config keys, `focus_scale_ref` MUST default to `0`.

When `FOCUS_SCALE_REF` is set to a non-integer value, the script MUST fail with a non-zero exit and a clear error message.

The prepare script MUST write model config when **only** `FOCUS_SCALE_REF` is set (alongside existing triggers for `MODEL`, `SN`, `CAMERA_IP`, `CAMERA_TYPE`).

#### Scenario: Prepare with explicit focus scale ref

- **WHEN** the developer runs `FOCUS_SCALE_REF=5 make prepare` with other required env set
- **THEN** `/system/etc/model.properties` on the device MUST contain `focus_scale_ref=5`

#### Scenario: Prepare without FOCUS_SCALE_REF defaults to zero

- **WHEN** the developer runs `make prepare` with `MODEL` or `SN` set but `FOCUS_SCALE_REF` unset
- **THEN** the pushed `model.properties` MUST contain `focus_scale_ref=0`

#### Scenario: Prepare with negative focus scale ref

- **WHEN** the developer runs `FOCUS_SCALE_REF=-3 make prepare`
- **THEN** `/system/etc/model.properties` MUST contain `focus_scale_ref=-3`

#### Scenario: Invalid FOCUS_SCALE_REF rejected

- **WHEN** the developer runs `FOCUS_SCALE_REF=abc make prepare`
- **THEN** prepare MUST exit non-zero before modifying the device

### Requirement: Makefile documents FOCUS_SCALE_REF for prepare and emulator

The root `Makefile` help text SHALL document `FOCUS_SCALE_REF=<int>` for `make prepare` and `make emulator`, noting default `0`.

#### Scenario: make help lists focus scale ref

- **WHEN** the developer runs `make help` (or equivalent documented help target)
- **THEN** output MUST mention `FOCUS_SCALE_REF` alongside other `model.properties` env vars

### Requirement: Makefile documents demo alarm target

`make help` SHALL list the `alarm` target with the `CODE=` parameter, an example such as `make alarm CODE=C002`, and a note that demo alarms stay open until manually dismissed and are disabled on release-channel builds.

#### Scenario: Developer reads help for alarm demo

- **WHEN** the developer runs `make help`
- **THEN** the output SHALL include the `make alarm CODE=…` usage line and example alarm code

### Requirement: make install supports optional cloud VERSION install

The `make install` target SHALL accept optional `VERSION=x.y.z`. When `VERSION` is non-empty, install SHALL download the matching published zip from the public R2 `lws-app` path, extract the APK, run the cloud install pipeline (purge when downgrading, priv-app install, reboot, strict PM sync, verify), then launch. When `VERSION` is empty, install SHALL retain the existing local `TARGET_APK` behavior including optional streamed PM sync fallback.

#### Scenario: Cloud staging install

- **WHEN** the developer runs `make install VERSION=1.0.35` with adb device ready
- **THEN** the workflow SHALL install from `lws-app_v1.0.35-beta.zip` without requiring a local `make build`

#### Scenario: Cloud release install

- **WHEN** the developer runs `make install VERSION=1.0.17 RELEASE=1`
- **THEN** the workflow SHALL install from `lws-app_v1.0.17.zip`

#### Scenario: Local install unchanged

- **WHEN** the developer runs `make install` without `VERSION` after `make build`
- **THEN** the workflow SHALL install `TARGET_APK` as before cloud support existed

#### Scenario: Missing cloud version fails fast

- **WHEN** the developer runs `make install VERSION=9.9.99` and the zip does not exist
- **THEN** the command SHALL exit non-zero before modifying the device

### Requirement: Makefile documents cloud install VERSION and RELEASE

`make help` SHALL document `make install VERSION=x.y.z` for staging (default beta channel) and `RELEASE=1` for release channel cloud install, with at least one example of each.

#### Scenario: Help lists cloud install

- **WHEN** the developer runs `make help`
- **THEN** output SHALL mention `VERSION=` on `make install` and `RELEASE=1` for release channel

