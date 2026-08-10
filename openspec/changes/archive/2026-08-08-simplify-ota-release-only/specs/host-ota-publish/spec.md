## MODIFIED Requirements

### Requirement: make publish uploads OTA tar.gz and channel manifest to R2

The repository SHALL provide **`make publish`** that (1) ensures a signed OTA `tar.gz` exists via **`make ota-package`** (or Make prerequisite equivalent) for the selected `APP`, and (2) uploads that archive, its detached `.sig`, and the channel manifest to the application R2 bucket under the publish artifact prefix derived from `APP`, updating **`release.json`** so devices can discover the package via the public CDN (same R2 keys as peripheral `release.json`). The repository SHALL also provide **`make publish-only`** that performs only the upload/manifest step against an already-built OTA `tar.gz` (+ `.sig`) and MUST fail if that archive or signature is missing.

Upload authentication SHALL resolve a Bearer token in this order: (1) **`PUBLISH_API_TOKEN`** when set (Worker **`STATIC_API_TOKENS`** member — preferred for presign), (2) **`CLOUD_ACCESS_TOKEN`** when set, (3) **`access_token`** from the **`make login`** credentials file (`output/cloud/credentials.json`, see **`make-login-register-device`** / `cloud_resolve_publish_token`). Values are loadable from repo-root **`.env`** via the same dotenv pattern as other Make targets, with a non-empty command-line/env value overriding `.env`. Tokens MUST NOT be committed to git.

API base URL SHALL be resolved via the same helper as **`make login`** / **`make register-device`**: **`cloud_api_base()`** in `scripts/cloud-credentials.sh`. The default when **`CLOUD_API_BASE`** is unset SHALL be the production cloud service **`https://api-prod.lasercyber.workers.dev`**. Operators MAY override with **`CLOUD_API_BASE`** (e.g. `https://api-test.lasercyber.workers.dev`) for non-production testing. Publish MUST NOT introduce a separate default host (e.g. a distinct `PUBLISH_BASE_URL` that defaults elsewhere).

#### Scenario: Default publish builds package then uploads release

- **WHEN** the operator runs `make publish` with default `APP` after images required by `ota-package` exist and signing is configured, and a publish token is available (`PUBLISH_API_TOKEN` or login credentials)
- **THEN** a signed OTA `tar.gz` is produced or refreshed via `ota-package`, uploaded under the `lws-hmi/` R2 prefix (with `.sig` per documented convention), and `lws-hmi/release.json` is updated with fields suitable for client download (`version`, `filename`, `published_at`, `url`)

#### Scenario: Default API base is production (same as login)

- **WHEN** the operator runs `make publish` or `make publish-only` without setting `CLOUD_API_BASE`
- **THEN** the host requests the R2 presigned URL from `https://api-prod.lasercyber.workers.dev` (same default as `make login` / `make register-device`)

#### Scenario: Explicit CLOUD_API_BASE override

- **WHEN** the operator sets `CLOUD_API_BASE=https://api-test.lasercyber.workers.dev` and runs `make publish-only`
- **THEN** the host requests the R2 presigned URL from that base instead of api-prod

#### Scenario: publish-only refuses missing archive

- **WHEN** the operator runs `make publish-only` and the documented OTA `tar.gz` path for the selected `APP` is absent
- **THEN** the command exits non-zero without calling the upload API

#### Scenario: Missing token refuses publish

- **WHEN** `PUBLISH_API_TOKEN`, `CLOUD_ACCESS_TOKEN`, and the login credentials file are all empty/missing after dotenv load and the operator runs `make publish` or `make publish-only`
- **THEN** the command exits non-zero before uploading
- **AND** the error SHALL mention `make login` or `PUBLISH_API_TOKEN`

### Requirement: Publish version is the HMI app version

Cloud publish versioning SHALL use the **selected HMI Flutter app version** only: parse `version:` from `app/<APP>/pubspec.yaml` (e.g. `app/lws_hmi/pubspec.yaml`), take the semver before any `+build` metadata, and use that as the channel manifest **`version`** field and archive basename (with a leading `v` on the filename only). The system MUST NOT invent a separate OS, kernel, rootfs, git-tag, or host `VERSION` file as the cloud OTA channel version. The system MUST NOT append prerelease suffixes such as **`-beta`** or **`-alpha`**. Device update checks that consume this manifest SHALL compare against the running HMI app version (same pubspec lineage).

#### Scenario: Manifest version matches lws_hmi pubspec

- **WHEN** `app/lws_hmi/pubspec.yaml` has `version: 1.0.38+1038` and the operator publishes with default `APP`
- **THEN** the channel manifest `version` is `1.0.38` (no `-beta` / `-alpha`) and MUST NOT use an unrelated firmware label

#### Scenario: Other HMI APP uses that app’s pubspec

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi/pubspec.yaml` has `version: 2.1.0+2100`
- **THEN** pack/manifest versioning is based on `2.1.0` from that app, not from `lws_hmi`

### Requirement: R2 artifact prefix derives from APP

The R2 directory (publish **artifact** segment) SHALL be derived from Make/env **`APP`**: replace underscores with hyphens (default `APP=lws_hmi` → artifact **`lws-hmi`**). Objects SHALL live under **`{artifact}/`** in the app bucket (`tar.gz`, `.sig`, + **`release.json`**). Archive basename SHALL be **`v{semver}.tar.gz`** (version segment only — MUST NOT prefix with `{artifact}_`, MUST NOT include `-beta` / `-alpha`).

`make publish` / `make publish-only` SHALL target HMI product apps (`APP` ending in `_hmi`). Publishing a non-HMI `APP` (e.g. `factory_test`) SHALL fail fast unless an explicitly documented override is used.

#### Scenario: Default APP maps to lws-hmi prefix

- **WHEN** the operator runs `make publish` without setting `APP`
- **THEN** upload paths use the `lws-hmi` artifact prefix (not `lws-app` and not `lws_hmi` with underscores)

#### Scenario: Alternate HMI APP maps prefix

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi` is a valid app
- **THEN** upload paths use the `cnc-hmi` artifact prefix

### Requirement: Host documents publish Make surface

Host docs (Makefile `help` and README Make-commands, plus AGENTS rebuild table as needed) SHALL document `make publish` / `publish-only`, `APP=`, and auth/env (`PUBLISH_API_TOKEN`, **`CLOUD_API_BASE`** defaulting to production api-prod like login/register-device, and `make login` fallback). Docs SHALL state that publish is **release-only** (`release.json`, no `staging.json`, no `RELEASE=1`, no `-beta`/`-alpha`), and that devices fetch manifests from **`https://cdn.lasercyber.com/{artifact}/release.json`**. Docs SHALL describe the **presigned-url + direct R2 PUT** flow (aligned with `lws-ui`), MUST NOT prescribe `PUT /upload/{artifact}/…` as the HMI publish path, and MUST state that channel manifests omit `sha512` because `.sig` covers integrity.

#### Scenario: Operator finds publish in help

- **WHEN** a developer runs `make help` or reads README Make-commands
- **THEN** `publish` / `publish-only` and release-only/`APP`/CDN check behavior are described without requiring reading script source

### Requirement: Preferred upload path is R2 presigned PUT via Python on production cloud API

The intended production upload path SHALL match **`lws-ui`** and SHALL use the **same cloud API origin** as **`make login`** / **`make register-device`**: for each object key, the host client SHALL call **`GET {cloud_api_base()}/v1/storage/r2/presigned-url`** with query parameters **`key`** and **`content_type`**, using **`Authorization: Bearer <token>`**, then **HTTP PUT** the object bytes to the returned **`upload_url`** with the matching Content-Type. When `CLOUD_API_BASE` is unset, that origin SHALL be **`https://api-prod.lasercyber.workers.dev`**. The client SHALL use the returned **`public_url`** when composing the channel manifest `url` (and when printing success URLs). The host SHALL implement this in a **Python** publish program (same shape as `lws-ui/scripts/publish_lws_app.py`). The path MUST NOT use **`PUT /upload/{artifact}/{archive-basename}`** as the production HMI publish mechanism.

#### Scenario: Successful presigned publish against production default

- **WHEN** `CLOUD_API_BASE` is unset, the production API issues presigned URLs for the archive, `.sig`, and channel manifest keys, and the host client PUTs each object successfully
- **THEN** R2 contains the archive and `.sig` under `{artifact}/` and **`release.json`**, and the client prints or logs the archive and manifest public URLs

#### Scenario: Presign request targets cloud_api_base

- **WHEN** the publish client requests upload credentials
- **THEN** the HTTP request URL host/path prefix is `{cloud_api_base()}/v1/storage/r2/presigned-url` (not a hardcoded alternate publish-only host)

## ADDED Requirements

### Requirement: Publish is release-only

`make publish` / `make publish-only` SHALL always write **`release.json`** and use the plain HMI pubspec semver (no `-beta` / `-alpha`). The host MUST NOT accept a **`RELEASE=`** channel toggle; if `RELEASE` is set in the environment, publish SHALL fail fast with a migration hint.

#### Scenario: Plain publish writes release.json

- **WHEN** the operator runs `make publish` and the HMI app pubspec semver is `1.0.38`
- **THEN** the uploaded object basename and manifest `version` use `1.0.38` without prerelease suffix and the written manifest key is `{artifact}/release.json`

#### Scenario: RELEASE env is rejected

- **WHEN** the operator runs `RELEASE=1 make publish` (or otherwise sets `RELEASE` in the environment)
- **THEN** the command exits non-zero before uploading
- **AND** the error SHALL state that publish is always `release.json`

## REMOVED Requirements

### Requirement: Publish channel follows RELEASE flag like lws-ui

**Reason:** System OTA is simplified to a single release channel on CDN; staging/`-beta` and `RELEASE=1` are retired.

**Migration:** Run plain `make publish` / `make publish-only`. Do not set `RELEASE`. Ensure CDN has current `{artifact}/release.json`.
