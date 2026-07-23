## Context

Settings currently uses `DeviceSettingActivity` with `TopTabView` and `ViewPager2` to host six tabs: Advanced Settings, Network Settings, Screen Settings, Date & Time, Device Information, and Custom Layout. Several pages render rows and cards with image resources such as `net_work_border*`, while the app already has reusable FrostedGlass primitives for cards and buttons.

Advanced Settings is implemented through `AdvancedSettingFragment` and `AdvancedSettingViewModel`, combining operator preferences from `t_common_settings` with device parameters from `t_parameter_settings`. The requested refactor separates this into Common Settings for operator/system controls and Advanced Settings for device parameters only. The database change is material because `t_parameter_settings` is replaced by `t_advanced_settings`.

## Goals / Non-Goals

**Goals:**
- Present Settings as exactly four top-level tabs in this order: Device Information, Common Settings, Advanced Settings, Custom Home Page.
- Use `FrostedGlassCard` and `FrostedGlassButton` for Settings card/button chrome instead of image-backed visual assets.
- Preserve existing setting behavior while reorganizing rows into the requested groups.
- Move Advanced Settings parameter persistence from `t_parameter_settings` to `t_advanced_settings`, migrating existing values.
- Keep existing Modbus register semantics and validation while changing the persistence source.

**Non-Goals:**
- Redesign FrostedGlass primitives themselves.
- Change Wi-Fi, system brightness, language, unit, sound effect, boot self-check, date/time, or custom home page business behavior beyond the requested placement and grouping.
- Add new remote APIs or expose Advanced Settings parameters in WebSocket snapshots.
- Change device model/version discovery semantics for Device Information.

## Decisions

1. Keep `DeviceSettingActivity` as the top-level shell.

   `DeviceSettingActivity` already owns the status bar, `TopTabView`, and non-swipeable `ViewPager2` behavior. Reusing it limits navigation risk: implementation updates the tab list, default title, initial-tab indexes, and fragment order instead of introducing a new activity. The main alternative was a single-fragment router with internal tabs, but that would replace working status-bar and deep-link behavior without adding much value.

2. Build Common Settings as a composed Settings page instead of preserving separate top-level Network, Screen, and Date & Time tabs.

   Common Settings should group Network, Display & Sound, Date & Time, and Misc in one scrollable page. Existing logic from `NetworkSettingFragment`, `ScreenDisplayFragment`, `DateTimeSettingFragment`, and common preference portions of `AdvancedSettingFragment` should be moved into reusable row/view-model helpers or into a new `CommonSettingsFragment`, while preserving the underlying system utility calls and `CommonSettings` persistence. The alternative was nesting the existing fragments inside cards, but nested fragment lifecycles would make row grouping and visual consistency harder.

3. Treat Advanced Settings as a new persistence owner, not an alias over `ParameterSettings`.

   Create `AdvancedSettings` entity and DAO backed by `t_advanced_settings`, with fields matching the requested parameter set:
   `zeroPointCorrection`, `properSwingWidth`, `laserStartPower`, `laserEndPower`, `blowPressureThreshold`, `inletGasPressureThreshold`, `driverTemperatureAlarmThreshold`, `protectiveLensTemperatureAlarmThreshold`, `collimatingLensTemperatureAlarmThreshold`, `motorTemperatureAlarmThreshold`, and `temperatureAlarmRecoveryInterval`.
   Legacy fields not displayed in the requested Advanced Settings groups should not be carried forward unless current Modbus writes still require them. If a required write path depends on a removed field, keep it in code defaults or document it as no longer user-configurable before removing it from persistence.

4. Migrate data forward with a Room version bump.

   Add the next database migration after version 45. The migration creates `t_advanced_settings`, copies values from `t_parameter_settings` where present, inserts defaults if needed through application-level first-load logic, and leaves legacy `t_parameter_settings` unused after migration. Dropping the old table is acceptable if no downgraded app compatibility is required; otherwise it may remain orphaned until a later cleanup migration. App code must register only the new entity/DAO for active reads and writes.

5. Use FrostedGlass components at the row/card boundary.

   Replace image background resources in Settings layouts with `FrostedGlassCard` containers and `FrostedGlassButton` actions. Existing row contents, switches, radio controls, seek bars, and picker dialogs stay as-is unless their container needs sizing/spacing adjustments. This keeps the visual refactor focused and uses the existing component contract.

6. Merge Date & Time automatic controls into one UI control while preserving both platform settings.

   The new `Automatic` row writes both auto-time and auto-timezone settings together. Manual Date and Time rows are enabled only when automatic time is off; Time Zone is enabled only when automatic timezone is off, which will normally track the same switch state after this refactor. During refresh, if platform state is split because of external changes, the combined control should reflect enabled only when both are enabled and still allow the user to bring both settings into the selected state.

## Risks / Trade-offs

- Database migration misses a parameter column -> migrated devices lose operator-tuned thresholds. Mitigation: use explicit column mapping tests or migration verification against a pre-v45 fixture containing every `t_parameter_settings` field.
- Removing `ParameterSettings` references touches Modbus, AI zero-point, process parameter, and advanced settings code paths. Mitigation: centralize the replacement through an `AdvancedSettingsDao` and conversion utility, then update call sites mechanically.
- Common Settings combines logic that currently lives in separate fragments. Mitigation: keep behavior helpers small and preserve existing system utility calls; avoid changing permission and lifecycle behavior except where grouping requires it.
- Four-tab order changes existing `EXTRA_INITIAL_TAB_INDEX` assumptions. Mitigation: replace index constants with named constants for the new order and update callers that deep-link to Wireless Network.
- FrostedGlass containers may change measured size compared with image backgrounds. Mitigation: verify at target tablet resolution and keep scroll containers using the global scrollbar style.

## Migration Plan

1. Add `AdvancedSettings` entity, `AdvancedSettingsDao`, defaults, and conversion utilities.
2. Add Room migration from version 45 to 46 to create and populate `t_advanced_settings` from `t_parameter_settings`.
3. Update `AppDatabase` entities, DAO accessors, and migration registration.
4. Update Advanced Settings view model, validation, and Modbus write builders to use `AdvancedSettings`.
5. Remove active app reads/writes of `ParameterSettings` and `t_parameter_settings`.
6. Refactor Settings UI fragments and resources, then verify navigation, persistence, and device write behavior on app launch and after upgrade.

Rollback is limited because Room schema upgrades are forward-only. If rollback support is needed for development builds, keep the legacy table during the first migration and rely on existing destructive downgrade behavior for APK downgrades.

## Open Questions

- Should legacy `t_parameter_settings` be dropped in the 45-to-46 migration or left unused for one release?
- Are `redLightOffset`, `swingSpeedUpperLimit`, `swingSpeedLowerLimit`, `manualWireFeedSpeed`, and `manualDrawStringSpeed` intentionally removed from user-configurable Advanced Settings, or should they remain internal/default-backed for device writes?
