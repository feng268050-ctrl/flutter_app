## 1. Resources and package skeleton

- [x] 1.1 Create `frostui_control_attrs.xml`, `frostui_control_colors.xml`, `frostui_control_dimens.xml` (migrate Switch/Checkbox/ScaledSlider tokens from `attrs.xml`, `styles.xml`, `dimens.xml`)
- [x] 1.2 Add `FrostSwitch` / `FrostCheckbox` styles in values (mirror `LwsSwitch` / `LwsCheckbox`)
- [x] 1.3 Create `app/src/main/kotlin/com/lasercyber/lws/frostui/control/` and `control/interop/` package directories
- [x] 1.4 Add `FrostControlColors.kt` and `FrostControlDimens.kt` reading `frostui_control_*` resources

## 2. FrostSwitch

- [x] 2.1 Implement `FrostSwitch` Composable (Canvas track/thumb, 200ms animation, `FrostUiClickSoundRegistry`)
- [x] 2.2 Implement `FrostSwitchAttrs.kt` parsing XML styleable from `frostui_control_attrs.xml`
- [x] 2.3 Implement `FrostSwitchView` (`AbstractComposeView`, `Checkable`, `setOnCheckedChangeListener`)
- [x] 2.4 Add unit tests: toggle callback, disabled no-op, checked state

## 3. FrostCheckbox

- [x] 3.1 Implement `FrostCheckbox` Composable (ring, checkmark animation, optional label, 200ms)
- [x] 3.2 Implement `FrostCheckboxAttrs.kt` and `FrostCheckboxView` interop
- [x] 3.3 Add unit tests: toggle callback, label rendering contract

## 4. Switch layout and Java migration

- [x] 4.1 Replace `ui.component.Switch` with `FrostSwitchView` in: `fragment_common_settings.xml`, `fragment_advanced_setting.xml`, `fragment_date_time_setting.xml`, `fragment_network_setting.xml`, `activity_wifi.xml`, `activity_bluetooth.xml`
- [x] 4.2 Update Java bindings: `WifiActivity`, `BluetoothManagerActivity`, `CommonSettingsFragment`, `AdvancedSettingFragment`, `DateTimeSettingFragment`, `NetworkSettingFragment` (grep `ui.component.Switch`)
- [x] 4.3 Delete `com.lasercyber.lws.ui.component.Switch.java`
- [x] 4.4 Remove `Switch` styleable from `attrs.xml` if fully superseded

## 5. Checkbox layout and Java migration

- [x] 5.1 Replace `ui.component.Checkbox` with `FrostCheckboxView` in all five checkbox layouts (prompt, boot self check, safety tips)
- [x] 5.2 Update Java: `FrostedGlassPromptDialog`, `BootSelfCheckDialog`, `ReminderExactBuilder`, `SafetyTipsActivity`, `UseSafetyTipsActivity`
- [x] 5.3 Delete `com.lasercyber.lws.ui.component.Checkbox.java`
- [x] 5.4 Remove `Checkbox` styleable from `attrs.xml` if fully superseded

## 6. FrostSlider (linear)

- [x] 6.1 Implement `FrostSlider` Composable (track/thumb aligned with `scaled_seekbar_*`, min/max/zero scale labels)
- [x] 6.2 Implement `FrostSliderAttrs.kt` and `FrostSliderView` (progress/max listeners for `AdvancedSettingFragment`)
- [x] 6.3 Replace all `ScaledSlider` in `fragment_advanced_setting.xml` with `FrostSliderView`
- [x] 6.4 Update `AdvancedSettingFragment` seek/slider bindings (grep `ScaledSlider`, `ScaledSeekBar` under advanced settings only)
- [x] 6.5 Delete `com.lasercyber.lws.ui.component.ScaledSlider.java`
- [x] 6.6 Confirm `ScaledSeekBar.java` **remains** and `FlankedSeekBar` / `activity_process_video_details.xml` still compile

## 7. Documentation and framework spec alignment

- [x] 7.1 Update `docs/frostui-compose-refactor-design.md` §4 to document `control` fourth layer
- [x] 7.2 Grep verify no production imports of deleted `Switch` / `Checkbox` / `ScaledSlider`
- [x] 7.3 Grep verify no `frostui.control` imports `com.lasercyber.lws.ui`

## 8. Verification

- [x] 8.1 `:app:assembleDebug` and frostui/control unit tests pass
- [x] 8.2 `make sync` — visual check: common settings, advanced settings (switches + sliders), WiFi, Bluetooth, safety tips, laser-enable prompt, boot self check
- [x] 8.3 Pixel-level spot check per D12: switch track, checkbox checkmark, slider thumb/scale labels
