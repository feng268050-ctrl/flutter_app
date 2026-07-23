## 1. Data Model And Migration

- [x] 1.1 Add `AdvancedSettings` entity and `AdvancedSettingsDao` backed by `t_advanced_settings`.
- [x] 1.2 Add default creation helpers and conversion utilities for `AdvancedSettings`.
- [x] 1.3 Add Room migration from version 45 to 46 that creates `t_advanced_settings` and copies supported values from `t_parameter_settings`.
- [x] 1.4 Register the new entity, DAO, database version, and migration in `AppDatabase`.
- [x] 1.5 Replace active app reads and writes of `ParameterSettings` with `AdvancedSettings`.

## 2. Advanced Settings Behavior

- [x] 2.1 Update the Advanced Settings view model to load, edit, and save only device parameters from `t_advanced_settings`.
- [x] 2.2 Rebuild the Advanced Settings layout into Offset & Correction, Power Thresholds, and Temperature Thresholds groups.
- [x] 2.3 Preserve numeric validation and stepper limits, including Minimum Gas Pressure Threshold 0 through 400.
- [x] 2.4 Update Modbus register payload builders and related call sites to source Advanced Settings values from `t_advanced_settings`.
- [x] 2.5 Verify no Advanced Settings parameter blob is added to `command.stat_response` or `device.online`.

## 3. Common Settings Page

- [x] 3.1 Create the Common Settings page with Network, Display & Sound, Date & Time, and Misc groups.
- [x] 3.2 Move Wireless Network entry behavior into the Common Settings Network group, preserving the existing Wi-Fi flow and deep-link behavior.
- [x] 3.3 Move Language, Unit, Screen Brightness, Screen-off Time, and Sound Effect into Display & Sound with existing persistence/system behavior.
- [x] 3.4 Merge Automatic Date & Time and Automatic Timezone into one Automatic control that writes both platform settings.
- [x] 3.5 Move Show Startup Self-Check into Misc and keep persistence in `t_common_settings.showBootSelfCheck`.
- [x] 3.6 Rename the Screen Settings icon resource for Common Settings while preserving the existing artwork.

## 4. Settings Navigation And Visuals

- [x] 4.1 Update `DeviceSettingActivity` tab order to Device Information, Common Settings, Advanced Settings, and Custom Home Page.
- [x] 4.2 Update status-bar titles, initial tab constants, and callers that open Settings directly.
- [x] 4.3 Rename Custom Layout presentation strings/navigation to Custom Home Page while preserving stored custom layout behavior.
- [x] 4.4 Group Device Information rows into identity, version, and Focus Scale Reference untitled groups.
- [x] 4.5 Replace image-backed Settings card containers with `FrostedGlassCard`.
- [x] 4.6 Replace image-backed Settings action buttons with `FrostedGlassButton`.

## 5. Verification

- [x] 5.1 Run OpenSpec validation/status for `refactor-welder-app-settings-page`.
- [x] 5.2 Build the Android app and resolve compile or resource errors.
- [x] 5.3 Verify Room migration on an upgraded database containing `t_parameter_settings` values.
- [x] 5.4 Verify Settings tab order, grouped rows, FrostedGlass visuals, and Custom Home Page naming on the target layout.
- [x] 5.5 Verify Common Settings changes persist and do not trigger unintended Modbus writes.
- [x] 5.6 Verify Advanced Settings edits persist to `t_advanced_settings` and still send the expected device register payloads.

## 6. Polish And UX Follow-ups

- [x] 6.1 Add reusable Settings list chrome (`InsetList`, `InsetListRow`, `InsetDivider`, `SectionHeader`, `SectionContent`, `ControlCapsule`) and adopt it on Common Settings, Device Information, Advanced Settings, and Wi-Fi pages.
- [x] 6.2 Polish Wi-Fi list and details layouts: connected-row dedupe, consistent row height, signal/lock/check alignment, and card margins.
- [x] 6.3 Polish Common Settings Display & Sound: capsule padding, brightness slider end alignment, and sun icon / percent color transition across slider midpoint.
- [x] 6.4 Externalize Common Settings option labels (language, unit, screen-off, sound effect) and complete missing `values-zh` strings.
- [x] 6.5 Refresh Advanced Settings temperature displays when Unit changes in Common Settings (`observeCommonSettings`).
- [x] 6.6 Apply alternating `FrostedGlassCard` border gradients, restore power-threshold endpoint labels, and align Advanced Settings slider tracks/thumbs to scale endpoints.
- [x] 6.7 Use concise Chinese Date & Time row labels (`日期`, `时间`, `时区`) without the `设置` prefix in `values-zh`.
- [x] 6.8 Set Zero Offset Auto button (`zero_point_auto`) to `borderGradientCenter="left-right"`.
- [x] 6.9 Update Advanced Settings seek bars to refresh card value boxes in real time while dragging; persist and send Modbus writes on release only.
