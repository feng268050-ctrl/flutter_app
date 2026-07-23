## ADDED Requirements

### Requirement: make version prints combined app version

The repository SHALL provide a root Makefile target `version` that prints exactly one line to stdout: `{versionName}+{versionCode}`, where both values are read from `app/build.gradle.kts` `defaultConfig`.

#### Scenario: Developer checks current version

- **WHEN** the developer runs `make version` from the repository root
- **THEN** stdout SHALL contain a single line matching `digit.digit.patch+build` using the current `versionName` and `versionCode` from Gradle

#### Scenario: Gradle file missing version fields

- **WHEN** `versionName` or `versionCode` cannot be parsed from `app/build.gradle.kts`
- **THEN** the command SHALL exit non-zero and print a clear error to stderr

### Requirement: make version-bump updates Gradle with validated VERSION

The repository SHALL provide a Makefile target `version-bump` that requires `VERSION=x.y.z+build`, validates the string, and writes `versionName = "x.y.z"` and `versionCode = build` (integer literal) into `app/build.gradle.kts` `defaultConfig`.

#### Scenario: Successful bump

- **WHEN** the developer runs `make version-bump VERSION=1.0.8+108`
- **THEN** `app/build.gradle.kts` SHALL set `versionName` to `1.0.8` and `versionCode` to `108`
- **AND** the command SHALL print the new combined version `1.0.8+108` on success

#### Scenario: Missing VERSION argument

- **WHEN** the developer runs `make version-bump` without `VERSION=…`
- **THEN** the command SHALL exit non-zero and instruct the user to pass `VERSION=x.y.z+build`

### Requirement: VERSION format enforces digit constraints

The `version-bump` target SHALL reject `VERSION` unless:

- major is one digit `0`–`9`;
- minor is one digit `0`–`9`;
- patch is an integer `0`–`100` (expressed as one to three decimal digits);
- build is a positive integer after `+` with no leading-zero-only form required beyond standard decimal parsing.

#### Scenario: Invalid major width

- **WHEN** `VERSION=10.0.8+108`
- **THEN** the command SHALL exit non-zero and report invalid version format

#### Scenario: Patch exceeds 100

- **WHEN** `VERSION=1.0.101+108`
- **THEN** the command SHALL exit non-zero and report patch must be 0–100

#### Scenario: Valid boundary patch

- **WHEN** `VERSION=1.9.100+1`
- **THEN** the bump SHALL succeed and persist `versionName` `1.9.100` and `versionCode` `1`

### Requirement: make help documents version targets

The `make help` output SHALL list `make version` and `make version-bump VERSION=x.y.z+build` with a short description matching the Flutter sibling workflow.

#### Scenario: Help includes version section

- **WHEN** the developer runs `make help`
- **THEN** help text SHALL mention both version targets and an example `VERSION=1.0.8+108`
