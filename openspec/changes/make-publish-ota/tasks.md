## 1. Prerequisites

- [ ] 1.1 Confirm `unified-ota-cyber-ota` has landed (or is mergeable) with a documented `make ota-package` `tar.gz` (+ `.sig`) path under `output/firmware/<APP>/`
- [ ] 1.2 Record the exact archive path, pack-mode env (`OEM_ONLY`, etc.), and signing preconditions publish will inherit
- [ ] 1.3 Confirm sibling api-server change **`hmi-ota-static-upload`** accepts **`.tar.gz`** (+ `.sig`) (or use documented interim bridge only if agreed)

## 2. Host publish client (lws-hmi)

- [ ] 2.1 Add publish script that maps `APP` → artifact slug, reads **HMI app** `app/<APP>/pubspec.yaml` version as the sole cloud semver source, applies `RELEASE=` channel rules, and uploads via `PUT /upload/...` per api-server contract
- [ ] 2.2 Wire Makefile `publish` (depends on `ota-package`) and `publish-only`; rename/copy `tar.gz` (+ `.sig`) to server basename if needed; resolve Bearer via `scripts/cloud-credentials.sh` `cloud_resolve_publish_token` (`PUBLISH_API_TOKEN` → login credentials / `CLOUD_ACCESS_TOKEN`; base URL `CLOUD_API_BASE`)
- [ ] 2.3 Refuse non-`*_hmi` `APP` values with a clear error (unless documented override)
- [ ] 2.4 Print `artifact_url` and `manifest_url` on success; fail fast on HTTP/ApiResult errors

## 3. Docs and Make surface

- [ ] 3.1 Update Makefile `help` for `publish` / `publish-only`, `RELEASE=1`, `APP=`, and publish env vars
- [ ] 3.2 Update README Make-commands and AGENTS.md rebuild table for publish-related paths
- [ ] 3.3 Cross-link `unified-ota-cyber-ota` / ota-package: upgrade and publish share the same `tar.gz`; point Worker gaps to api-server **`hmi-ota-static-upload`**

## 4. Verification

- [ ] 4.1 Dry-run: `make ota-package` then `make publish-only` (or `make publish`) uploads under `lws-hmi/` and refreshes `staging.json`
- [ ] 4.2 Confirm `GET /view/lws-hmi/staging.json` (or `RELEASE=1` → `release.json`) returns expected `version` / `sha512` / `url`
- [ ] 4.3 Smoke `APP=<other_hmi> make publish-only` prefix mapping when a second HMI app exists (or document skip)
