## ADDED Requirements

### Requirement: Important Reminder second card SHALL show mode-specific nozzle guidance

When the user initiates **laser enable** in **quick mode** or **engineer mode** and the **Important Reminder** dialog (`ReminderExactDialog`) is shown, the **second reminder card** text SHALL depend on the active process model (`ModelConstant`) at click time:

| Model group | Models | Card 2 text (English) |
|-------------|--------|------------------------|
| Weld | `CONTINUOUS_WELDING`, `POINT_WELDING` | Confirm that you have installed the welding copper nozzle |
| Cut | `HAND_CUT`, `CNC_CUT` | Confirm that you have installed the cutting copper nozzle |
| Clean | `WELD_CLEAN`, `WIDTH_CLEAN` | Confirm that you have removed the laser tube and the copper nozzle |

Card 2 icon, cards 1 and 3, confirm button, and session skip behavior MUST remain functionally unchanged aside from localization (below).

#### Scenario: Continuous weld shows welding nozzle copy

- **WHEN** the active model is `CONTINUOUS_WELDING`
- **AND** the user opens laser enable and the Important Reminder dialog is shown
- **THEN** card 2 MUST display the welding copper nozzle confirmation text

#### Scenario: Spot weld shows welding nozzle copy

- **WHEN** the active model is `POINT_WELDING`
- **AND** the Important Reminder dialog is shown
- **THEN** card 2 MUST display the welding copper nozzle confirmation text

#### Scenario: Hand cut shows cutting nozzle copy

- **WHEN** the active model is `HAND_CUT`
- **AND** the Important Reminder dialog is shown
- **THEN** card 2 MUST display the cutting copper nozzle confirmation text

#### Scenario: CNC cut shows cutting nozzle copy

- **WHEN** the active model is `CNC_CUT`
- **AND** the Important Reminder dialog is shown
- **THEN** card 2 MUST display the cutting copper nozzle confirmation text

#### Scenario: Weld path clean shows removal copy

- **WHEN** the active model is `WELD_CLEAN`
- **AND** the Important Reminder dialog is shown
- **THEN** card 2 MUST display the laser tube and copper nozzle removal confirmation text

#### Scenario: Ultra-wide clean shows removal copy

- **WHEN** the active model is `WIDTH_CLEAN`
- **AND** the Important Reminder dialog is shown
- **THEN** card 2 MUST display the laser tube and copper nozzle removal confirmation text

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
