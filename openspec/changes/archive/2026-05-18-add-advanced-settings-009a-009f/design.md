## Context

Advanced Settings is an Android data-binding screen backed by `AdvancedSettingViewModel`, `AdvancedSettingVo`, the Room `AdvancedSetting` entity, and `ModbusFiledBuilder.createWriteDeviceSetting`. The current visible controls cover language/unit/sound effect plus five device parameters, and the Modbus payload includes registers 0x0090-0x0099. Register constants for 0x009A-0x009F already exist in `DeviceSettingRegisterAddress`, but they are not represented in the UI, persisted model, conversion layer, defaults, or write payload.

The existing parameter interaction pattern is: tap the value box, play click sound, show `InputDialogFragment` through `SettingInputDialogBuilder`, validate through `AdvancedSettingDataCheck`, update the view model data, persist to DB, write all device settings through Modbus, and synchronize the displayed value/SeekBar when the parameter has a slider. The new settings should follow this behavior so device configuration remains consistent.

## Goals / Non-Goals

**Goals:**
- Add configurable Advanced Settings controls for 0x009A-0x009F:
  - Inlet gas pressure threshold.
  - Driver temperature alarm threshold.
  - Protective lens temperature alarm threshold.
  - Collimating/focusing lens temperature alarm threshold.
  - Motor temperature alarm threshold.
  - Temperature alarm recovery interval.
- Persist and restore the new values with existing advanced settings.
- Include the new registers in the device settings Modbus write payload.
- Make the page scroll when content exceeds the viewport.
- Move Sound Effect into its own full row immediately after the Unit row.

**Non-Goals:**
- Changing the underlying Modbus transport, write scheduling, or command envelope format.
- Redesigning the full Settings tab navigation.
- Changing existing parameter ranges or behavior unless needed to keep current behavior intact.
- Adding support for reading these setting registers back from the device.

## Decisions

1. Extend the existing Advanced Settings data model instead of creating a separate settings table.
   - Rationale: the current write path sends a single advanced-setting object as one register payload, and the new fields belong to the same register block.
   - Alternative considered: maintain a separate alarm-settings model. This would add conversion and synchronization complexity without a clear boundary benefit.

2. Use the same value-box plus dialog-editing pattern as Zero Offset and existing parameters.
   - Rationale: the user explicitly asked to reference existing UI and command behavior. Reusing `SettingInputDialogBuilder`, `AdvancedSettingDataCheck`, `updateAndSendData`, and `upInput` keeps UX and device writes predictable.
   - Alternative considered: add direct editable fields. Existing direct `EditText` blocks are commented out, so reviving them would diverge from the active page behavior.

3. Add sliders only where they fit the established control style and practical ranges.
   - Rationale: current parameter controls pair a value with a SeekBar. The new values have bounded ranges in the register comments, so pressure and temperature thresholds can be represented consistently. The recovery interval has no explicit range in the constants, so implementation should define a conservative validation range in the task phase if no product/device spec provides one.
   - Alternative considered: dialog-only cards for all new fields. This is simpler but less consistent with the existing page request.

4. Include 0x009A-0x009F in `ModbusFiledBuilder.doCreateWriteDeviceSetting` in register order.
   - Rationale: preserving ascending register order makes the payload easy to audit against `DeviceSettingRegisterAddress` and keeps existing writes compatible.
   - Alternative considered: write only the changed setting. Existing behavior writes the full device setting payload after changes, so changing to partial writes is out of scope.

5. Treat Sound Effect as a non-device setting row.
   - Rationale: Sound Effect is a local UI preference (`voiceCheck`) and should not occupy a device-parameter card slot. Moving it below Unit clarifies the split between app preferences and device register settings.
   - Alternative considered: leave Sound Effect paired with the gas threshold. This no longer scales once six more device parameters are added.

## Risks / Trade-offs

- Room schema change risk -> Add fields in a way that preserves existing installs, including a migration or schema strategy aligned with the project database setup.
- Register scaling ambiguity -> Verify whether temperature registers expect integer degrees or tenths before implementation; existing constants describe decimal ranges but current writer uses integer register fields.
- Validation range ambiguity for 0x009F -> Confirm the allowed recovery interval range if device documentation is available; otherwise use a conservative UI range and document it in code/tasks.
- Layout density risk -> A full two-column card grid plus a dedicated Sound Effect row may still be tall; rely on ScrollView and avoid fixed root heights that prevent scrolling.
- Existing dirty worktree risk -> Preserve current unrelated edits in `.vscode/settings.json` and `DeviceSettingRegisterAddress.java` while implementing.
