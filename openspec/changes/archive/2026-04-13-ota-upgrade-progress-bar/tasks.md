## 1. Strings and layout

- 1.1 Add `values/strings.xml` entries for download and system-upgrade status (Chinese default: 正在下载升级包、升级系统中).
- 1.2 Add `values-en/strings.xml` entries: **Downloading update package**, **Upgrading system**.
- 1.3 Bind a status `TextView` in `activity_upgrade.xml` (replace or id the existing **Updating** label) for runtime copy updates.

## 2. Download progress

- 2.1 In `UpgradeActivity` download path, read `Content-Length` when > 0 and pass incremental bytes-read to the UI thread with throttling.
- 2.2 Map bytes to SeekBar 0–100 during phase A; set status to download strings; handle unknown length per spec (no fake percent).
- 2.3 On successful ZIP write, end phase A: transition to phase B (reset bar to 0, system-upgrade strings).

## 3. Post-download milestones

- 3.1 Set progress to **50** when entering APK path after controller outcome (both `UPGRADE_SUCCESS` and 606-continue paths) before APK semver/install logic.
- 3.2 Set progress to **100** at end of `controllerBardUpgradeEnd` after APK branch completes; align with failure paths so the bar is not left mid-way incorrectly.

## 4. Success UI dwell and app restart after silent install

- 4.1 On the path that calls `installApkSilently`, show upgrade-success feedback first, then `Handler.postDelayed` / main-thread equivalent **3000 ms** before navigation.
- 4.2 After the delay, **start** the app’s main/launcher activity (same package; reuse `SystemSettingConstant` / `MainActivity` patterns or `getLaunchIntentForPackage` as decided in design), with flags for a clean restart where needed, **then** `finish()` `UpgradeActivity`.
- 4.3 Remove pending success-delay runnables in `onDestroy` / `onStop` as appropriate to avoid leaks or late `startActivity`/`finish()` after destroy.

## 5. Verification

- 5.1 Manual test with server that sends `Content-Length`: bar moves during download; labels CN/EN per locale.
- 5.2 Manual test without `Content-Length` (or chunked): no false smooth progress; phase B still runs. *(Not exercised: CDN/server always sends `Content-Length`.)*
- 5.3 Confirm 606 skip and real firmware success both hit 50% then 100% when APK step runs.
- [x] 5.4 Confirm that when a newer APK triggers silent install, the success message stays on screen **≥ 3s**, then the **app restarts** into the main entry (where the app controls teardown and the process survives).  
  _**Note:** Not achievable as specified on production path: `YNHAPI.installApkSilently` ends the process before returning (logcat shows `UpgradeActivity` `UIUp: before installApkSilently` but never `UIUp: after installApkSilently`), so the 3s dwell + delayed `restartAppAfterOta()`/`finish()` in app code does not run after silent install. Treat as vendor/API limitation._

*On-device checks in §5 were not run in this environment (Gradle/network to JitPack failed); please verify on hardware.*