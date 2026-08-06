## 1. Prerequisites

- [x] 1.1 Confirm `unified-ota-cyber-ota` has landed (or is mergeable) with a documented `make ota-package` `tar.gz` (+ `.sig`) path under `output/firmware/<APP>/`
- [x] 1.2 Record the exact archive path, pack-mode env (`OEM_ONLY`, etc.), and signing preconditions publish will inherit
- [x] 1.3 Confirm **production** cloud (`https://api-prod.lasercyber.workers.dev`, same default as `make login` / `register-device`) **`GET /v1/storage/r2/presigned-url`** accepts HMI keys under `{artifact}/` for `.tar.gz`, detached `.sig`, and channel JSON (extend sibling api-server allowlist if needed)

## 2. Host publish client (lws-hmi)

- [x] 2.1 Add Python publish script (patterned on `lws-ui/scripts/publish_lws_app.py`): map `APP` → artifact slug; read **HMI app** `app/<APP>/pubspec.yaml` version as sole cloud semver; apply `RELEASE=` channel rules; for archive, `.sig`, and channel manifest each call presign then HTTP PUT to R2
- [x] 2.2 Wire Makefile `publish` (depends on `ota-package`) and `publish-only`; rename/copy `tar.gz` (+ `.sig`) to agreed basename if needed; resolve Bearer via `cloud_resolve_publish_token` and API base via **`cloud_api_base()`** (default api-prod; same helpers as login / register-device; optional `CLOUD_API_BASE=` override only)
- [x] 2.3 Refuse non-`*_hmi` `APP` values with a clear error (unless documented override)
- [x] 2.4 Build channel manifest **without `sha512`** (`version`, `filename`, `published_at`, `url`); print archive and manifest `public_url`s on success; fail fast on HTTP errors

## 3. Docs and Make surface

- [x] 3.1 Update Makefile `help` for `publish` / `publish-only`, `RELEASE=1`, `APP=`, and publish env vars
- [x] 3.2 Update README Make-commands and AGENTS.md rebuild table for publish-related paths
- [x] 3.3 Cross-link `unified-ota-cyber-ota` / ota-package: upgrade and publish share the same `tar.gz`; document presign+direct-R2 flow (not `PUT /upload`), production default `CLOUD_API_BASE` shared with login/register-device, and that integrity is `.sig`, not manifest `sha512`

## 4. Verification

- [x] 4.1 Dry-run: `make ota-package` then `make publish-only` (or `make publish`) uploads under `lws-hmi/` and refreshes `staging.json`
- [x] 4.2 Confirm published `staging.json` (or `RELEASE=1` → `release.json`) has expected `version` / `filename` / `url` and **no** `sha512`; confirm sibling `.sig` object is reachable from the documented discovery rule
- [x] 4.3 Smoke `APP=<other_hmi> make publish-only` prefix mapping when a second HMI app exists (or document skip)

### Verification notes

- Archive path: `output/firmware/<APP>/ota-package.tar.gz` (+ `.sig`); `OEM_ONLY` / `OTA_SIGNING_KEY` / `REQUIRE_OTA_SIG` inherited from `ota-package` (`make publish` forces `REQUIRE_OTA_SIG=1`).
- Presign on api-prod accepts `lws-hmi/*.tar.gz`, `*.tar.gz.sig`, `staging.json` (no Worker allowlist change needed for static-token / JWT key path).
- Live `make publish-only` (2026-08-06): staging `v1.0.40-beta`; object basename `v{ver}[-beta].tar.gz` (no `lws-hmi_` prefix); `.sig` at `url + ".sig"` HTTP 200; manifest has no `sha512`.
- 4.3 skipped: only `app/lws_hmi` exists in-tree; non-`*_hmi` refuse + `PUBLISH_ARTIFACT=` documented.
