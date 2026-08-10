## MODIFIED Requirements

### Requirement: R2 artifact prefix derives from APP

The R2 directory (publish **artifact** segment) SHALL be derived from Make/env **`APP`**: replace underscores with hyphens (default `APP=lws_hmi` → artifact **`lws-hmi`**). Objects SHALL live under **`{artifact}/`** in the app bucket (`tar.gz`, `.sig`, + **`release.json`**). Archive basename SHALL be **`v{semver}.tar.gz`** (version segment only — MUST NOT prefix with `{artifact}_`, MUST NOT include `-beta` / `-alpha`).

`make publish` / `make publish-only` SHALL target HMI product apps (`APP` ending in `_hmi`). Publishing a non-HMI `APP` (e.g. `settings`) SHALL fail fast unless an explicitly documented override is used.

#### Scenario: Default APP maps to lws-hmi prefix

- **WHEN** the operator runs `make publish` without setting `APP`
- **THEN** upload paths use the `lws-hmi` artifact prefix (not `lws-app` and not `lws_hmi` with underscores)

#### Scenario: Alternate HMI APP maps prefix

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi` is a valid app
- **THEN** upload paths use the `cnc-hmi` artifact prefix
