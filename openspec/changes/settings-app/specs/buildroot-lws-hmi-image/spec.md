## REMOVED Requirements

### Requirement: Rootfs verify optional factory_test app tree

**Reason**: Second rootfs App slot is the platform Settings app, not Factory Test.
**Migration**: Use requirement “Rootfs verify optional settings app tree”.

## ADDED Requirements

### Requirement: Rootfs verify optional settings app tree

When repo `app/settings/pubspec.yaml` exists, `scripts/verify-rootfs-overlay.sh` after `make build-rootfs` SHALL require staging `target/opt/settings/lib/libapp.so` and `target/opt/settings/data/flutter_assets` release assets. That tree MUST NOT contain `libflutter_engine.so` or `icudtl.dat` under the app prefix, and MUST NOT contain Flutter JIT blobs (`kernel_blob.bin`, `isolate_snapshot_data`, `vm_snapshot_data`) under `data/flutter_assets/`. When `app/settings` is absent, verification MUST NOT require `/opt/settings`.

#### Scenario: settings present in source and rootfs

- **WHEN** `app/settings/pubspec.yaml` exists and `verify-rootfs-overlay.sh` inspects a staging `target/` after `make build-rootfs`
- **THEN** verification MUST PASS only if `/opt/settings` has release AOT layout without engine/ICU/JIT orphans

#### Scenario: settings source absent

- **WHEN** `app/settings` does not exist
- **THEN** verification MUST NOT fail solely due to missing `/opt/settings`
