## 1. Build integration

- 1.1 Add `app/src/main/assets/firmware/` to `.gitignore` (alongside existing ai-library / process-library entries)
- 1.2 Add Gradle task `bundleFirmwareAssets`: scan repo-root `firmware/` for `LSW01H####S####.bin`, warn and skip when none, when multiple select latest by SW (tie HW) and copy into `assets/firmware/`
- 1.3 Wire `preBuild` to depend on `bundleFirmwareAssets` (parallel to `fetchBundledLibraries`)
- 1.4 Align `Makefile` `FIRMWARE_BIN` with `firmware/` single source (auto-pick sole bin or document explicit path); verify `make pack` and APK bundle use same file

## 2. Runtime bootstrap core

- 2.1 Create `BundledFirmwareBootstrap` with `checkAndPromptIfNeeded(MainActivity)`: require valid `DeviceStatus` in cache; no-op when Modbus unavailable
- 2.2 Implement asset discovery: list `assets/firmware/`, validate single `LSW01H####S####.bin`, copy to `cacheDir/bundled-firmware-import.bin` before upgrade
- 2.3 Implement version gate using `UpgradeFileReaderUtils` HW/SW integers vs `DeviceStatus`; skip on HW mismatch or SW not greater
- 2.4 Invoke `BinUtil.binFileConvert(tempFile)` only after user confirms dialog; delete temp file on terminal success/failure

## 3. Home-screen dialog and safety

- 3.1 Add confirmation dialog on `MainActivity` only (power / do-not-operate copy aligned with OTA); confirm → upgrade, dismiss → no upgrade for that action
- 3.2 Re-prompt on subsequent `MainActivity` `onResume` while upgrade candidate remains valid (no silent/auto path)
- 3.3 Create `FirmwareUpgradeCoordinator` mutex: block bundled start when OTA `upStatus` or active controller upgrade; expose busy flag for OTA path

## 4. Event handling and persistence

- 4.1 Register home-scoped or Application-level `EventBus` subscriber (`MAIN_ORDERED`) for bundled path: handle `UPGRADE_ING`, `UPGRADE_SUCCESS`, `UPGRADE_FAIL`, `606` skip
- 4.2 On success, update `DeviceInfo.firmwareVersion` via `DeviceInfoViewModel` / DAO (mirror `UpgradeActivity.controllerBardUpgradeResult`)
- 4.3 On emulator / Modbus unavailable, apply same skip/degrade as OTA (`isProbablyEmulator` pattern); no blocking error on home screen
- 4.4 Show lightweight status feedback during bundled upgrade on home screen; do not launch full `UpgradeActivity`

## 5. Wiring and OTA coexistence

- 5.1 Wire `BundledFirmwareBootstrap.checkAndPromptIfNeeded` from `MainActivity.onResume` (not from `LaserApplication` or `BundledLibraryBootstrap`)
- 5.2 Ensure `UpgradeActivity` / OTA path consults `FirmwareUpgradeCoordinator` before starting firmware upgrade
- 5.3 Update `docs/ota-upgrade-flow.md` with home-screen bundled-firmware parallel delivery note

## 6. Verification

- 6.1 Unit test: firmware filename version parsing and compare gate (HW match, SW newer/same/older)
- 6.2 Manual checklist: open home → dialog → confirm → firmware version updated; dismiss → no upgrade; leave home and return → dialog again if still outdated; non-home screens never prompt; emulator skip (verified manually)
- 6.3 CI: `make build` produces `assets/firmware/*.bin` with the selected latest firmware; verify supports multiple source bins (`scripts/ci/verify-bundled-firmware-assets.sh` + `verify_staging_build` in `.gitlab-ci.yml`)