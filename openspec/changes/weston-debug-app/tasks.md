## 1. Board launch (Weston debug)

- [ ] 1.1 Extend `hmi-launch.sh` Weston branch: on `mode=debug`, require debug-runtime + `kernel_blob.bin`, ensure `/opt/hmi/data/icudtl.dat`, start Weston as today, run `flutter-wayland-client` with `LD_LIBRARY_PATH` to `/var/lib/hmi/debug-runtime/<ver>/` (no silent AOT fallback)
- [ ] 1.2 Soften/remove Weston refuse in `debug-app-apply.sh`; keep atomic replace + JIT asset checks
- [ ] 1.3 Keep `debug-app-run.sh` VM Service wait; stack-neutral log wording if needed

## 2. Host deploy / docs / tests

- [ ] 2.1 Remove Weston hard-refuse in `scripts/debug-app-deploy.sh`; optionally log detected `display-stack`; still fail before apply if debug staging/runtime missing
- [ ] 2.2 Ensure debug staging/apply places or launch can supply `data/icudtl.dat` for eLinux (`build-debug-app.sh` and/or apply/launch)
- [ ] 2.3 Update `app/README.md` P1.5: `make debug-app` supported on default Weston; flutter-pi still supported; `push-app` restores release
- [ ] 2.4 Update `scripts/tests/debug-app.test.sh`: assert Weston path wiring / no hard Weston refuse; keep ChipID parse check

## 3. Device verification

- [ ] 3.1 On Weston board: `make debug-app` (or deploy+run) → UI up, VM Service line present, IDE attach/hot reload smoke
- [ ] 3.2 `make push-app` restores release AOT and `hmi.service` on Weston
- [ ] 3.3 If flutter-pi board available: confirm existing debug path still works (or note N/A)
