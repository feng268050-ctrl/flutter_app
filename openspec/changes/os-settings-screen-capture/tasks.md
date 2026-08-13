## 1. App wiring

- [x] 1.1 Add `cyber_capture` path dependency to `app/os_settings/pubspec.yaml`
- [x] 1.2 Start/dispose `CaptureCommandWatcher` in `OsSettingsApp` (same paths as HMI)
- [x] 1.3 Document in `packages/cyber_capture/README.md` that OS Settings is a supported consumer

## 2. Spec / docs

- [x] 2.1 Sync delta into `openspec/specs/hmi-screen-capture/spec.md` when archiving (or apply now if landing together)
- [x] 2.2 Note in `docs/make-commands.md` (screenshot/record-screen) that either HMI or OS Settings seat works when that App is foreground

## 3. Verify

- [ ] 3.1 `APP=os_settings make build-app` / `push-app`; with Settings seat active, smoke `make screenshot` (and optional short `make record-screen`)
