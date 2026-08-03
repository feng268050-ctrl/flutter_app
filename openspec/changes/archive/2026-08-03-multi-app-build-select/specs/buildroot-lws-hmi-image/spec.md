## ADDED Requirements

### Requirement: Rootfs verify optional factory_test app tree

When repo `app/factory_test/pubspec.yaml` exists, `scripts/verify-rootfs-overlay.sh` after `make build-rootfs` SHALL require staging `target/opt/factory_test/lib/libapp.so` and `target/opt/factory_test/data/flutter_assets` release assets. That tree MUST NOT contain `libflutter_engine.so` or `icudtl.dat` under the app prefix, and MUST NOT contain Flutter JIT blobs (`kernel_blob.bin`, `isolate_snapshot_data`, `vm_snapshot_data`) under `data/flutter_assets/`. When `app/factory_test` is absent, verification MUST NOT require `/opt/factory_test`.

#### Scenario: factory_test present in source and rootfs

- **WHEN** `app/factory_test/pubspec.yaml` exists and `verify-rootfs-overlay.sh` inspects a staging `target/` after `make build-rootfs`
- **THEN** verification MUST PASS only if `/opt/factory_test` has release AOT layout without engine/ICU/JIT orphans

#### Scenario: factory_test source absent

- **WHEN** `app/factory_test` does not exist
- **THEN** verification MUST NOT fail solely due to missing `/opt/factory_test`
