## ADDED Requirements

### Requirement: control package provides switch checkbox and linear slider primitives

The system SHALL provide a `com.lasercyber.lws.frostui.control` package containing Compose implementations and XML/Java interop Views for `FrostSwitch`, `FrostCheckbox`, and `FrostSlider` (linear variant only). The package MUST depend on `frostui.border` and MUST NOT depend on `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`.

#### Scenario: Control package compiles without ui imports

- **WHEN** frostui control sources are compiled
- **THEN** no file under `frostui.control` MUST import `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`
- **AND** ui code MAY import `com.lasercyber.lws.frostui.control`

### Requirement: FrostSwitch matches legacy switch visual contract

`FrostSwitch` and `FrostSwitchView` SHALL reproduce the visual and interaction behavior of `com.lasercyber.lws.ui.component.Switch` and style `LwsSwitch`, including capsule track, thumb, checked/unchecked colors, and **200ms** toggle animation.

#### Scenario: Switch toggles with click sound

- **WHEN** a user toggles an enabled `FrostSwitch` or `FrostSwitchView`
- **THEN** the checked state MUST update
- **AND** `FrostUiClickSoundRegistry` MUST be invoked for the successful toggle

#### Scenario: Switch supports XML and Checkable interop

- **WHEN** `FrostSwitchView` is declared in XML with `android:checked` and frostui switch styleable attributes
- **THEN** the view MUST implement `android.widget.Checkable`
- **AND** Java callers MUST be able to set `OnCheckedChangeListener` without referencing deleted `ui.component.Switch`

### Requirement: FrostCheckbox matches legacy checkbox visual contract

`FrostCheckbox` and `FrostCheckboxView` SHALL reproduce the visual and interaction behavior of `com.lasercyber.lws.ui.component.Checkbox` and style `LwsCheckbox`, including circular ring, animated checkmark, optional `labelText`, and **200ms** animation.

#### Scenario: Checkbox toggles with optional label

- **WHEN** a user toggles an enabled `FrostCheckbox` with a non-empty label
- **THEN** the checked state and checkmark animation MUST match the legacy control within pixel-level acceptance (D12)
- **AND** click sound MUST play via `FrostUiClickSoundRegistry`

### Requirement: FrostSlider linear variant replaces ScaledSlider

`FrostSlider` and `FrostSliderView` SHALL replace `com.lasercyber.lws.ui.component.ScaledSlider` in advanced settings. The control MUST support min/max/zero scale labels when configured, track and thumb appearance aligned with `scaled_seekbar_progress` and `scaled_seekbar_thumb`, and progress changes suitable for `AdvancedSettingFragment` bindings.

#### Scenario: Advanced settings sliders migrate

- **WHEN** `fragment_advanced_setting.xml` is updated
- **THEN** all `ScaledSlider` elements MUST be replaced with `FrostSliderView`
- **AND** `ScaledSlider.java` MUST be deleted after call sites compile

#### Scenario: ScaledSeekBar remains for FlankedSeekBar

- **WHEN** this change completes
- **THEN** `com.lasercyber.lws.ui.component.ScaledSeekBar` MUST remain in the codebase
- **AND** `FlankedSeekBar` and process-video progress UI MUST continue to compile without migration in this change

### Requirement: Control design tokens live in dedicated resource files

Switch, checkbox, and linear slider tokens SHALL reside in dedicated `frostui_control_*` resource files under `app/src/main/res/values/`. frostui control code MUST reference these files as the canonical source after migration.

#### Scenario: Legacy styleables removed after migration

- **WHEN** all layouts and Java references migrate off `ui.component.Switch`, `Checkbox`, and `ScaledSlider`
- **THEN** corresponding `Switch`, `Checkbox`, and `ScaledSlider` entries in shared `attrs.xml` MUST be removed or forwarded without conflict
- **AND** frostui control styleables MUST be defined in `frostui_control_attrs.xml`

### Requirement: Legacy ui component switch checkbox scaledslider classes are removed

After migration, the system MUST delete `com.lasercyber.lws.ui.component.Switch`, `Checkbox`, and `ScaledSlider`. The system MUST NOT ship `@Deprecated` wrapper classes for these types.

#### Scenario: No remaining references to deleted classes

- **WHEN** the change is complete
- **THEN** grep for `com.lasercyber.lws.ui.component.Switch`, `.Checkbox`, and `.ScaledSlider` MUST return no layout or production Java references
- **AND** `:app:assembleDebug` MUST succeed

### Requirement: Switch layouts fully migrated including bluetooth activity

All production layout references to `ui.component.Switch` SHALL be migrated to `FrostSwitchView`, including:

- `fragment_common_settings.xml`
- `fragment_advanced_setting.xml`
- `fragment_date_time_setting.xml`
- `fragment_network_setting.xml`
- `activity_wifi.xml`
- `activity_bluetooth.xml`

#### Scenario: Bluetooth page uses FrostSwitchView

- **WHEN** `activity_bluetooth.xml` is opened on device
- **THEN** its switch MUST be a `FrostSwitchView` instance
- **AND** `BluetoothManagerActivity` MUST bind to `FrostSwitchView` without `ui.component.Switch`

### Requirement: Checkbox layouts fully migrated

All production layout references to `ui.component.Checkbox` SHALL be migrated to `FrostCheckboxView` in:

- `frosted_glass_action_laser_enable_reminder.xml`
- `frosted_glass_action_prompt.xml`
- `frosted_glass_body_boot_self_check.xml`
- `activity_safety_tips.xml`
- `activity_use_safety_tips.xml`

#### Scenario: Prompt dialog checkbox uses FrostCheckboxView

- **WHEN** a frosted glass prompt with checkbox body is shown
- **THEN** the checkbox MUST be `FrostCheckboxView`
- **AND** dialog logic MUST compile without `ui.component.Checkbox`
