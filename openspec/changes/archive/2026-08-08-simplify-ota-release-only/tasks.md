## 1. Host publish release-only

- [x] 1.1 Update `scripts/publish-ota.sh` to always use `release.json` and plain pubspec semver (no `-beta`); fail fast with a migration hint if `RELEASE` is set
- [x] 1.2 Tighten `scripts/publish_ota.py` manifest choices / help so system publish is release-only (align with peripheral publish)
- [x] 1.3 Update Makefile `help` for `publish` / `publish-only` (drop `RELEASE=1` / staging wording)

## 2. App system OTA URL

- [x] 2.1 Change `OtaManifestUrl.resolve` / `resolveView` to always select `release.json` regardless of cloud environment tier
- [x] 2.2 Update `app/lws_hmi/test/ota_manifest_url_test.dart` for release-only URLs on test/dev/prod tiers

## 3. cyber_ota examples / tests

- [x] 3.1 Update `packages/cyber_ota` tests that treat `staging.json` / `*-beta` as the canonical publish shape to use release-shaped versions (keep optional legacy prerelease compare coverage if useful)

## 4. Docs

- [x] 4.1 Update `docs/make-commands.md`, README Make-commands publish section, and `AGENTS.md` publish notes: release-only, no staging/`RELEASE`/`-beta`/`-alpha`
- [x] 4.2 Remove leftover “system OTA still has staging” wording anywhere it contradicts this change (e.g. peripheral OTA docs if still present)

## 5. Verification

- [x] 5.1 Run App OTA URL unit tests and `cyber_ota` unit tests affected by the example updates
- [x] 5.2 Smoke: `make publish-only` dry-run / help path shows release-only; confirm `RELEASE=1` fails with clear message (no upload)
