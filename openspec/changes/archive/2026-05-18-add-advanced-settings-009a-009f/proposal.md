## Why

Advanced Settings already exposes and sends device-setting registers up to 0x0099, while register constants for 0x009A-0x009F exist but are not configurable from the page or included in the Modbus write payload. The page also no longer fits comfortably on one screen, and the current Sound Effect placement competes with device parameter controls.

## What Changes

- Add Advanced Settings UI controls for device setting registers 0x009A-0x009F, following the existing Zero Offset and other parameter-setting interaction pattern.
- Persist the new values with the rest of `AdvancedSetting` data and include them in device setting Modbus writes.
- Support scrolling on the Advanced Settings page so all settings remain reachable when content exceeds the viewport.
- Move Sound Effect to the row immediately after Unit and make that row contain only Sound Effect.
- Preserve existing Language, Unit, Zero Offset, Scan Width Correction, laser power, gas threshold, and sound effect behavior.

## Capabilities

### New Capabilities
- `advanced-settings-device-registers`: Advanced Settings page presentation, persistence, validation, and Modbus write behavior for device setting registers.

### Modified Capabilities
- None.

## Impact

- Affected UI: `fragment_advanced_setting.xml`, `AdvancedSettingFragment`, setting input dialogs, and localized strings.
- Affected data model: `AdvancedSetting`, `AdvancedSettingVo`, conversion/default-value helpers, and Room schema handling if required.
- Affected command path: `ModbusFiledBuilder.createWriteDeviceSetting` / `doCreateWriteDeviceSetting` payloads for registers 0x009A-0x009F.
- Tests/manual validation should cover displayed defaults, value editing, scrolling, sound-effect layout, persistence, and outbound Modbus register addresses/values.
