## Context

`hmi_bundle_install_release` already strips `kernel_blob.bin` from the host overlay, and `apply-overlay` rsyncs `/opt/hmi` with `--delete`. Buildroot’s `SYSTEM_RSYNC` for `BR2_ROOTFS_OVERLAY` does **not** delete orphans in incremental `target/`. The board `post-build.sh` already purges similar leftovers (`libflutter_engine.so` / `icudtl.dat` under `/opt/hmi`, `flutter-pi`).

## Goals / Non-Goals

**Goals:**

- Idempotently remove JIT snapshot files from product `/opt/hmi` during every rootfs post-build.
- Fail `verify-rootfs-overlay` if they remain.

**Non-Goals:**

- Changing Buildroot upstream overlay rsync to use `--delete`.
- Altering `make debug-app` / debug staging (those still need `kernel_blob.bin`).
- Moving GStreamer or other media stacks.

## Decisions

### D1 — Purge in `post-build.sh` next to existing `/opt/hmi` engine/icu `rm`

Same class of problem (overlay apply is additive on `target/`). Keep the list next to the existing App-bundle purge so future readers see one place for “release `/opt/hmi` must not contain …”.

**Alternatives:** only extend `purge-retired-rootfs-artifacts.sh` (naming is about renamed systemd units — poorer fit); only rely on verify (does not shrink `rootfs.img`).

### D2 — Remove three named blobs

- `kernel_blob.bin` — Dart JIT kernel (~50 MiB in observed orphan)
- `isolate_snapshot_data` / `vm_snapshot_data` — engine JIT snapshots also observed as orphans alongside it

Do **not** delete directories or other assets.

### D3 — Verify gate mirrors post-build

Extend the existing `/opt/hmi (Flutter app bundle — no engine)` section so CI/`build-rootfs` verification catches regressions without depending on log grepping.

## Risks / Trade-offs

- **[Risk]** Someone expects JIT inside baked rootfs for debug → Mitigation: debug path stays `make debug-app` + staging push; product rootfs remains release AOT only (already documented).
- **[Risk]** Filename drift in future Flutter layouts → Mitigation: verify fails loudly; adjust the short list.

## Migration Plan

1. Land post-build + verify.
2. `make apply-overlay` then `make build-rootfs` once to clear existing SDK `target/` orphans.
3. No board flash required solely for this unless validating image size; next normal rootfs upgrade picks it up.

## Open Questions

- None.
