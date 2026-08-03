## 1. APP resolver

- [x] 1.1 Add `scripts/app-select.sh` (sourceable): default `APP=lws_hmi`, validate `app/$APP/pubspec.yaml`, export `APP_DIR`, `APP_OPT_NAME`, `OVERLAY_APP`, `DEVICE_APP`, `APP_IS_HMI` (`*_hmi` → `/opt/hmi`)
- [x] 1.2 Wire Makefile: export/pass `APP` into `build-app`, `push-app`, `build-rootfs` (and help text)

## 2. build-app

- [x] 2.1 Update `scripts/build-app.sh` to source app-select; install only to `OVERLAY_APP`; leave other non-HMI `/opt/*` trees intact
- [x] 2.2 Gate MediaMTX/ffmpeg/AI on `APP_IS_HMI`; run prepare-hmi-ship-assets when app has process-library/firmware sources

## 3. push-app

- [x] 3.1 Update `scripts/push-app.sh` to use selected overlay/device paths
- [x] 3.2 Keep HMI apply/restart for `*_hmi`; for other apps, deploy tree to `DEVICE_APP` without restarting `hmi.service`

## 4. build-rootfs ensure

- [x] 4.1 Add ensure helper that builds missing selected `APP` and, when `app/factory_test` exists, missing `factory_test`
- [x] 4.2 Invoke ensure from `make build-rootfs` before pack

## 5. Verify + docs

- [x] 5.1 Extend `scripts/verify-rootfs-overlay.sh` for optional `/opt/factory_test` checks when source exists
- [x] 5.2 Update README Make commands, `AGENTS.md` rebuild table, Makefile help for `APP=` / `_hmi` convention
