## 1. Device Information regroup

- [x] 1.1 Reorder `DeviceInformationTab` into four untitled `SettingsGroup`s: Identity (Model, SN), Versions, Storage placeholder, Accessory (Welding Gun SN, Focus Scale Reference)
- [x] 1.2 Remove Kernel Version and Process Library Version rows from Device Information
- [x] 1.3 Move Welding Gun SN out of Identity into the last (Accessory) group with Focus Scale Reference
- [x] 1.4 Add Camera Version row to the Versions group; wire shared `CameraDeviceInfoCache` (do not show Camera Type)

## 2. Storage bar UI

- [x] 2.1 Add Settings storage bar widget (segmented used mounts + available, human-readable used/free caption) using `SysInfoSnapshot.storage`
- [x] 2.2 Bind Device Information storage group to `sysInfo.watch` storage list; soft-fail to `-` / empty bar when totals missing
- [x] 2.3 Add l10n strings for storage labels / units (`en`, `zh`, `zh_TW` ARBs + `make l10n`)

## 3. System Upgrade version rows

- [x] 3.1 On `SystemUpgradePage` check mode, show Kernel Version and Process Library Version near System Version (reuse existing SysInfo / ProcessLibrary sources)
- [x] 3.2 Keep progress-only / apply UI unchanged (no requirement to show those rows during burn)

## 4. Verification

- [x] 4.1 Update or add widget/unit tests for Device Info group membership / order and System Upgrade check-mode rows where practical
- [x] 4.2 Run `flutter analyze` (and targeted tests) under `app/lws_hmi/`
- [x] 4.3 Manual device check: Device Info order, Camera Version, storage bar with real `df`, System Upgrade shows Kernel + Process Library
