## ADDED Requirements

### Requirement: Host can print selected app version

The repository SHALL provide `make version` that prints the Flutter app version for the selected `APP` (default `lws_hmi`) as a single line `versionName+buildNumber` parsed from `app/<APP>/pubspec.yaml` `version:` (e.g. `1.0.40+10040`). The target MUST resolve the app via the same `APP=` rules as other multi-app Make targets and MUST fail if the app directory or pubspec version line is missing or unparsable.

#### Scenario: Default APP print

- **WHEN** the operator runs `make version` and `app/lws_hmi/pubspec.yaml` contains `version: 1.0.40+10040`
- **THEN** stdout is exactly `1.0.40+10040` (plus a trailing newline)

#### Scenario: Explicit APP print

- **WHEN** the operator runs `APP=factory_test make version` and that app’s pubspec has a valid `version:` line
- **THEN** the printed combined version is taken from `app/factory_test/pubspec.yaml`, not from `lws_hmi`

#### Scenario: Invalid APP fails

- **WHEN** the operator runs `APP=does_not_exist make version`
- **THEN** the command fails with a non-zero exit and an actionable error (missing pubspec / invalid APP)

### Requirement: Host can bump selected app version

The repository SHALL provide `make version-bump VERSION=<x.y.z>` (optional `+build`) that updates `app/<APP>/pubspec.yaml` for the selected `APP` (default `lws_hmi`). `VERSION` MUST be required; omitting it MUST fail. After a successful bump, `make version` for that `APP` MUST print the new combined version. When `app/<APP>/lib/app_version.dart` exists, the bump MUST also set `kSystemVersion` to the semver name and `kSystemVersionCode` to the integer build number so they match the pubspec.

#### Scenario: Bump writes pubspec

- **WHEN** the operator runs `make version-bump VERSION=1.0.40` with default `APP`
- **THEN** `app/lws_hmi/pubspec.yaml` contains `version: 1.0.40+10040` and the command prints `1.0.40+10040`

#### Scenario: Bump syncs app_version.dart when present

- **WHEN** `app/lws_hmi/lib/app_version.dart` exists and the operator bumps to `1.0.40`
- **THEN** `kSystemVersion` is `'1.0.40'` and `kSystemVersionCode` is `10040`

#### Scenario: Explicit build must match encoding

- **WHEN** the operator runs `make version-bump VERSION=1.0.40+99999`
- **THEN** the command fails without modifying files, because `99999` is not the encoded build for `1.0.40`

#### Scenario: Matching explicit build succeeds

- **WHEN** the operator runs `make version-bump VERSION=1.0.40+10040`
- **THEN** the bump succeeds the same as omitting `+10040`

### Requirement: Five-digit build number encoding with overflow errors

Build numbers SHALL be encoded as `major * 10000 + minor * 100 + patch` (example: version `1.0.40` → build `10040`). Allowed ranges SHALL be major `0–9`, minor `0–99`, patch `0–99`. A bump (or parse of `VERSION`) that would place any component outside its range MUST fail with a non-zero exit and MUST NOT write pubspec or Dart files. The host MUST NOT silently wrap or truncate overflowing fields.

#### Scenario: Canonical encode

- **WHEN** version name `1.0.40` is bumped or encoded
- **THEN** the build number is `10040`

#### Scenario: Minor uses two digits in the code

- **WHEN** version name `1.12.3` is bumped
- **THEN** the build number is `11203` (`1*10000 + 12*100 + 3`)

#### Scenario: Patch overflow fails

- **WHEN** the operator runs `make version-bump VERSION=1.0.100`
- **THEN** the command fails with an error indicating patch exceeds `99`, and files are unchanged

#### Scenario: Minor overflow fails

- **WHEN** the operator runs `make version-bump VERSION=1.100.0`
- **THEN** the command fails with an error indicating minor exceeds `99`, and files are unchanged

#### Scenario: Major overflow fails

- **WHEN** the operator runs `make version-bump VERSION=10.0.0`
- **THEN** the command fails with an error indicating major exceeds `9`, and files are unchanged

### Requirement: Version targets are documented for operators

`make help`, README Make commands, and the AGENTS.md rebuild guidance SHALL document `make version` and `make version-bump` (including `APP=` and `VERSION=`), and SHALL state that these are host-only operations (no firmware rebuild required solely for a version bump).

#### Scenario: help lists version targets

- **WHEN** the operator runs `make help`
- **THEN** the output mentions `make version` and `make version-bump` with `VERSION=` / `APP=` usage

### Requirement: lws_hmi migrates to 1.0.40 with five-digit build

As part of adopting the five-digit encoding, `app/lws_hmi` SHALL ship `version: 1.0.40+10040` in `pubspec.yaml` and matching `kSystemVersion` / `kSystemVersionCode` in `lib/app_version.dart`, replacing the prior `1.0.38+1038` four-digit lineage.

#### Scenario: Current product version is 1.0.40+10040

- **WHEN** an operator inspects `app/lws_hmi/pubspec.yaml` and `lib/app_version.dart` after this change
- **THEN** pubspec is `1.0.40+10040`, `kSystemVersion` is `1.0.40`, and `kSystemVersionCode` is `10040`
