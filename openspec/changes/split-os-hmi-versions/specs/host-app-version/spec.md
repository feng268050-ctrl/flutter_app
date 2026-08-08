## MODIFIED Requirements

### Requirement: Host can print selected app version

The repository SHALL provide `make version` that prints a product version as a single line. **By default** (no `APP=`), it SHALL print the **OS Version** SemVer from the OS Version SoT file (e.g. `1.0.0`). When **`APP=<id>`** is set, it SHALL print the Flutter app combined `versionName+buildNumber` from `app/<APP>/pubspec.yaml` (e.g. `1.0.41+10041`), resolving the app via the same `APP=` rules as other multi-app Make targets. The host MUST NOT introduce an `HMI=` alias or special `APP=HMI` token for version tooling. The target MUST fail if the selected SoT file or pubspec version line is missing or unparsable.

#### Scenario: Default prints OS Version

- **WHEN** the operator runs `make version` with no `APP=` and the OS Version SoT is `1.0.0`
- **THEN** stdout is exactly `1.0.0` (plus a trailing newline)
- **AND** MUST NOT print the Flutter pubspec combined version

#### Scenario: APP selects Flutter app version

- **WHEN** the operator runs `APP=lws_hmi make version` and `app/lws_hmi/pubspec.yaml` contains `version: 1.0.41+10041`
- **THEN** stdout is exactly `1.0.41+10041`

#### Scenario: Invalid APP fails

- **WHEN** the operator runs `APP=does_not_exist make version`
- **THEN** the command fails with a non-zero exit and an actionable error

### Requirement: Host can bump selected app version

The repository SHALL provide `make version-bump VERSION=<x.y.z>` (optional `+build` for Flutter apps) that updates the **default OS Version SoT** when no `APP=` is set, or updates `app/<APP>/pubspec.yaml` when `APP=` is set. `VERSION` MUST be required; omitting it MUST fail. After a successful OS bump, `make version` (default) MUST print the new OS SemVer. After a successful Flutter bump, `APP=<id> make version` MUST print the new combined version. When bumping a Flutter app and `app/<APP>/lib/app_version.dart` exists, the bump MUST set **`kHmiVersion`** to the semver name and **`kHmiVersionCode`** to the integer build number so they match the pubspec (replacing former `kSystemVersion` / `kSystemVersionCode` names). The host MUST NOT introduce an `HMI=` alias for bumps.

#### Scenario: Default bump writes OS Version

- **WHEN** the operator runs `make version-bump VERSION=1.0.1` with no `APP=`
- **THEN** the OS Version SoT becomes `1.0.1` and `make version` prints `1.0.1`
- **AND** Flutter pubspec files are unchanged

#### Scenario: APP bump writes pubspec

- **WHEN** the operator runs `APP=lws_hmi make version-bump VERSION=1.0.42`
- **THEN** `app/lws_hmi/pubspec.yaml` contains `version: 1.0.42+10042` and the command prints `1.0.42+10042`

#### Scenario: Bump syncs kHmiVersion when present

- **WHEN** `app/lws_hmi/lib/app_version.dart` exists and the operator bumps with `APP=lws_hmi` to `1.0.42`
- **THEN** `kHmiVersion` is `'1.0.42'` and `kHmiVersionCode` is `10042`

#### Scenario: Explicit build must match encoding

- **WHEN** the operator runs `APP=lws_hmi make version-bump VERSION=1.0.40+99999`
- **THEN** the command fails without modifying files, because `99999` is not the encoded build for `1.0.40`

### Requirement: Version targets are documented for operators

`make help`, README Make commands, and the AGENTS.md rebuild guidance SHALL document `make version` and `make version-bump`, including that **default targets OS Version**, that **`APP=`** targets Flutter app version, and that these are host-only operations (no firmware rebuild required solely for a version bump). Docs SHALL state the initial OS Version is **1.0.0**. Docs MUST NOT document an `HMI=` version alias.

#### Scenario: help lists version targets with OS default

- **WHEN** the operator runs `make help`
- **THEN** the output mentions `make version` and `make version-bump` with OS-default vs `APP=` usage

## REMOVED Requirements

### Requirement: lws_hmi migrates to 1.0.40 with five-digit build

**Reason**: One-time adoption of five-digit encoding is complete; product versioning is now split into OS Version + HMI Version.
**Migration**: Use default `make version` / `version-bump` for OS; `APP=lws_hmi make version` / `version-bump` for Flutter app pubspec / `kHmiVersion`.
