## MODIFIED Requirements

### Requirement: Publish version is the OS Version

Cloud **whole-device / system** publish versioning SHALL use the product **OS Version** only: read the OS Version SoT SemVer (e.g. `1.0.0`) and use that as the channel manifest **`version`** field and archive basename (with a leading `v` on the filename only). The system MUST NOT use the Flutter HMI `pubspec.yaml` as the whole-device cloud OTA channel version. The system MUST NOT invent kernel, git-tag, or ad-hoc host labels as the channel version. The system MUST NOT append prerelease suffixes such as **`-beta`** or **`-alpha`**. Device update checks that consume **`{artifact}/release.json`** SHALL compare against the running **OS Version**. Independent HMI app publishes use **`{artifact}/app/release.json`** per `host-app-publish` (out of scope for this requirement’s channel).

#### Scenario: Manifest version matches OS Version stamp

- **WHEN** the OS Version SoT is `1.0.0` and the operator publishes with default `APP` artifact prefix
- **THEN** the channel manifest `version` is `1.0.0` (no `-beta` / `-alpha`)
- **AND** MUST NOT use the Flutter HMI pubspec semver as that manifest version

#### Scenario: HMI pubspec divergence does not change system channel

- **WHEN** HMI pubspec is `1.0.41` and OS Version is `1.0.0`
- **THEN** `make publish` system channel versioning remains based on `1.0.0`

### Requirement: Publish is release-only

`make publish` / `make publish-only` SHALL always write **`release.json`** and use the plain **OS Version** SemVer (no `-beta` / `-alpha`). The host MUST NOT accept a **`RELEASE=`** channel toggle; if `RELEASE` is set in the environment, publish SHALL fail fast with a migration hint.

#### Scenario: Plain publish writes release.json

- **WHEN** the operator runs `make publish` and the OS Version is `1.0.0`
- **THEN** the uploaded object basename and manifest `version` use `1.0.0` without prerelease suffix and the written manifest key is `{artifact}/release.json`

#### Scenario: RELEASE env is rejected

- **WHEN** the operator runs `RELEASE=1 make publish` (or otherwise sets `RELEASE` in the environment)
- **THEN** the command exits non-zero before uploading
- **AND** the error SHALL state that publish is always `release.json`
