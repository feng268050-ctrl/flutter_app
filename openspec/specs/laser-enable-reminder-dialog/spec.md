# laser-enable-reminder-dialog Specification

## Purpose
TBD - created by archiving change add-focus-scale-ref. Update Purpose after archive.
## Requirements
### Requirement: Laser-enable Important Reminder third card SHALL show focus scale guidance

When the user initiates **laser enable** in **quick mode** or **engineer mode** and the **Important Reminder** dialog (`ReminderExactDialog`) is shown, the **third reminder card** SHALL:

1. Display the text: **"Adjust focus scale reference on your gun head to the given value"**.
2. Display an illustration loaded from `res/drawable-nodpi/fsr_{n}.png` for non-negative values and `res/drawable-nodpi/fsr_n{n}.png` for negative values (e.g. `fsr_3.png` for `3`, `fsr_n3.png` for `-3`), where the numeric portion matches `DeviceModelConfig.getFocusScaleRef()`.
3. When no matching drawable exists for the configured value, the illustration area MUST remain **blank** (no placeholder image, no crash).

Cards 1 and 2, the confirm button, and the "don't show again this session" checkbox behavior MUST remain unchanged.

#### Scenario: Reference zero shows zero illustration

- **WHEN** `focus_scale_ref=0` in ROM
- **AND** the user opens laser enable in quick mode
- **AND** `res/drawable-nodpi/fsr_0.png` exists
- **THEN** the third card MUST show the updated text
- **AND** MUST display the `fsr_0.png` illustration

#### Scenario: Positive reference shows matching illustration

- **WHEN** `focus_scale_ref=7` in ROM
- **AND** the user opens laser enable in engineer mode
- **AND** `res/drawable-nodpi/fsr_7.png` exists
- **THEN** the third card MUST display `fsr_7.png`

#### Scenario: Missing illustration shows blank image area

- **WHEN** `focus_scale_ref=99` in ROM
- **AND** no matching `res/drawable-nodpi/fsr_*.png` exists for that value
- **AND** the user opens laser enable in quick mode
- **THEN** the third card MUST show the updated text
- **AND** the illustration `ImageView` MUST be blank

#### Scenario: Session skip still bypasses dialog

- **WHEN** the user previously checked "don't show again this session" for the current mode
- **AND** the user initiates laser enable again in that mode
- **THEN** the Important Reminder dialog MUST NOT be shown (existing `ReminderExactBuilder` behavior)

### Requirement: Important Reminder second card SHALL show mode-specific nozzle guidance

When the user initiates **laser enable** in **quick mode** or **engineer mode** and the **Important Reminder** dialog (`ReminderExactDialog`) is shown, the **second reminder card** text and illustration SHALL depend on the active process model (`ModelConstant`) at click time:

| Model group | Models | Card 2 text (English) | Card 2 illustration (`res/drawable-nodpi/`) |
|-------------|--------|------------------------|---------------------------------------------|
| Weld | `CONTINUOUS_WELDING`, `POINT_WELDING` | Confirm that you have installed the welding copper nozzle | `nozzle_weld.png` |
| Cut | `HAND_CUT`, `CNC_CUT` | Confirm that you have installed the cutting copper nozzle | `nozzle_cut.png` |
| Weld-path clean | `WELD_CLEAN` | Confirm that you have removed the laser tube and the copper nozzle | `nozzle_weld_path_clean.png` |
| Ultra-wide clean | `WIDTH_CLEAN` | Confirm that you have removed the laser tube and the copper nozzle | `nozzle_ultra_wide_clean.png` |

The illustration MUST be bound at runtime (not a static `@mipmap` in layout XML). When no matching drawable exists for the active model, the illustration `ImageView` MUST remain **blank** (no placeholder image, no crash).

Cards 1 and 3, the confirm button, and session skip behavior MUST remain functionally unchanged aside from localization (below).

#### Scenario: Continuous weld shows welding nozzle copy and illustration

- **WHEN** the active model is `CONTINUOUS_WELDING`
- **AND** the user opens laser enable and the Important Reminder dialog is shown
- **AND** `res/drawable-nodpi/nozzle_weld.png` exists
- **THEN** card 2 MUST display the welding copper nozzle confirmation text
- **AND** MUST display the `nozzle_weld.png` illustration

#### Scenario: Spot weld shows welding nozzle copy and illustration

- **WHEN** the active model is `POINT_WELDING`
- **AND** the Important Reminder dialog is shown
- **AND** `res/drawable-nodpi/nozzle_weld.png` exists
- **THEN** card 2 MUST display the welding copper nozzle confirmation text
- **AND** MUST display the `nozzle_weld.png` illustration

#### Scenario: Hand cut shows cutting nozzle copy and illustration

- **WHEN** the active model is `HAND_CUT`
- **AND** the Important Reminder dialog is shown
- **AND** `res/drawable-nodpi/nozzle_cut.png` exists
- **THEN** card 2 MUST display the cutting copper nozzle confirmation text
- **AND** MUST display the `nozzle_cut.png` illustration

#### Scenario: CNC cut shows cutting nozzle copy and illustration

- **WHEN** the active model is `CNC_CUT`
- **AND** the Important Reminder dialog is shown
- **AND** `res/drawable-nodpi/nozzle_cut.png` exists
- **THEN** card 2 MUST display the cutting copper nozzle confirmation text
- **AND** MUST display the `nozzle_cut.png` illustration

#### Scenario: Weld path clean shows removal copy and illustration

- **WHEN** the active model is `WELD_CLEAN`
- **AND** the Important Reminder dialog is shown
- **AND** `res/drawable-nodpi/nozzle_weld_path_clean.png` exists
- **THEN** card 2 MUST display the laser tube and copper nozzle removal confirmation text
- **AND** MUST display the `nozzle_weld_path_clean.png` illustration

#### Scenario: Ultra-wide clean shows removal copy and illustration

- **WHEN** the active model is `WIDTH_CLEAN`
- **AND** the Important Reminder dialog is shown
- **AND** `res/drawable-nodpi/nozzle_ultra_wide_clean.png` exists
- **THEN** card 2 MUST display the laser tube and copper nozzle removal confirmation text
- **AND** MUST display the `nozzle_ultra_wide_clean.png` illustration

#### Scenario: Missing illustration shows blank image area

- **WHEN** the active model is `HAND_CUT`
- **AND** `res/drawable-nodpi/nozzle_cut.png` does not exist
- **AND** the user opens laser enable in quick mode
- **THEN** card 2 MUST show the cutting nozzle confirmation text
- **AND** the illustration `ImageView` MUST be blank

### Requirement: Important Reminder dialog copy SHALL be localized

All user-visible strings in the Important Reminder dialog (`ReminderExactDialog` / `dialog_reminder.xml`) SHALL be defined in Android string resources and MUST be available in **default (`values`)**, **English (`values-en`)**, and **Simplified Chinese (`values-zh`)** at minimum. This includes:

1. Dialog title (**Important Reminder!**)
2. Card 1 tip (laser protection equipment)
3. Card 2 tips (three mode-specific variants)
4. Card 3 tip (focus scale reference guidance)
5. Confirm button label

Hard-coded English in layout XML or Java for these strings MUST NOT remain.

#### Scenario: zh-CN locale shows translated reminder title

- **WHEN** the device locale is Simplified Chinese
- **AND** the Important Reminder dialog is shown
- **THEN** the dialog title MUST display the `values-zh` string, not hard-coded English

#### Scenario: Card 2 weld tip localized in zh-CN

- **WHEN** the device locale is Simplified Chinese
- **AND** the active model is `CONTINUOUS_WELDING`
- **AND** the Important Reminder dialog is shown
- **THEN** card 2 MUST display the Simplified Chinese translation of the welding nozzle confirmation text

#### Scenario: Card 3 focus-scale tip uses string resource

- **WHEN** the Important Reminder dialog is shown
- **THEN** card 3 text MUST be loaded from a string resource (not a Java string literal)
- **AND** MUST follow the user's current locale

