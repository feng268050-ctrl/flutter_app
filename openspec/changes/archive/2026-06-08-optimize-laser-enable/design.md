## Context

Laser enable in **quick mode** (`GeneralOperationsFragment`) and **engineer mode** (`EngineerModeActivity`) runs two pre-dialog checks via `EngineerModeCheck.enableLaser` → `checkWorkStatus`, including a **key switch** gate (`deviceStatus.isKeySwitchOn()`). Emulators use Modbus mock reads and have no physical key; developers hit `check_key_error_text` and cannot proceed.

The **Important Reminder** dialog (`ReminderExactDialog`, layout `dialog_reminder.xml`) is opened via `ReminderExactBuilder.openReminderExactDialog`. Today:

- Card 1, title, confirm button, and card 2 text are **hard-coded English** in XML.
- Card 3 tip is set in Java with a hard-coded English string (focus-scale requirement from prior change).
- Card 2 always shows welding nozzle copy regardless of active `ModelConstant` mode.
- `ReminderExactBuilder` keys session skip by `WorkModel` (quick vs engineer), not by process model—unchanged in this change.

Existing emulator detection: `AndroidEmulatorUtils.isLikelyEmulator()` (used by `ModbusConfig.isMock()`, boot self-check, comm status display).

## Goals / Non-Goals

**Goals:**

- Allow laser-enable preflight to pass on emulator without key-switch-on.
- Show correct card-2 safety copy per process model group (weld / cut / clean).
- Externalize all Important Reminder user-visible strings to Android resources with en + zh translations.

**Non-Goals:**

- Changing key-switch display on `EquipmentStatusBar` (status bar may still show key off on emulator).
- Changing card 2 icon (`open_laser_icon2`) per mode.
- Changing session "don't show again" behavior or focus-scale card 3 logic.
- Skipping other preflight checks (E-stop, shielding gas) on emulator.

## Decisions

### 1. Emulator key-switch bypass in `EngineerModeCheck.checkWorkStatus`

**Choice:** Wrap the key-switch block with `if (!ModbusConfig.isMock()) { ... }` (or `!AndroidEmulatorUtils.isLikelyEmulator()`—equivalent in practice since `ModbusConfig.isMock()` delegates to emulator detection).

**Rationale:** Single choke point used by both quick and engineer laser enable; matches existing emulator classification used elsewhere. Production devices never use mock Modbus.

**Alternative considered:** Mock `keySwitchStatus=1` in `ModbusMockReadValues`—rejected because it hides the real status in UI and only fixes mock data, not the check logic.

### 2. Pass active process model into `ReminderExactDialog`

**Choice:** Extend `ReminderExactBuilder.openReminderExactDialog(Context, int sessionKey, int processModel, listener)` and `ReminderExactDialog(Context, int processModel, listener)`. Callers pass `deviceControlData.getModel()`.

**Rationale:** Card 2 mapping is per `ModelConstant`, not per quick/engineer session key. Minimal API surface change.

**Alternative considered:** Read model from `MemoryCacheManager` inside dialog—rejected as implicit and harder to test.

### 3. Card 2 text mapping helper

**Choice:** Small static helper (e.g. `LaserEnableReminderCopy.nozzleTipResId(int model)`) mapping:

| Models | String key |
|--------|------------|
| `CONTINUOUS_WELDING`, `POINT_WELDING` | `laser_reminder_welding_nozzle` |
| `HAND_CUT`, `CNC_CUT` | `laser_reminder_cutting_nozzle` |
| `WELD_CLEAN`, `WIDTH_CLEAN` | `laser_reminder_clean_nozzle_removed` |

Unknown model → fallback to welding copy (safest default).

### 4. i18n: move all dialog copy to string resources

**Choice:** Add string keys for title, card 1, card 2 (three variants), card 3 (reuse/update existing focus-scale key), confirm button. Set card 2/3 in Java; reference `@string/...` in XML for static cards, title, button.

**Rationale:** Aligns with project localization (`values`, `values-en`, `values-zh`). Card 3 already partially hard-coded in Java—consolidate to `@string/laser_reminder_focus_scale_ref`.

English source strings (per user request):

- Title: `Important Reminder!`
- Card 1: `Please check that you are wearing laser protection equipment!`
- Card 2 weld: `Confirm that you have installed the welding copper nozzle`
- Card 2 cut: `Confirm that you have installed the cutting copper nozzle`
- Card 2 clean: `Confirm that you have removed the laser tube and the copper nozzle`
- Card 3: existing focus-scale text (already specified)
- Confirm: `Yes, I have taken laser protection measures.`

Provide Simplified Chinese translations in `values-zh`.

## Risks / Trade-offs

- **[Risk] Emulator bypass too broad** → Mitigation: Gate only on `ModbusConfig.isMock()` / emulator detection; production hardware unchanged.
- **[Risk] Wrong model passed in engineer mode tab switch** → Mitigation: Read `deviceControlData.getModel()` at click time (existing pattern in both call sites).
- **[Risk] Partial i18n if card 2 left in XML** → Mitigation: Card 2 `TextView` gets `android:id` and text set in Java from mapped `@string` resource.

## Migration Plan

App-only change; no ROM/OTA migration. Ship in next app build. Rollback: revert Java/XML/string changes.

## Open Questions

None—all requirements specified by product.
