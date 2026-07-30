## 1. cyber_pm package

- [x] 1.1 Scaffold `packages/cyber_pm` (pubspec, analysis_options, barrel `lib/cyber_pm.dart`)
- [x] 1.2 Implement `RestartPolicy` (`none`, `onFailure` with delay / optional maxBurst)
- [x] 1.3 Implement `ProcessSupervisor` (start/stop/isRunning, log drain, injectable process factory + log sink)
- [x] 1.4 Add package unit tests; wire `cyber_pm` path dependency in `app/lws_hmi/pubspec.yaml`

## 2. App MediaMTX relay

- [x] 2.1 Add Dart `MediaMtxConfigWriter` writing `/run/hmi/mediamtx.yaml` (parity with former shell renderer)
- [x] 2.2 Rewrite `LinuxIpCameraMediaMtxRelay` to use `cyber_pm` + `/opt/hmi/bin/mediamtx` (no systemctl)
- [x] 2.3 Add/adjust App unit tests for config writer and relay with fake supervisor/process

## 3. Bundle packaging

- [x] 3.1 Extend `hmi-bundle-common` / `build-app` to install prebuilt mediamtx into `$DEST/bin/mediamtx` with `+x`
- [x] 3.2 Fail build-app when mediamtx prebuilt missing; stop `build-mediamtx` from syncing rootfs-overlay

## 4. Rootfs teardown and docs

- [x] 4.1 Remove overlay `usr/bin/mediamtx`, `mediamtx.service`, `render-mediamtx-config.sh`
- [x] 4.2 Drop defconfig `#include` of `lws_hmi_mediamtx`; update check-prebuilt / verify-rootfs / boot-verify / env-verify / post-hooks
- [x] 4.3 Update README / AGENTS / measure scripts for App-owned MediaMTX and `make logs GREP=mediamtx`

## 5. Verification

- [x] 5.1 Run analyze/tests for `cyber_pm` and `app/lws_hmi`
- [x] 5.2 Document rebuild: `make build-app` + `make push-app`; full OS purge needs `make build-rootfs` + `make upgrade`
