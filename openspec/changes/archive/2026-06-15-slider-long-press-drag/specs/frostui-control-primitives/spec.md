## MODIFIED Requirements

### Requirement: FrostSlider linear variant replaces ScaledSlider

`FrostSlider` and `FrostSliderView` SHALL replace `com.lasercyber.lws.ui.component.ScaledSlider` in advanced settings. The control MUST support min/max/zero scale labels when configured, track and thumb appearance aligned with `scaled_seekbar_progress` and `scaled_seekbar_thumb`, and progress changes suitable for `AdvancedSettingFragment` bindings. The control MUST NOT support tap-to-seek: clicking the track outside the thumb hit region MUST NOT change progress. Progress MUST change only after the user long-presses the thumb (see `slider-long-press-drag`) and then drags horizontally.

#### Scenario: Advanced settings sliders migrate

- **WHEN** `fragment_advanced_setting.xml` is updated
- **THEN** all `ScaledSlider` elements MUST be replaced with `FrostSliderView`
- **AND** `ScaledSlider.java` MUST be deleted after call sites compile

#### Scenario: ScaledSeekBar remains for FlankedSeekBar

- **WHEN** this change completes
- **THEN** `com.lasercyber.lws.ui.component.ScaledSeekBar` MUST remain in the codebase
- **AND** `FlankedSeekBar` and process-video progress UI MUST continue to compile without migration in this change

#### Scenario: Track tap does not jump value

- **WHEN** the user taps the linear slider track away from the thumb
- **THEN** the displayed progress MUST remain unchanged

#### Scenario: Long-press thumb then drag updates advanced settings value box

- **WHEN** the user long-presses the thumb on an advanced-settings slider until it enlarges, then drags
- **THEN** the paired value box MUST update in real time during the drag
- **AND** persistence and Modbus write behavior after release MUST remain as defined in `advanced-settings-persistence`
