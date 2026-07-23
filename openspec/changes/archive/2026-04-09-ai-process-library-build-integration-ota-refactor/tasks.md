## 1. Build pipeline and manifests

- [x] 1.0 Add a **SemVer 2.0–compliant** JVM dependency (e.g. `semver4j` or `java-semver`) in Gradle; centralize version parse/compare in a small helper used by startup import and OTA (**no** hand-rolled version ordering).
- [x] 1.1 Add Makefile (or extend existing) so a variable such as `RELEASE=1` maps to `release.json`, default maps to `staging.json`, and pass the chosen `json_file` name into Gradle or a download script.
- [x] 1.2 Implement a Gradle task or standalone script invoked by `make build` that fetches `https://api-prod.lasercyber.workers.dev/view/ai-library/<json_file>` and `.../process-library/<json_file>`, parses required fields `url`, `filename`, `sha512`, and `version` (ignore optional `published_at` unless needed for logging).
- [x] 1.3 Download each `url` to `app/src/main/assets/<artifact>/<filename>`, compute SHA-512 on bytes, normalize digest comparison with manifest, and fail the build on mismatch or network/parse errors.
- [x] 1.4 Wire the task as a dependency of appropriate `assemble*` / bundle tasks so release APKs always contain fresh verified assets.

## 2. Repository hygiene

- [x] 2.1 Add `assets/ai-library/` and `assets/process-library/` (or exact module-relative paths) to `.gitignore`; ensure empty dirs or `.gitkeep` strategy does not fight Android merge (document one-line developer note if needed).
- [x] 2.2 Verify a clean clone + `make build` (default) produces both artifacts under assets before `assembleDebug`. _(Use `SKIP_BUNDLED_FETCH=1 make build` when Workers returns 404 until `ai-library` / `process-library` manifests exist.)_

## 3. Startup bundled-library import

- [x] 3.1 Implement **substring extraction** from filenames only (regex/template); pass substrings to the SemVer library for parse/compare (prerelease and optional `v` handled by the library), e.g. `工艺库_v1.0.0-beta.xlsx` and AI zip with the same shape.
- [x] 3.2 Use `t_device_info.processLibVersion` and `t_device_info.AIVersion` as the single source of truth for installed library versions; if either value is empty/null, treat as "not imported yet".
- [x] 3.3 On cold start (or agreed lifecycle), compare bundled asset version vs `t_device_info` using **only** the SemVer library; when import is needed, run importer directly from temporary files under cache (no persistent xlsx/zip retention).
- [x] 3.4 For `process-library`, invoke the same code path as pre-refactor OTA process-library upgrade (refactor into shared method if needed); add logging for skip vs import vs failure.
- [x] 3.5 For `ai-library`, invoke the existing unpack/install path previously used when OTA delivered the archive; ensure idempotency when versions match and delete legacy versions/directories before writing new content.
- [x] 3.6 Persist `processLibVersion` / `AIVersion` in `t_device_info` as core semver (`MAJOR.MINOR.PATCH`) by stripping prerelease/build suffixes (e.g. `1.0.0-beta` -> `1.0.0`) for display and dual-track marker isolation.
- [x] 3.7 Normalize runtime installed-version comparison and AI unpack directory naming to core semver (`MAJOR.MINOR.PATCH`) so JNI lookup path and `t_device_info.AIVersion` remain consistent.

## 4. OTA refactor (lws-app)

- [x] 4.1 Point OTA version check to `https://api-prod.lasercyber.workers.dev/view/lws-app/<json_file>` using the same Makefile/environment channel as library builds.
- [x] 4.2 Replace local vs remote version comparison with **SemVer library** ordering against manifest `version` and local `versionName`; gate download strictly on “remote greater”.
- [x] 4.3 Download zip from `url`, extract, locate inner APK and bin per agreed layout; hand off to existing firmware-update and APK install routines without behavioral regression aside from semver.
- [x] 4.4 Remove or disable AI-library and process-library download/import branches from the OTA flow so only startup handles those artifacts.

## 5. Specs and verification

- [x] 5.1 Manually verify staging vs release manifest selection with two local builds (default vs `RELEASE=1` or chosen flag).
- [x] 5.2 Current project has superseding bundled-library bootstrap coverage and later RKNN/runtime investigation; this archived change no longer needs the original semver-bump device matrix as an open task.
- [x] 5.3 Run existing tests / lint touched modules; fix regressions from extracted OTA helpers if any signatures changed.
