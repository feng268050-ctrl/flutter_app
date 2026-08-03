## 1. Path resolver

- [x] 1.1 Export `APP_FIRMWARE_DIR` / `APP_ROOTFS_IMG` from `app-select.sh` (after resolve)
- [x] 1.2 Update `factory-sku.sh` so `FACTORY_OUT_DIR` / `FACTORY_IMG` are under `output/firmware/<APP>/<sku>/`

## 2. Publish + consume rootfs

- [x] 2.1 `docker-export-artifacts.sh rootfs`: publish into `APP_FIRMWARE_DIR`; optional flat symlink for default APP
- [x] 2.2 `upgrade-remote.sh`: load rootfs from `APP_ROOTFS_IMG`; keep shared boot paths
- [x] 2.3 `build-img.sh`: stage APP rootfs into SDK firmware; write factory under APP/sku; refresh `update.img` symlink
- [x] 2.4 `flash-usb.sh` / Makefile: pass `APP`; default flash image uses APP-scoped factory
- [x] 2.5 Emulator build: copy device rootfs from `APP_ROOTFS_IMG`

## 3. Docs

- [x] 3.1 Makefile help, README Make commands, AGENTS rebuild/pipeline notes for APP-scoped rootfs/factory
