## 1. Prerequisites

- [ ] 1.1 Confirm `unified-ota-cyber-ota` has landed (or is mergeable) with a documented `make ota-package` zip path under `output/firmware/<APP>/`
- [ ] 1.2 Record the exact zip path, pack-mode env (`OEM_ONLY`, etc.), and signing preconditions publish will inherit

## 2. api-server (sibling repo OpenSpec)

- [ ] 2.1 In `../api-server`, open an OpenSpec change to extend static library upload: add artifact(s) for HMI OTA (`lws-hmi`, and APP-derived `*-hmi` slugs as designed)
- [ ] 2.2 Specify basename rules `{artifact}_[vV]?{semver}(-alpha|-beta)?.zip`, staging/release manifest write, `PUT /upload/{artifact}/*`, and `GET /view/{artifact}/{staging|release}.json`
- [ ] 2.3 Implement registry + parser + tests + CLIENT-CURL (or shared static-library docs); deploy/verify Worker accepts a sample zip
- [ ] 2.4 If Worker body size cannot hold OTA zips, extend the api-server change with presigned zip upload + authenticated manifest finalize (same R2 key layout)

## 3. Host publish client (lws-hmi)

- [ ] 3.1 Add publish script (Python or shell) that maps `APP` → artifact slug, reads **HMI app** `app/<APP>/pubspec.yaml` version as the sole cloud semver source, applies `RELEASE=` channel rules, and uploads via `PUT /upload/...` (or interim presigned bridge)
- [ ] 3.2 Wire Makefile `publish` (depends on `ota-package`) and `publish-only`; rename/copy zip to server basename if needed; require `PUBLISH_API_TOKEN` / base URL from env + `.env`
- [ ] 3.3 Refuse non-`*_hmi` `APP` values with a clear error (unless documented override)
- [ ] 3.4 Print `artifact_url` and `manifest_url` (or equivalent) on success; fail fast on HTTP/ApiResult errors

## 4. Docs and Make surface

- [ ] 4.1 Update Makefile `help` for `publish` / `publish-only`, `RELEASE=1`, `APP=`, and publish env vars
- [ ] 4.2 Update README Make-commands and AGENTS.md rebuild table for publish-related paths
- [ ] 4.3 Cross-link `unified-ota-cyber-ota` / ota-package docs: upgrade and publish share the same zip

## 5. Verification

- [ ] 5.1 Dry-run against staging API: `make ota-package` then `make publish-only` (or `make publish`) uploads under `lws-hmi/` and refreshes `staging.json`
- [ ] 5.2 Confirm `GET /view/lws-hmi/staging.json` (or release with `RELEASE=1`) returns expected `version` / `sha512` / `url` and the zip downloads
- [ ] 5.3 Smoke `APP=<other_hmi> make publish-only` prefix mapping when a second HMI app exists (or document skip if none)
