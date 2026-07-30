## 1. Source layout migration

- [x] 1.1 Create `app/lws_hmi/assets/process-library/L1_Pro/` and copy current Excel to `1.0.4.xlsx` (numeric version only; no alpha/beta suffix)
- [x] 1.2 Add `app/lws_hmi/assets/.generated/` to `.gitignore` and a short README under `process-library/` documenting multi-file `<model>/<version>.xlsx` naming (spaces→`_`, optional `v` prefix; keep old version files when adding new ones)
- [x] 1.3 Keep `assets/firmware/control-board/*.bin` as the multi-version **source** tree; stop declaring the wholesale source directory as the sole ship path in `pubspec.yaml` once generate staging exists

## 2. Prepare / ship-prune tooling

- [x] 2.1 Add `scripts/prepare-hmi-ship-assets.sh` (or `hmi-bundle-common.sh` helpers) that cleans and regenerates `assets/.generated/`
- [x] 2.2 Process-library prune: scan `process-library/<model>/*.xlsx`, normalize version (`v`/`V` strip), pick newest semver per model, invoke converter, write ship JSON + `manifest.json` under `.generated/process-library/`
- [x] 2.3 Firmware prune: scan source `firmware/control-board/LSW01H*.bin`, copy newest SW per HW into `.generated/firmware/control-board/`
- [x] 2.4 Extend `scripts/convert-process-library.py` as needed for batch/model/`supported_models` from directory name (`L1_Pro` → `L1 Pro`) without writing into the source tree
- [x] 2.5 Wire prepare into `make build-app` and debug assemble paths before `flutter assemble`; add a documented `make prepare-app-assets` (or equivalent) for host use
- [x] 2.6 Update `app/lws_hmi/pubspec.yaml` to declare only `.generated/process-library/` and `.generated/firmware/` (plus unchanged unrelated assets); remove old `assets/process-library/` and wholesale `assets/firmware/` ship declarations

## 3. App runtime path updates

- [x] 3.1 Point `ProcessLibraryImporter` default manifest/asset keys at the generated ship prefix chosen in design
- [x] 3.2 Point `BundledFirmwareAssets.assetPrefix` at the generated firmware ship prefix
- [x] 3.3 Confirm `make upgrade-control-board` still reads git source `assets/firmware/control-board/` (not `.generated/`)
- [x] 3.4 Update unit/widget tests that assumed checked-in `assets/process-library/manifest.json` / JSON (fixtures or prepare-before-test)

## 4. Cleanup and docs

- [x] 4.1 Remove obsolete checked-in `assets/process-library/` generated JSON, manifest, `__source_filename.txt`, and old xlsx once prepare + tests pass
- [x] 4.2 Update `docs/process-library-migration-plan.md`, control-board README, and AGENTS/README notes for the new source layout and prepare step
- [x] 4.3 Verify prepare fails closed on invalid xlsx / empty unexpected junk; smoke `make build-app` ship tree contains newest-only process JSON and firmware bins

## 5. Verification

- [x] 5.1 Run process-library and bundled-firmware related tests under `app/lws_hmi/`
- [x] 5.2 Run `flutter analyze` (pinned SDK) on touched Dart
- [x] 5.3 Confirm host helper + bundled Home path still documented; default library refresh does not require network download
