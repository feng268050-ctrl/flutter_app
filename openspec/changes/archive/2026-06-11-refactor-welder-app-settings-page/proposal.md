## Why

The Settings area has grown into a mixed experience: visual chrome still relies on image-based card/button assets, Advanced Settings contains both operator preferences and device parameters, and related controls are spread across legacy pages. This change refactors the welder App Settings page into clearer top-level sections with reusable FrostedGlass components and a dedicated Advanced Settings persistence model.

## What Changes

- Replace image-resource-based Settings cards with `FrostedGlassCard` and image-resource-based action buttons with `FrostedGlassButton`.
- Reorganize Settings into these top-level tabs in order: Device Information, Common Settings, Advanced Settings, and Custom Home Page.
- Keep the current Device Information content but display it in untitled groups: identity rows, version rows, and Focus Scale Reference.
- Move general operator settings into Common Settings, grouped as Network, Display & Sound, Date & Time, and Misc.
- Use the current Screen Settings icon for Common Settings and rename the related resource to match the new section.
- Merge Automatic Date & Time and Automatic Timezone into one `Automatic` control in Common Settings Date & Time.
- Rebuild Advanced Settings around device parameters only, grouped as Offset & Correction, Power Thresholds, and Temperature Thresholds.
- Replace `t_parameter_settings` with `t_advanced_settings` and migrate existing `t_parameter_settings` values into the new table.
- Rename the existing Custom Layout section to Custom Home Page while preserving its behavior.

## Capabilities

### New Capabilities
- `settings-page-structure`: Settings top-level tab order, section naming, group layout, FrostedGlass visual usage, and Custom Home Page naming.
- `advanced-settings-persistence`: Advanced Settings device-parameter table ownership, singleton loading, and migration from `t_parameter_settings` to `t_advanced_settings`.

### Modified Capabilities
- `common-settings`: Common Settings grouping, resource naming, row placement, and operator preference ownership.
- `system-date-time-management`: Date & Time entry placement changes and merged automatic time/timezone control semantics.
- `parameter-settings`: Legacy `t_parameter_settings` behavior is superseded by the new Advanced Settings persistence model.
- `advanced-settings-device-registers`: Device parameter rows and Modbus write payloads must source values from the new Advanced Settings table.
- `device-focus-scale-ref-config`: Focus Scale Reference remains in Device Information but moves into the third untitled Device Information group.
- `monitor-settings-top-tab-navigation`: Settings top tab composition changes from the prior multi-tab set to the four-tab structure.

## Impact

- Android Settings UI layouts/fragments/view models under `app/src/main/java/com/lasercyber/lws/ui/activitys/setting` and related `res/layout`, `res/drawable`, `res/mipmap`, and string resources.
- FrostedGlass component adoption for Settings card and button chrome.
- Room schema version, entity/DAO/database registration, migrations, defaults, and conversion utilities for Advanced Settings parameters.
- Modbus register write/read flows that currently depend on `ParameterSettings`/`t_parameter_settings`.
- Date & Time, Wi-Fi, boot self-check, language/unit/sound effect, Device Information, and Custom Layout/Home Page navigation surfaces.
