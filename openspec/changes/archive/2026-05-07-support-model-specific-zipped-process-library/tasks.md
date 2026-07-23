## 1. Build Pipeline Updates

- [x] 1.1 Update `make build` library-fetch step to accept `process-library` `.xlsx/.zip` artifacts and keep AI artifact behavior unchanged.
- [x] 1.2 Implement suffix branch in build: `.xlsx` direct copy to `assets/process-library/`, `.zip` extraction to the same directory (xlsx-only, flattened).
- [x] 1.3 Add pre-extract cleanup for stale files in `assets/process-library/` and ensure path remains gitignored.
- [x] 1.4 Extend build verification logs/checks to confirm expected model xlsx files exist after extraction.

## 2. Startup Import Selection

- [x] 2.1 Implement a model normalization helper that removes `LaserCyber` prefix, trims whitespace, and performs case-insensitive matching preparation.
- [x] 2.2 Implement process-library selector with source-shape branch: single xlsx direct import; multiple xlsx use `<normalized-model>.xlsx` match with deterministic fallback.
- [x] 2.3 Update `BundledLibraryBootstrap` process-library flow to route through the selector while preserving current importer invocation.
- [x] 2.4 Preserve bundled process-library version comparison semantics by sourcing version from package metadata/filename, not per-model xlsx names.

## 3. Diagnostics and Safety

- [x] 3.1 Add warning logs for model-miss fallback including raw model, normalized model, and fallback filename.
- [x] 3.2 Ensure startup import still updates `DeviceInfo.processLibVersion` only after successful import using core semver format.
- [x] 3.3 Verify fallback behavior does not break canonical importer parity (default/quick replacement and DB write path).

## 4. Tests and Validation

- [x] 4.1 Add unit tests for model normalization and filename matching (`LaserCyber` prefix, casing, whitespace variants).
- [x] 4.2 Add unit/integration tests for selector behavior: exact match, no match fallback, deterministic ordering.
- [x] 4.3 Add compatibility test for legacy single-xlsx path to ensure import still works unchanged.
- [x] 4.4 Add build-side test/script check using sample zip (`L1.xlsx`, `L1 Pro.xlsx`) to verify extraction layout under assets.
- [x] 4.5 Run relevant startup/import tests and manual smoke checks for both single-xlsx and multi-model zip paths.
