# make-install-cloud-version Specification

## Purpose
TBD - created by archiving change make-install-cloud-version. Update Purpose after archive.
## Requirements
### Requirement: Cloud package fetch resolves channel from CLI RELEASE only

The cloud install fetch script SHALL resolve staging vs release zip names from the make command line only: when `RELEASE=1` is passed to `make install`, the zip MUST be `lws-app_v{x.y.z}.zip`; otherwise MUST be `lws-app_v{x.y.z}-beta.zip`. A `.env` file containing `RELEASE=1` MUST NOT change the channel unless `RELEASE=1` also appears on the make command line for that invocation.

#### Scenario: Staging channel without CLI RELEASE

- **WHEN** the developer runs `make install VERSION=1.0.36` without `RELEASE=1` on the command line
- **THEN** fetch SHALL request `lws-app_v1.0.36-beta.zip` from the public R2 base URL

#### Scenario: Release channel with CLI RELEASE

- **WHEN** the developer runs `make install VERSION=1.0.17 RELEASE=1`
- **THEN** fetch SHALL request `lws-app_v1.0.17.zip`

#### Scenario: Channel conflict rejected

- **WHEN** the developer runs `make install VERSION=1.0.17-beta RELEASE=1`
- **THEN** fetch SHALL exit non-zero with a clear channel conflict error

#### Scenario: env RELEASE alone does not select release zip

- **WHEN** `.env` contains `RELEASE=1` but the command is `make install VERSION=1.0.36` without CLI `RELEASE=1`
- **THEN** fetch SHALL still use the staging beta zip name

### Requirement: Cloud package download validates archive integrity

The fetch script SHALL download to a `.part` file, atomically rename on success, run zip integrity validation (`unzip -t` or equivalent), and MUST NOT treat HEAD `Content-Length` alone as sufficient to skip re-download. Corrupt or incomplete artifacts MUST be deleted and the command MUST exit non-zero.

#### Scenario: Successful download and zip test

- **WHEN** the remote zip exists and download completes
- **THEN** the script SHALL pass zip integrity check before extraction

#### Scenario: Corrupt cached zip

- **WHEN** a cached zip fails integrity check
- **THEN** the script SHALL remove the corrupt file, re-download or fail, and exit non-zero if validation still fails

### Requirement: Cloud package extraction dynamically selects the APK entry

The fetch script SHALL NOT assume a fixed inner APK filename. It SHALL list zip entries, select exactly one `.apk` (or apply documented priority when multiple), extract it, and validate with `aapt dump badging` (readable `packageName` and `versionCode`).

#### Scenario: Single apk in zip

- **WHEN** the zip contains one `.apk` entry
- **THEN** that entry SHALL be extracted and validated

#### Scenario: No apk in zip

- **WHEN** the zip contains no `.apk` entries
- **THEN** the script SHALL exit non-zero

### Requirement: Downgrade purge cleans PackageManager state and package_cache

When the target APK `versionCode` is strictly less than the installed `versionCode`, purge scripts SHALL run before priv-app replace and again after successful strict PM sync. Each purge SHALL: force-stop the app; `pm uninstall-system-updates`; `pm clear`; purge `package_cache` entries for the package; and verify `pm path` is empty or points at `/system/priv-app/LwsUI/LwsUI.apk`. The scripts MUST NOT `rm -rf` under `/data/app/` for the package.

#### Scenario: Downgrade before install

- **WHEN** cloud install targets a lower `versionCode` than installed
- **THEN** pre-install purge SHALL run and SHALL fail if `pm path` still references `/data/app/`

#### Scenario: Downgrade after PM sync

- **WHEN** downgrade install completes strict PM sync successfully
- **THEN** post-install purge SHALL run `package_cache` cleanup and `pm clear` again before verify

#### Scenario: Upgrade or same version skips downgrade purge

- **WHEN** target `versionCode` is greater than or equal to installed
- **THEN** downgrade-specific purge steps MAY be skipped

### Requirement: Cloud install uses strict PackageManager sync

When `INSTALL_STRICT=1` is set (cloud `VERSION=` path), `sync-pm-after-priv-app-install.sh` SHALL run `pm install -r -d` on the device priv-app path and MUST NOT fall back to streamed `adb install` on failure.

#### Scenario: Strict PM sync success

- **WHEN** device-path `pm install` succeeds under `INSTALL_STRICT=1`
- **THEN** the script SHALL exit zero

#### Scenario: Strict PM sync failure

- **WHEN** device-path `pm install` fails under `INSTALL_STRICT=1`
- **THEN** the script SHALL exit non-zero without streamed adb install

### Requirement: Cloud install verifies version and priv-app path before launch

`verify-priv-app-install.sh` SHALL compare installed `versionCode` and `versionName` to the target APK, require `pm path` to include `/system/priv-app/LwsUI/LwsUI.apk`, forbid `/data/app/` in `pm path`, and confirm the on-device APK file exists. Cloud install MUST NOT launch the app if verify fails.

#### Scenario: Verify passes

- **WHEN** install and PM sync complete and device state matches the target APK
- **THEN** verify SHALL exit zero and install MAY proceed to launch

#### Scenario: Verify fails version mismatch

- **WHEN** `dumpsys package` reports a different `versionCode` than the target APK
- **THEN** verify SHALL exit non-zero and launch SHALL NOT run

#### Scenario: Verify fails data app path

- **WHEN** `pm path` includes `/data/app/`
- **THEN** verify SHALL exit non-zero

### Requirement: Optional manifest sha512 for latest cloud version

When the requested version matches the current `staging.json` or `release.json` latest entry (per CLI channel), fetch MAY verify the downloaded zip against manifest `sha512`. Historical versions without manifest entries SHALL rely on zip and APK structural validation only.

#### Scenario: Latest staging version sha512 match

- **WHEN** `make install VERSION=` matches latest staging manifest version and sha512 is present
- **THEN** fetch SHALL verify zip bytes against sha512 before extraction

