## Why

Process-library and control-board firmware both need a clear “many versions in git, one (per key) in the shipped App” pipeline. Today the process library still ships checked-in JSON/manifest/xlsx under `assets/process-library/`, and control-board bins under `assets/firmware/control-board/` are copied wholesale into the Flutter bundle. Operators should drop new Excel/firmware files into the repo by hand; `make build-app` should convert and prune so devices never carry historical payloads or depend on network download for the default library.

## What Changes

- **BREAKING (process-library source layout):** Replace `app/lws_hmi/assets/process-library/` (manifest + generated JSON + xlsx + sidecar files) with a source-only tree `app/lws_hmi/assets/process-library/<model>/<version>.xlsx`.
  - `<model>` is the product `MODEL` with spaces turned into underscores (e.g. `"L1 Pro"` → `L1_Pro`).
  - `<version>` is a numeric semantic version basename, with or without a leading `v` / `V` (e.g. `1.0.4.xlsx`, `v1.4.0.xlsx`). **No** alpha/beta/prerelease suffixes.
  - **Multi-version, multi-file:** each model directory MAY contain many `.xlsx` files at once (one file per version). Operators add a new version file alongside older ones; they do not replace a single shared workbook. Source dirs contain **only** those `.xlsx` files (no `manifest.json`, no pre-generated JSON, no `__source_filename.txt`).
- **Build-time process-library ship:** `make build-app` (via shared HMI bundle helpers) scans all versioned xlsx under each model, converts **only the newest semver per model** to JSON, builds a ship-only manifest, and stages that into Flutter assets. All historical xlsx stay in git; only the newest per model is shipped.
- **Default library updates without network:** The App’s built-in process library comes only from this ship staging. Network download is not part of integrating or refreshing the default library (USB/OTA offline package import and optional cloud ops commands remain separate channels).
- **Control-board firmware prune:** Keep multiple `LSW01H####S####.bin` files under `assets/firmware/control-board/` in git; at `build-app` time stage **only the newest software version per hardware version** into the Flutter asset bundle. Runtime discovery continues to pick newest matching HW from whatever is shipped.
- Shared **asset ship-prune** helper used by both pipelines (select latest by key, stage into a build-time assets tree, point `flutter assemble` at that tree or an equivalent filtered asset root).
- Update docs (`docs/process-library-migration-plan.md`, control-board README, AGENTS/README rebuild notes as needed) and App importer asset paths to consume the generated ship layout.

## Capabilities

### New Capabilities

- `asset-ship-prune`: Build-time pipeline that stages a filtered Flutter asset tree for versioned bundles (process libraries and control-board firmware): multi-version sources in git, ship only the newest entry per selection key.
- `process-library-source-layout`: Source-of-truth layout and naming for checked-in process-library Excel (`process-library/<model>/<version>.xlsx`), conversion rules, and ship-only JSON/manifest generation during `build-app`.

### Modified Capabilities

- `startup-bundled-firmware-upgrade`: Packaging SHALL ship only the newest control-board `.bin` per hardware version from `assets/firmware/control-board/`, while git MAY retain multiple versions; runtime discovery semantics stay newest-matching-HW.

## Impact

- `scripts/convert-process-library.py`, `scripts/hmi-bundle-common.sh`, `scripts/build-app.sh` (or equivalent): convert + prune + stage before `flutter assemble`.
- `app/lws_hmi/pubspec.yaml` assets: stop declaring the raw multi-version source trees as shipped assets; declare/use the build-generated ship tree (or filtered staging path).
- `app/lws_hmi/lib/features/process_library/**` importer paths and tests expecting `assets/process-library/manifest.json` / checked-in JSON.
- `app/lws_hmi/lib/features/bundled_firmware/**` and `scripts/upgrade-control-board.sh` (host helper still reads **git** source tree, not the pruned ship tree).
- Existing `assets/process-library/` contents migrate into `assets/process-library/L1_Pro/` and generated ship outputs; USB/OTA package import format unchanged unless noted in design.
- No change to SQLite process-library DB schema or Modbus control-board transfer protocol.
