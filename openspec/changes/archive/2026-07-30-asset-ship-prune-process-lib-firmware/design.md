## Context

Process-library default content today is checked in under `app/lws_hmi/assets/process-library/` as Excel + converted JSON + `manifest.json` (+ sidecars). `convert-process-library.py` overwrites a single library entry. Control-board firmware lives under `assets/firmware/control-board/` and is declared via parent `assets/firmware/` in `pubspec.yaml`, so every checked-in `.bin` is copied into the Flutter bundle. Runtime already knows how to pick newest process-library (semver + model) and newest firmware (HW/SW integers); packaging does not yet prune.

Operators want to drop new Excel / firmware files into git by hand, keep history in the repo, and have `make build-app` produce a lean ship tree—without network download as part of integrating the default process library.

## Goals / Non-Goals

**Goals:**

- Source-only process libraries at `assets/process-library/<model>/<version>.xlsx` — **many version files per model** coexist in git (same idea as multiple firmware bins); source dirs hold only `.xlsx` (no manifest/JSON/sidecars).
- Source-only (multi-version) control-board bins remain under `assets/firmware/control-board/`.
- Shared build-time ship-prune: among those coexisting sources, convert/copy **only newest per key** → stage into a generated Flutter asset tree consumed by `flutter assemble`.
- Default process library on device comes only from that ship tree (App upgrade / push), not from network download.
- Host `make upgrade-control-board` continues to read the **git source** firmware tree (all versions / override).
- Migrate existing Excel into `process-library/L1_Pro/1.0.4.xlsx`; ship as `.generated/process-library/L1_Pro/1.0.4.json`.

**Non-Goals:**

- Removing USB / MTP / `/userdata/ota/process-library` offline package import.
- Implementing or removing cloud `command.send_process_lib` (ops channel stays out of this change; it is not the default-library integration path).
- Changing SQLite process-library schema, engineer deriver, or Modbus firmware transfer protocol.
- Flutter-native asset tree-shaking (explicit staging instead).
- Product/APK/rootfs OTA for process libraries as a separate download channel.
- Multi-product Excel formats beyond the existing converter rules.

## Decisions

### 1. Source trees vs ship tree

**Choice:** Keep multi-version **sources** outside `pubspec` ship declarations. `make build-app` (and a shared prepare helper used by debug-app) writes a **gitignored** ship tree, e.g.:

```text
app/lws_hmi/assets/
  process-library/                 # SOURCE (not in pubspec)
    L1_Pro/
      1.0.4.xlsx
      v1.4.0.xlsx
  firmware/
    control-board/                   # SOURCE (not declared wholesale in pubspec)
      LSW01H1000S1013.bin
      LSW01H1000S1017.bin
  .generated/                        # SHIP (gitignored; declared in pubspec)
    process-library/
      manifest.json                  # generated at prepare time
      L1_Pro/
        1.0.4.json                   # mirrors source model/version names
    firmware/
      control-board/
        LSW01H1000S1017.bin          # newest SW per HW only
```

**Why:** Flutter ships everything listed under `pubspec` assets; there is no unused-asset tree-shake. Staging is the reliable prune. Generated ship assets must not be hand-edited.

**Alternatives considered:** Rewrite `AssetManifest` after assemble (fragile); list exact files in pubspec per release (error-prone); keep sources in pubspec and delete after assemble (race-prone / pollutes assemble inputs).

### 2. Process-library naming

**Choice:**

- Directory `<model>` = product.ini `MODEL` with each ASCII space replaced by `_` (example `"L1 Pro"` → `L1_Pro`). At convert time, map folder name back to `supported_models` by replacing `_` → space (single model entry; no `*` unless a dedicated convention is added later).
- File `<version>.xlsx` where the basename (minus `.xlsx`) is a **numeric** semantic version (`MAJOR.MINOR.PATCH` with optional fewer components), optionally prefixed with `v`/`V`. Strip the prefix for `library_version` and for newest-version comparison. **Reject** alpha/beta/prerelease suffixes (e.g. `1.0.4-beta` is invalid as a source basename).
- Reject non-`.xlsx` files in source dirs during prepare (fail or warn loudly; prefer fail on unexpected files so junk is not silent).

**Why:** Matches operator mental model (drop Excel per model/version); removes checked-in manifest as a second SoT.

### 3. Newest selection keys

**Choice:**

| Bundle | Key | Newest rule |
|--------|-----|-------------|
| Process library | model directory (`L1_Pro`) | highest semver among valid `<version>.xlsx` |
| Control-board firmware | hardware version (`H####`) | highest software version (`S####`) |

Ship one process JSON (+ one manifest listing all shipped libraries) covering every model that has at least one xlsx. Ship one firmware bin per HW present in the source tree.

**Why:** Aligns with runtime `_selectLibrary` / `BundledFirmwareAssets.selectLatestFileName`. Shipping only a global “max version” would break multi-model / multi-HW.

### 4. Generated process-library ship format

**Choice:** Keep runtime `ProcessLibraryImporter.importBundled()` contract: ship-only `manifest.json` + versioned JSON payloads with `content_sha256` / `library_version` / `supported_models` / `row_count`. Manifest exists **only** under `.generated/process-library/` (never in the Excel source tree).

**Why:** Minimizes Dart churn; USB/OTA packages already use the same shape. Conversion remains `scripts/convert-process-library.py` (extended for batch/model/version parsing) invoked by the prepare script.

**Alternatives considered:** Discover JSON without manifest at runtime (more Dart + weaker hash gate); ship xlsx and parse on device (rejected earlier in migration plan).

### 5. Prepare hook placement

**Choice:** Add `scripts/prepare-hmi-ship-assets.sh` (or equivalent function in `hmi-bundle-common.sh`) called at the start of `build-app` and `debug-app` / debug assemble paths before `flutter assemble`. Clean and regenerate `.generated/` each run. Document that host `flutter test` for asset-dependent cases should either mock `AssetBundle` or run prepare first; CI that builds the app already runs prepare via `build-app`.

**Why:** Single entry for both release and debug bundles; avoids stale ship trees.

### 6. Host firmware helper vs ship tree

**Choice:** `make upgrade-control-board` keeps scanning `app/lws_hmi/assets/firmware/control-board/` (source). It MUST NOT depend on `.generated/` existing.

**Why:** Operators may force an older bin via `FIRMWARE_BIN=` or pick newest from full history without building the App.

### 7. Network / default library

**Choice:** Spec and docs state that integrating and refreshing the **default** process library is App-bundle-only (prepare → build-app → push/upgrade). Offline USB/OTA import remains. Cloud process-lib commands are out of scope here and MUST NOT be required for default-library integration.

### 8. pubspec declarations

**Choice:** Remove `assets/process-library/` and do not declare `assets/process-library/` or the full firmware source tree for shipping. Declare:

- `assets/.generated/process-library/`
- `assets/.generated/firmware/` (or the control-board subdirectory)

Ensure `.gitignore` covers `app/lws_hmi/assets/.generated/`. Other existing assets unchanged.

## Risks / Trade-offs

- **[Risk] Host `flutter test` / IDE run without prepare** → empty or missing bundled library/firmware. **Mitigation:** prepare in build-app/debug-app; tests prefer mocked bundles; README note; optional make target `prepare-app-assets`.
- **[Risk] Semver vs `v`-prefix / prerelease ordering drift** between Python prepare and Dart importer. **Mitigation:** shared test vectors; strip `v` once; reuse the same numeric/prerelease compare rules as today’s importer.
- **[Risk] Model folder `Foo_Bar` → `Foo Bar` is lossy if a real MODEL contains underscores.** **Mitigation:** document space↔underscore only; open question if a product needs literal `_` in MODEL.
- **[Risk] Accidental commit of `.generated/`** → stale ship artifacts. **Mitigation:** gitignore + verify script / CI check that `.generated` is not tracked.
- **[Risk] Empty model dir or invalid xlsx fails release builds.** **Mitigation:** prepare fails closed with clear errors; at least one valid library required for products that expect bundled presets (or allow empty with explicit warning—prefer fail if `process-library/` exists but yields zero ship entries).
- **[Trade-off] Duplicate convert logic in batch prepare vs old single-file CLI.** Accept thin wrapper around existing converter to avoid two validators.

## Migration Plan

1. Add `process-library/L1_Pro/1.0.4.xlsx` from the prior Excel (numeric version only).
2. Implement prepare + pubspec/gitignore; wire into `build-app` / debug assemble.
3. Point Dart importer default `manifestAsset` at `assets/process-library/manifest.json` **as produced under the generated tree** (Flutter asset key remains `assets/process-library/...` if we stage with that logical prefix—see below).
4. Delete checked-in `assets/process-library/` generated JSON, manifest, `__source_filename.txt`, and old xlsx once prepare is green.
5. Update docs and OpenSpec archive on apply completion.

**Asset key note:** Stage files so Flutter asset keys stay `assets/process-library/...` and `assets/firmware/control-board/...` (copy into `.generated/` layout that mirrors those relative paths, or use a pubspec asset directory mapping). Prefer mirroring path suffixes so Dart constants need minimal change:

```text
assets/.generated/process-library/manifest.json
  → asset key assets/.generated/process-library/manifest.json
```

If Flutter requires the pubspec path to equal the on-disk path, either:

- declare `assets/.generated/process-library/` and update Dart prefixes to `assets/.generated/process-library/`, **or**
- stage into a non-ignored path that uses the historical names but is fully overwritten by prepare (still gitignored contents).

**Preferred:** update Dart to load from `assets/.generated/process-library/` and `assets/.generated/firmware/control-board/` for honesty, **or** keep historical asset keys by using pubspec:

```yaml
- assets/.generated/process-library/
- assets/.generated/firmware/control-board/
```

and set importer/`BundledFirmwareAssets` prefixes accordingly. Document the chosen keys in tasks.

**Rollback:** Revert change; restore previous `assets/process-library/` and firmware pubspec directory declaration from git history.

## Open Questions

1. Should prepare allow a model directory that ships `supported_models: ["*"]` (e.g. folder name `_common` or `ANY`), or only exact MODEL mapping?
2. If `process-library/` is empty, should `build-app` fail or succeed with no bundled library (Quick Mode empty)? Recommendation: succeed with warning only when explicitly opted in; default fail if the directory is missing entirely, warn if present but empty after filter.
3. Exact Flutter asset key strings (`.generated/...` vs historical `assets/process-library/...`) — resolve in implementation to whichever pubspec mapping is simplest on Flutter 3.24.4.
