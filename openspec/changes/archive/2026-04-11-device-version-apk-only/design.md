## Context

Today `DeviceInfo` (Room `t_device_info`) stores `systemVersion` and `uiVersion`. Settings **Device Information** shows both **System version** and **UI version**. `DeviceInfoViewModel` overwrites `uiVersion` from `PackageManager` and may mirror empty `systemVersion` from `uiVersion`. `UpgradeActivity` writes a normalized manifest `version` into `systemVersion` after OTA. That duplicates the installed APK’s `versionName` / `BuildConfig.VERSION_NAME` and can drift from the binary.

## Goals / Non-Goals

**Goals:**

- Single source of truth for **installed app release**: runtime `PackageManager.getPackageInfo().versionName` and/or `BuildConfig.VERSION_NAME` (same string for a given build).
- Remove the **`systemVersion` column** from Room `DeviceInfo` and all writers/readers.
- **Device Information** UI: one version line only; **remove** the separate UI-version row.
- OTA flow continues semver gating vs installed app version; OTA success **does not** repersist app version into Room under a `systemVersion` field.

**Non-Goals:**

- Changing manifest URL, zip layout, or firmware upgrade mechanics beyond removing redundant DB writes.
- Renaming Gradle `versionName` / `BuildConfig` conventions.
- Broader refactor of `DeviceInfo` fields unrelated to app version (firmware, SNs, libraries).

## Decisions

1. **Drop `systemVersion` from `DeviceInfo` + migration**  
   **Rationale**: User-requested; eliminates duplicate storage.  
   **Alternative considered**: Keep column but stop writing—rejected as dead schema.

2. **Display string from APK, not Room**  
   **Rationale**: Matches “truth is the installed binary”. ViewModel or binding reads `versionName` when the screen loads / updates.  
   **Alternative**: Keep one Room field as cache—rejected per proposal.

3. **Remove `uiVersion` from Room if it only duplicated APK** (implementation detail in tasks)  
   If `uiVersion` is still required for MQTT `DeviceInfoVo` backward compatibility, tasks may keep the column but **stop showing** it in Settings and populate only from APK when serializing—or remove from entity if safe. **Design default**: remove from UI first; remove `uiVersion` from persistence only if no remaining contract requires it (tasks will verify Gson/MQTT).

4. **OTA (`UpgradeActivity`)**  
   Remove `setSystemVersion` / `toCoreVersion` persistence to `DeviceInfo`. Keep APK semver check (`SemanticVersionHelper.isNewerThan` vs filename vs current `getUiVersion()` or equivalent) aligned with **installed** version: after column removal, compare against `PackageManager` / in-memory from package.

5. **Label copy**  
   Keep one row labeled per product (e.g. continue using `@string/system_version` for the single line showing APK version) unless product wants a rename—tasks can confirm strings.

## Risks / Trade-offs

- **[Risk] DB migration on deployed devices** → Add Room migration dropping column(s); test upgrade from previous schema.  
- **[Risk] External tools expecting `systemVersion` / `uiVersion` in JSON** → Audit `DeviceInfoVo` / MQTT payloads; document **BREAKING** if field removed from wire format.  
- **[Risk] Tests/fixtures seeding old columns** → Update tests and seed data.

## Migration Plan

1. Ship Room migration removing `systemVersion` (and `uiVersion` if removed from schema).  
2. Release notes: **BREAKING** for any consumer of exported DB or API mirroring `DeviceInfo` JSON.  
3. Rollback: reintroduce column via migration (avoid if possible); prefer forward-only fix.

## Open Questions

- Whether **`uiVersion` must remain in Room** for MQTT/cloud payloads; if yes, populate exclusively from APK at pack time and do not show in Settings.
