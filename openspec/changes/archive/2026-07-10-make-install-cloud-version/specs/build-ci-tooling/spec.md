## ADDED Requirements

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
