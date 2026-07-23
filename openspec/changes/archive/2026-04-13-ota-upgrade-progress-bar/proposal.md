## Why

The OTA upgrade screen shows a SeekBar that does not reflect real work: the ZIP download runs for a long time with no progress, parse/unzip updates flash too fast to see, and the long-running controller firmware step shows no movement. Users cannot tell whether the update is progressing or stuck.

## What Changes

- Drive download progress from bytes read versus `Content-Length` when the response includes a known length; update status copy to **「正在下载升级包」** with English **「Downloading update package」** (via string resources / locale).
- After the ZIP is fully written, **reset** the bar to **0** (or equivalent “phase start”), switch status to **「升级系统中」** / **「Upgrading system」**, then map the remaining flow to **two coarse steps**: **50%** when the controller firmware step finishes (success, **or** skipped as already current, e.g. error 606), and **100%** when the APK step in `controllerBardUpgradeEnd` completes (install invoked or skipped per existing rules).
- When `Content-Length` is absent or invalid, define **best-effort** progress (e.g. stay at 0 or use a bounded indeterminate pattern) without blocking the flow.
- After **silent APK install** is triggered on a successful OTA path, keep the **upgrade success** UI visible for **at least 3 seconds**, then **restart the app** into its normal entry (e.g. `MainActivity` / launcher component for this package) and tear down `UpgradeActivity`, so users see **升级完成 / Upgrade successful** and land in a fresh process with the new build—not only `finish()` without relaunch (today the UI often vanishes immediately and the user does not clearly return to the app).

## Capabilities

### New Capabilities

- `ota-upgrade-progress`: User-visible progress and status text for the in-app OTA ZIP download and the two post-download phases (controller firmware, APK).

### Modified Capabilities

- (none) — existing `lws-app-ota-semver` behavior (manifest, semver gating, install paths) stays the same; this change is UI/progress orchestration only.

## Impact

- `UpgradeActivity` (download loop, phase transitions, `DeviceUpgradeEvent` / `controllerBardUpgradeEnd` hooks, post-install **dwell**, then **explicit app relaunch** + `finish()`).
- `activity_upgrade.xml` (or equivalent) if a dedicated status `TextView` is needed for localized strings.
- `res/values/strings.xml` and `res/values-en/strings.xml` (or project’s i18n pattern) for CN/EN copy.
