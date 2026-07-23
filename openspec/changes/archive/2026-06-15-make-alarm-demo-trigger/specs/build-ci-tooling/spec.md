## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Makefile documents demo alarm target

`make help` SHALL list the `alarm` target with the `CODE=` parameter, an example such as `make alarm CODE=C002`, and a note that demo alarms stay open until manually dismissed and are disabled on release-channel builds.

#### Scenario: Developer reads help for alarm demo

- **WHEN** the developer runs `make help`
- **THEN** the output SHALL include the `make alarm CODE=…` usage line and example alarm code
