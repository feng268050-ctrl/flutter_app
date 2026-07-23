## MODIFIED Requirements

### Requirement: OTA manifest is fetched from lws-app view

The App OTA client SHALL fetch its version descriptor from the **in-memory pinned Worker API base** (the same origin used for other Worker HTTPS traffic after `DeviceApiOriginProber` succeeds), by joining the path `/view/lws-app/<json_file>` under that base using the project’s standard base+path join rules (`DeviceApiOriginConfig` / `joinUnderBase` semantics). The `<json_file>` value SHALL be `staging.json` or `release.json` under the **same** Makefile/environment selection rules as bundled library builds (default staging for non-release descriptor builds).

The client SHALL NOT use a hardcoded `https://api-prod.lasercyber.workers.dev/...` origin for manifest fetch when a pinned base is available.

#### Scenario: Descriptor fetch uses configured channel

- **WHEN** the OTA check runs for a build configured for production descriptors
- **THEN** the client SHALL request `release.json` under the `lws-app` view path on the pinned base

#### Scenario: Descriptor fetch uses staging by default for test builds

- **WHEN** the OTA check runs for a build whose manifest file is `staging.json`
- **THEN** the client SHALL request `staging.json` under the `lws-app` view path on the pinned base

#### Scenario: Manifest URL preserves a path-prefixed pinned base

- **WHEN** the pinned API base is `http://47.86.53.176:8080/prod` (no trailing slash) and the manifest file is `staging.json`
- **THEN** the manifest request URL MUST be `http://47.86.53.176:8080/prod/view/lws-app/staging.json` (and MUST NOT be `http://47.86.53.176:8080/view/lws-app/staging.json`)

#### Scenario: No hardcoded prod Workers host when pin is absent

- **WHEN** the OTA check runs and the pinned API base is not yet set (`getPinnedBase()` is null)
- **THEN** the client MUST NOT issue the manifest request using `https://api-prod.lasercyber.workers.dev` as a silent default solely because the pin is missing

#### Scenario: Manifest on canonical Workers host without path prefix

- **WHEN** the pinned API base is `https://api-prod.lasercyber.workers.dev` and the manifest file is `release.json`
- **THEN** the manifest request URL MUST be `https://api-prod.lasercyber.workers.dev/view/lws-app/release.json`
