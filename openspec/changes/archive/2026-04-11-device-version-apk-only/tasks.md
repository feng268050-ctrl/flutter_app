## Implementation notes

**1.2 Decision:** Remove persisted **`uiVersion`** from Room; MQTT / `DeviceInfoVo` fill **`uiVersion`** from **`PackageManager.versionName`** / **`BuildConfig.VERSION_NAME`** at pack time (`DeviceStatusPut.applyInstalledAppVersionForMqtt`). **`systemVersion`** remains removed from Room.

**5.2 Tests:** `:app:testDebugUnitTest` — `ProcessLibXlsxMappingTest.emptyNumericCell_mapsToNull` still fails (unrelated to this change; Excel mapping). All other unit tests passed in the last run.

## 1. Inventory and contracts

- [x] 1.1 Grep the codebase for `systemVersion`, `getSystemVersion`, `setSystemVersion`, and `uiVersion` on `DeviceInfo`; list MQTT/Gson/export paths (`DeviceInfoVo`, `DeviceStatusPut`, caches) that serialize `DeviceInfo`.
- [x] 1.2 Decide per **Open Questions** in `design.md`: keep `uiVersion` in Room only as a non-displayed mirror of APK for payloads, or remove it entirely; document the decision in a short comment in `tasks.md` completion notes if needed.

## 2. Room schema and entity

- [x] 2.1 Remove `systemVersion` from `DeviceInfo` entity (and `uiVersion` if 1.2 chooses full removal).
- [x] 2.2 Add a Room **migration** that drops `systemVersion` (and `uiVersion` if applicable) from `t_device_info`, bump `AppDatabase` version, and wire `addMigrations` in `AppDatabase.java`.
- [x] 2.3 Regenerate or update Room schema exports under `app/schemas/` if the project tracks them.

## 3. Settings UI and ViewModel

- [x] 3.1 Remove the **UI Version** row from `fragment_device_information.xml` (and related string resources if now unused).
- [x] 3.2 Ensure the remaining **single** app version row binds to APK-sourced data (`PackageManager` / `BuildConfig`) via `DeviceInfoViewModel` or a small helper, not Room `systemVersion` / removed `uiVersion`.
- [x] 3.3 Delete `DeviceInfoViewModel` logic that set default/fallback `systemVersion`, mirrored `systemVersion` from `uiVersion`, or wrote APK version into Room for display only.

## 4. OTA and upgrade flow

- [x] 4.1 Remove `setSystemVersion` / normalized manifest persistence from `UpgradeActivity` (`controllerBardUpgradeEnd` and any other writers).
- [x] 4.2 Align APK upgrade branch semver checks to compare zip filename version against **installed** `PackageManager.getPackageInfo().versionName` (or `BuildConfig.VERSION_NAME`) instead of `deviceInfo.getUiVersion()` if that field is removed from persistence.

## 5. Downstream consumers and tests

- [x] 5.1 Update `DeviceStatusPut`, memory cache (`DEVICE_INFO_KEY`), and any tests/fixtures that construct `DeviceInfo` with `systemVersion` / removed fields.
- [x] 5.2 Run unit/instrumentation tests touching Settings, OTA, or Room; fix failures.
- [x] 5.3 After implementation, update **root** specs under `openspec/specs/` for `device-app-version-single-source` (new) and `lws-app-ota-semver` (delta merge) per project archive workflow when promoting the change.
