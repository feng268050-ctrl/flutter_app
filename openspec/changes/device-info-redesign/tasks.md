## 1. Device Information regroup

- [ ] 1.1 Reorder `DeviceInformationTab` into four untitled `SettingsGroup`s: Identity (Model, SN), Versions, Storage placeholder, Accessory (Welding Gun SN, Focus Scale Reference)
- [ ] 1.2 Remove Kernel Version and Process Library Version rows from Device Information
- [ ] 1.3 Move Welding Gun SN out of Identity into the last (Accessory) group with Focus Scale Reference
- [ ] 1.4 Add Camera Version row to the Versions group; wire shared `CameraDeviceInfoCache` (do not show Camera Type)

## 2. Storage bar UI

- [ ] 2.1 Add Settings storage bar widget (segmented used mounts + available, human-readable used/free caption) using `SysInfoSnapshot.storage`
- [ ] 2.2 Bind Device Information storage group to `sysInfo.watch` storage list; soft-fail to `-` / empty bar when totals missing
- [ ] 2.3 Add l10n strings for storage labels / units (`en`, `zh`, `zh_TW` ARBs + `make l10n`)

## 3. System Upgrade version rows

- [ ] 3.1 On `SystemUpgradePage` check mode, show Kernel Version and Process Library Version near System Version (reuse existing SysInfo / ProcessLibrary sources)
- [ ] 3.2 Keep progress-only / apply UI unchanged (no requirement to show those rows during burn)

## 4. Verification

- [ ] 4.1 Update or add widget/unit tests for Device Info group membership / order and System Upgrade check-mode rows where practical
- [ ] 4.2 Run `flutter analyze` (and targeted tests) under `app/lws_hmi/`
- [ ] 4.3 Manual device check: Device Info order, Camera Version, storage bar with real `df`, System Upgrade shows Kernel + Process Library
