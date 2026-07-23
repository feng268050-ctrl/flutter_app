## ADDED Requirements

### Requirement: Laser-enable Important Reminder third card SHALL show focus scale guidance

When the user initiates **laser enable** in **quick mode** or **engineer mode** and the **Important Reminder** dialog (`ReminderExactDialog`) is shown, the **third reminder card** SHALL:

1. Display the text: **"Adjust focus scale reference on your gun head to the given value"**.
2. Display an illustration loaded from `res/mipmap-anydpi/focus-scale-ref/{n}.png` where `{n}` is the decimal string of `DeviceModelConfig.getFocusScaleRef()` (e.g. `0`, `5`, `-3`).
3. When no matching PNG resource exists for `{n}`, the illustration area MUST remain **blank** (no placeholder image, no crash).

Cards 1 and 2, the confirm button, and the "don't show again this session" checkbox behavior MUST remain unchanged.

#### Scenario: Reference zero shows zero illustration

- **WHEN** `focus_scale_ref=0` in ROM
- **AND** the user opens laser enable in quick mode
- **AND** `res/mipmap-anydpi/focus-scale-ref/0.png` exists
- **THEN** the third card MUST show the updated text
- **AND** MUST display the `0.png` illustration

#### Scenario: Positive reference shows matching illustration

- **WHEN** `focus_scale_ref=7` in ROM
- **AND** the user opens laser enable in engineer mode
- **AND** `res/mipmap-anydpi/focus-scale-ref/7.png` exists
- **THEN** the third card MUST display `7.png`

#### Scenario: Missing illustration shows blank image area

- **WHEN** `focus_scale_ref=99` in ROM
- **AND** no `res/mipmap-anydpi/focus-scale-ref/99.png` exists
- **AND** the user opens laser enable in quick mode
- **THEN** the third card MUST show the updated text
- **AND** the illustration `ImageView` MUST be blank

#### Scenario: Session skip still bypasses dialog

- **WHEN** the user previously checked "don't show again this session" for the current mode
- **AND** the user initiates laser enable again in that mode
- **THEN** the Important Reminder dialog MUST NOT be shown (existing `ReminderExactBuilder` behavior)
