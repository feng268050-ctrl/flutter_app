## MODIFIED Requirements

### Requirement: Cloud channel manifest accepts publish url field

`cyber_ota` SHALL parse whole-device **cloud channel** manifests as used by `make publish` / `host-ota-publish`: a JSON object with at least `version` (string) and an archive location. The archive location SHALL be taken from **`package_url`** when that field is a non-empty string; otherwise from **`url`** when that field is a non-empty string. Missing both SHALL be a parse error. Optional `sig_url` (or equivalent) SHALL select the detached signature URL; when absent, the resolved signature URL SHALL default to the archive URL with `.sig` appended. The package MUST NOT require `sha512` in the channel manifest. Channel `url` / `package_url` alone MUST NOT authorize partition writes; CloudIngress MUST still Ed25519-verify using the detached `.sig` before extract-and-apply. Host publish SHALL emit release-shaped versions (no `-beta` / `-alpha`); the parser MAY still accept legacy prerelease version strings if present in a fetched document.

#### Scenario: Published release.json with url parses

- **WHEN** `OtaManifest.fromJson` receives `{"version":"1.0.41","filename":"v1.0.41.tar.gz","published_at":"…Z","url":"https://cdn.lasercyber.com/lws-hmi/v1.0.41.tar.gz"}` with no `package_url`
- **THEN** the manifest’s package URL equals that `url` value
- **AND** the resolved signature URL equals that `url` with `.sig` appended

#### Scenario: package_url still accepted

- **WHEN** `OtaManifest.fromJson` receives a non-empty `package_url` (with or without `url`)
- **THEN** the package URL is taken from `package_url`

#### Scenario: Neither url nor package_url fails

- **WHEN** the JSON has `version` but neither `url` nor `package_url` is a non-empty string
- **THEN** parsing fails without starting a download or partition write
