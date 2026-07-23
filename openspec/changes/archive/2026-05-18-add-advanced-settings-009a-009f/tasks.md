## 1. Data Model and Defaults

- [x] 1.1 Add `AdvancedSetting` fields for 0x009A-0x009F values and handle Room schema/migration requirements.
- [x] 1.2 Add matching `AdvancedSettingVo` string/int accessors for binding and validation.
- [x] 1.3 Update `AdvancedSettingConvertUtil` to convert all new fields between entity and VO.
- [x] 1.4 Add default values for all new settings in `DefaultValueUtils.createDefaultAdvancedSetting`.

## 2. Validation and Input Dialogs

- [x] 2.1 Confirm register value scaling/ranges for pressure, temperature thresholds, and recovery interval before coding final conversions.
- [x] 2.2 Add `AdvancedSettingDataCheck` validation methods for 0x009A-0x009F settings.
- [x] 2.3 Add `SettingInputDialogBuilder` builders for each new setting using localized labels and default values.
- [x] 2.4 Add or update localized strings for labels, hints, and validation messages in English and Chinese resources.

## 3. Advanced Settings UI

- [x] 3.1 Rework `fragment_advanced_setting.xml` so the page scrolls reliably when controls exceed the viewport.
- [x] 3.2 Move Sound Effect to a dedicated full row immediately after the Unit row.
- [x] 3.3 Add UI cards/value controls for inlet gas pressure, driver temperature alarm, protective lens temperature alarm, collimating/focusing lens temperature alarm, motor temperature alarm, and temperature alarm recovery interval.
- [x] 3.4 Wire click handlers and value updates in `AdvancedSettingFragment` using the existing update, persist, send, and UI synchronization flow.

## 4. Modbus Write Behavior

- [x] 4.1 Extend `ModbusFiledBuilder.doCreateWriteDeviceSetting` to include 0x009A-0x009F in register order with default fallbacks.
- [x] 4.2 Ensure changing Sound Effect still updates only local sound preference state and does not trigger device setting writes.
- [x] 4.3 Preserve existing 0x0090-0x0099 write behavior while adding the new register writes.

## 5. Verification

- [x] 5.1 Add or update unit tests for `AdvancedSettingConvertUtil` and default-value coverage for the new fields.
- [x] 5.2 Add or update tests for `ModbusFiledBuilder.doCreateWriteDeviceSetting` to assert 0x009A-0x009F addresses and values are emitted.
- [x] 5.3 Manually verify Advanced Settings layout: scrolling reaches all controls, Sound Effect is alone after Unit, and existing controls still work.
- [x] 5.4 Manually verify editing each new setting persists the value and sends the expected Modbus payload.
