## Why

`DeviceInfo` currently persists both `systemVersion` and `uiVersion`, which duplicate the same product fact—the installed Android app release. Storing `systemVersion` in Room adds drift risk (DB vs actual APK) and extra maintenance. The Settings **Device Information** screen also shows **UI Version** separately even when it matches the user-facing “app version”, which is redundant noise.

## What Changes

- **Remove persisted `systemVersion`** from the Room `DeviceInfo` model (and migrations as needed). **BREAKING** for the `t_device_info` schema and any code/serialization that assumes the column exists.
- **Treat the app release as read-only from the APK**: use `BuildConfig.VERSION_NAME` and/or `PackageManager.getPackageInfo().versionName` wherever the UI or logic needs “current app version”; do not write an app-version duplicate into Room for OTA completion.
- **Remove the “UI Version” row** from the Device Information layout; keep a single **system/app version** line (or rename label to match product copy) sourced only from APK/build metadata.
- **Adjust OTA completion paths** (`UpgradeActivity` and related) so they no longer `setSystemVersion` / persist app version into `DeviceInfo` for this purpose; OTA continues to use manifest semver vs installed `versionName` for gating per existing OTA spec.

## Capabilities

### New Capabilities

- `device-app-version-single-source`: Defines how the app exposes “installed app version” in Settings and related surfaces—single runtime source (APK / `BuildConfig`), no Room column for that value, and Device Information UI without a separate UI-version row.

### Modified Capabilities

- `lws-app-ota-semver`: Update requirements so OTA success handling does not require persisting manifest-derived app version into Room `systemVersion`; clarify that local comparison remains against installed app `versionName` (or equivalent) per existing semver rules.

## Impact

- **Room**: `t_device_info` migration removing `systemVersion` (or deprecating column—implementation detail in design); `DeviceInfo` entity, DAO, Gson/MQTT payloads if `DeviceInfo` is serialized with that field.
- **UI**: `fragment_device_information.xml` and bindings; strings if `ui_version` becomes unused.
- **Logic**: `DeviceInfoViewModel`, `UpgradeActivity`, `DeviceStatusPut` / MQTT packaging, any `MemoryCacheManager` `DEVICE_INFO_KEY` consumers expecting `systemVersion`.
- **Tests**: Unit/instrumentation tests referencing `systemVersion` or UI version row.
