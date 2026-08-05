## ADDED Requirements

### Requirement: make publish uploads OTA zip and channel manifest to R2

The repository SHALL provide **`make publish`** that (1) ensures an OTA package zip exists via **`make ota-package`** (or Make prerequisite equivalent) for the selected `APP`, and (2) uploads that zip to the application R2 bucket under the publish artifact prefix derived from `APP`, updating the channel manifest (**`staging.json`** or **`release.json`**) so devices can discover the package the same way `lws-ui` discovers `lws-app` builds. The repository SHALL also provide **`make publish-only`** that performs only the upload/manifest step against an already-built OTA zip and MUST fail if that zip is missing.

Upload authentication SHALL use a static publish token from the environment (e.g. **`PUBLISH_API_TOKEN`**), loadable from repo-root **`.env`** via the same dotenv pattern as other Make targets, with a non-empty command-line/env value overriding `.env`. Tokens MUST NOT be committed to git.

#### Scenario: Default publish builds package then uploads staging

- **WHEN** the operator runs `make publish` with default `APP` after signed images required by `ota-package` exist, and `PUBLISH_API_TOKEN` is set
- **THEN** an OTA zip is produced or refreshed via `ota-package`, uploaded under the `lws-hmi/` R2 prefix, and `lws-hmi/staging.json` is updated (default channel) with fields suitable for client download (`version`, `filename`, `published_at`, `sha512`, `url`)

#### Scenario: publish-only refuses missing zip

- **WHEN** the operator runs `make publish-only` and the documented OTA zip path for the selected `APP` is absent
- **THEN** the command exits non-zero without calling the upload API

#### Scenario: Missing token refuses publish

- **WHEN** `PUBLISH_API_TOKEN` is empty after dotenv load and the operator runs `make publish` or `make publish-only`
- **THEN** the command exits non-zero before uploading

### Requirement: Publish version is the HMI app version

Cloud publish versioning SHALL use the **selected HMI Flutter app version** only: parse `version:` from `app/<APP>/pubspec.yaml` (e.g. `app/lws_hmi/pubspec.yaml`), take the semver before any `+build` metadata, and use that as the numeric/base version for the zip basename and channel manifest **`version`** field. The system MUST NOT invent a separate OS, kernel, rootfs, git-tag, or host `VERSION` file as the cloud OTA channel version. Device update checks that consume this manifest SHALL compare against the running HMI app version (same pubspec lineage).

#### Scenario: Manifest version matches lws_hmi pubspec

- **WHEN** `app/lws_hmi/pubspec.yaml` has `version: 1.0.38+1038` and the operator publishes with default `APP`
- **THEN** the channel manifest base version is `1.0.38` (with channel suffix rules below) and MUST NOT use an unrelated firmware label

#### Scenario: Other HMI APP uses that app’s pubspec

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi/pubspec.yaml` has `version: 2.1.0+2100`
- **THEN** pack/manifest versioning is based on `2.1.0` from that app, not from `lws_hmi`

### Requirement: Publish channel follows RELEASE flag like lws-ui

Default publish (no `RELEASE=1`) SHALL treat the package as prerelease: the HMI app semver gains a **`-beta`** suffix and the channel manifest file SHALL be **`staging.json`**. When **`RELEASE=1`**, the pack version SHALL be that same HMI app semver without `-beta`/`-alpha`, and the channel manifest file SHALL be **`release.json`**.

#### Scenario: Staging channel default

- **WHEN** the operator runs `make publish` without `RELEASE=1` and the HMI app pubspec semver is `1.0.38`
- **THEN** the uploaded object basename and manifest `version` reflect a prerelease such as `…1.0.38-beta` and the written manifest key is `{artifact}/staging.json`

#### Scenario: Release channel

- **WHEN** the operator runs `RELEASE=1 make publish` with the same HMI app pubspec semver
- **THEN** the basename/version omit `-beta` and the written manifest key is `{artifact}/release.json`

### Requirement: R2 artifact prefix derives from APP

The R2 directory (static-upload **artifact** segment) SHALL be derived from Make/env **`APP`**: replace underscores with hyphens (default `APP=lws_hmi` → artifact **`lws-hmi`**). Objects SHALL live under **`{artifact}/`** in the app bucket (zip + `staging.json` / `release.json`). Zip basename SHALL match the api-server basename rules for that artifact (documented as `{artifact}_v{semver}[-beta].zip` or equivalent agreed normalization).

`make publish` / `make publish-only` SHALL target HMI product apps (`APP` ending in `_hmi`). Publishing a non-HMI `APP` (e.g. `factory_test`) SHALL fail fast unless an explicitly documented override is used.

#### Scenario: Default APP maps to lws-hmi prefix

- **WHEN** the operator runs `make publish` without setting `APP`
- **THEN** upload paths use the `lws-hmi` artifact prefix (not `lws-app` and not `lws_hmi` with underscores)

#### Scenario: Alternate HMI APP maps prefix

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi` is a valid app
- **THEN** upload paths use the `cnc-hmi` artifact prefix

### Requirement: Cloud manifest schema matches static library OTA descriptors

The channel manifest written for publish (by the upload API or an equivalent client write approved in design) SHALL be a JSON object including at least **`version`** (string), **`filename`** (string), **`published_at`** (UTC ISO 8601 with `Z`), **`sha512`** (hex), and **`url`** (HTTPS URL of the uploaded OTA zip). This cloud manifest describes the downloadable zip only; trust to write partitions remains the per-image Ed25519 signatures inside the OTA zip per `unified-ota-cyber-ota` / `ota-image-signing`.

#### Scenario: Manifest points at zip URL

- **WHEN** publish completes successfully
- **THEN** the channel manifest `url` equals the public HTTPS URL of the uploaded OTA zip under `{artifact}/`

### Requirement: Host documents publish Make surface

Host docs (Makefile `help` and README Make-commands, plus AGENTS rebuild table as needed) SHALL document `make publish` / `publish-only`, `APP=`, `RELEASE=1`, and required env (`PUBLISH_API_TOKEN`, API base URL). Docs SHALL point to sibling api-server OpenSpec **`hmi-ota-static-upload`** for Worker artifact / basename / view rules, and MUST NOT duplicate that Worker design in this repository.

#### Scenario: Operator finds publish in help

- **WHEN** a developer runs `make help` or reads README Make-commands
- **THEN** `publish` / `publish-only` and channel/`APP` behavior are described without requiring reading script source

### Requirement: Preferred upload path is static library PUT

The intended production upload path SHALL be **`PUT /upload/{artifact}/{zip-basename}`** with **`Authorization: Bearer <STATIC_API_TOKENS member>`**, expecting **ApiResult** success data with **`artifact_url`** and **`manifest_url`**, per api-server **`hmi-ota-static-upload`** / `static-library-manifest`. A temporary presigned PUT of zip + client-written manifest MAY be used only as a bridge while that Worker change lands, and MUST still produce the same R2 key layout and manifest field set.

#### Scenario: Successful PUT-shaped publish

- **WHEN** api-server accepts the artifact and the host publish client uploads a correctly named zip with a valid static token
- **THEN** R2 contains the zip under `{artifact}/` and the appropriate `staging.json` or `release.json`, and the client prints or logs `artifact_url` and `manifest_url`
