## 0. 删除历史遗留

- [x] 0.1 Delete `UploadVideoInput.java` and remove unused `LogTAGConstant.UploadVideoInput` if unreferenced
- [x] 0.2 Remove video-title `MaterialDialog` block from `DevActivity.uploadVideo`
- [x] 0.3 Delete `TimePickerDialog.java` and clean `MainActivity` dead code (import, field, commented show block)
- [x] 0.4 Delete legacy parameter import: `BaseDialog.java`, `ParameterProcessFragment.java`, `ParameterProcessAdapter.java`, `ParameterProcessItem.java`, layouts (`dialog_base`, `fragment_parameter_process`, `layout_drop_down_parameter_process`, `parameter_process_data_item`), and `EngineerModeActivity.parameterImport` + related imports

## 1. Shared infrastructure

- [x] 1.1 Add `frosted_glass_body_text_input.xml` and `FrostedGlassTextInputDialog` wrapper
- [x] 1.2 Add `frosted_glass_body_wifi_password.xml` and `FrostedGlassWifiPasswordDialog` wrapper
- [x] 1.3 Add frosted-glass body layouts for date, time, and timezone pickers
- [x] 1.4 Add `frosted_glass_body_status.xml` (icon + message + optional SeekBar + confirm) and internal helper used by `showStatusDialog`
- [x] 1.5 Add upload-progress frosted-glass wrapper (SeekBar + cancel) for `VideoUploadProgressDialog`

## 2. Global status dialog (D3 + D5)

- [x] 2.1 Migrate `GlobalDialogUtil.showStatusDialog` modes 0/1/2 to FrostedGlass status body
- [x] 2.2 Migrate mode 3 blocking firmware progress + `updateFirmwareUpgradeProgress` to same FrostedGlass status body
- [x] 2.3 Verify call sites: `DeviceInformationFragment`, `WarnLogFragment`, `DashboardFragment`, `UpgradeActivity`, `BundledFirmwareBootstrap`, `OSSCredentialProviderManger`
- [x] 2.4 Remove `dialog_global` dependency from `initDialog` / `createDialogWithLayout` status path after migration

## 3. GlobalDialogUtil simple prompts (C1–C7)

- [x] 3.1 Migrate `showWifiInitializationDialog` to `FrostedGlassDialog`
- [x] 3.2 Migrate `showForcedDisconnectDialog` and `showRemoteLockDialog` to `FrostedGlassDialog`
- [x] 3.3 Migrate `showSelectAppEnvDialog` to `FrostedGlassDialog` with RadioGroup custom body
- [x] 3.4 Migrate `showBindDeviceDialog` and `showDeviceRegistrationDialog` to `FrostedGlassDialog`
- [x] 3.5 Migrate WiFi forget confirm in `WifiDetailsActivity` to `FrostedGlassDialog`

## 4. Network & text input (A1–A3)

- [x] 4.1 Replace `WifiActivity.showPasswordDialog` with `FrostedGlassWifiPasswordDialog`
- [x] 4.2 Route `InputDialogBuilder.commonlyUsedParameterBuilder` and `materialBuilder` to `FrostedGlassTextInputDialog`

## 5. Date & Time pickers (B1–B3)

- [x] 5.1 Migrate `DateTimeSettingFragment.showDatePicker` to frosted-glass picker wrapper
- [x] 5.2 Migrate `DateTimeSettingFragment.showTimePicker` to frosted-glass picker wrapper
- [x] 5.3 Migrate `DateTimeSettingFragment.showTimeZonePicker` to frosted-glass picker wrapper

## 6. Progress, firmware confirm, boot self-check (D1–D2, D4)

- [x] 6.1 Migrate `VideoUploadProgressDialog` to FrostedGlass custom body (all call sites)
- [x] 6.2 Migrate `showBundledFirmwareUpgradeDialog` to `FrostedGlassDialog`
- [x] 6.3 Migrate `BootSelfCheckDialog` to `FrostedGlassDialog` custom body (incremental item rows preserved)

## 7. QR & cleanup (C11)

- [x] 7.1 Migrate device info QR dialog (`DeviceInformationFragment`) to `FrostedGlassDialog` custom body
- [x] 7.2 Remove deprecated migrated legacy layouts after manual QA
- [x] 7.3 Manual regression: status dialogs, WiFi, date-time, upload progress, firmware upgrade, boot self-check, bind device, text inputs, QR
