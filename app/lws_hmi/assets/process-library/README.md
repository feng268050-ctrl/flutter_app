# Process library (source Excel)

Drop versioned workbooks here. **Do not** add `manifest.json`, converted JSON, or sidecars.

## Layout

```text
process-library/<model>/<version>.xlsx
```

- `<model>`: Vendor Storage / product `MODEL` with spaces → underscores (`L1 Pro` → `L1_Pro`, `L1` → `L1`)
- `<version>`: numeric semantic version basename, optional leading `v` / `V`
  (`1.0.4.xlsx`, `v1.4.0.xlsx`). **No** alpha/beta/prerelease suffixes.

`L1/` and `L1_Pro/` are **separate** model trees (each ship entry has its own
`supported_models`). Content may be identical for a while; when recipes diverge,
edit only the model directory that should change.

## Multi-version

Keep **multiple** `.xlsx` files per model directory. Add a new version as a new file; leave older files in place unless you intentionally delete them.

`make prepare-app-assets` / `make build-app` converts **only the newest** semver per
model into the gitignored ship tree as:

```text
assets/.generated/process-library/<model>/<version>.json
assets/.generated/process-library/manifest.json
```

(example: `L1_Pro/1.0.4.json` — same model/version names as the source Excel).

Flutter packs only direct files under each `pubspec.yaml` asset directory, so
prepare also rewrites the `# BEGIN/END generated-ship-assets` block to list
each `<model>/` subdirectory (plus `firmware/control-board/`).
