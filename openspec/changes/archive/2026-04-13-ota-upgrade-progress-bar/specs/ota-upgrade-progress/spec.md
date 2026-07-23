## ADDED Requirements

### Requirement: OTA download phase shows byte-based progress when length is known

During `UpgradeActivity` ZIP download, the client SHALL read the HTTP response body and, when the response advertises a positive entity length (`Content-Length` / `getContentLengthLong()` > 0), SHALL update the upgrade `SeekBar` on the UI thread to reflect the fraction of bytes written divided by that length, clamped to 0–100.

The visible status text SHALL use the string resource for **「正在下载升级包」** (default locale) and the English string resource **「Downloading update package」** under an English locale (`values-en` or project equivalent).

#### Scenario: Progress advances with Content-Length

- **WHEN** the OTA ZIP response includes a positive `Content-Length` and the client reads the body incrementally
- **THEN** the UI thread SHALL update the progress bar so it moves from 0 toward 100 as the fraction of bytes read increases

#### Scenario: English locale shows English download status

- **WHEN** the application locale is English and the download phase is active
- **THEN** the status text SHALL show the English **Downloading update package** string

### Requirement: OTA download phase without known length does not fabricate byte progress

- **WHEN** the OTA ZIP response does not provide a usable content length (missing, chunked, or non-positive)
- **THEN** the client MUST NOT infer a false percentage from unknown total size; the progress bar MAY remain at 0 until the download completes, while the download status text still shows the downloading strings

#### Scenario: Unknown length still completes download

- **WHEN** content length is unknown and the download finishes successfully
- **THEN** the client SHALL proceed to the post-download phase without claiming intermediate byte percentages

### Requirement: Post-download phase resets progress and uses system-upgrade copy

- **WHEN** the ZIP has been fully written to storage successfully and the UI transitions from the download phase to system upgrade work
- **THEN** the client SHALL reset the progress bar to **0** (start of the post-download scale) and set the status text to **「升级系统中」** with English **「Upgrading system」** via string resources

#### Scenario: After download, label switches to system upgrade

- **WHEN** the download phase ends successfully
- **THEN** the status text SHALL show the system-upgrade strings and the bar SHALL read 0 before controller/APK milestones

### Requirement: Two-step post-download progress at 50% and 100%

After the post-download phase has started (bar at 0, system-upgrade copy), the client SHALL set the progress bar to **50** when the controller firmware step has **completed** in a way that continues the OTA flow (including **success** and **skip-because-same-version** paths that proceed to APK handling).

The client SHALL set the progress bar to **100** when the APK handling inside `controllerBardUpgradeEnd` has **finished** (after silent install is invoked or skipped per existing semver rules).

#### Scenario: Firmware skipped as same version moves bar to half

- **WHEN** the controller reports the same-version / no-upgrade outcome that still continues to APK evaluation
- **THEN** the progress bar SHALL be updated to **50** before APK handling runs

#### Scenario: Firmware success moves bar to half

- **WHEN** the controller reports firmware upgrade success and the flow continues to APK handling
- **THEN** the progress bar SHALL be updated to **50** before APK handling runs

#### Scenario: APK step completion reaches full bar

- **WHEN** `controllerBardUpgradeEnd` completes APK evaluation and install-or-skip logic
- **THEN** the progress bar SHALL be set to **100**

### Requirement: Successful OTA with silent APK install shows success for at least three seconds then restarts the app

- **WHEN** the OTA flow invokes **silent APK installation** (`installApkSilently` or project equivalent) because the new APK is newer than the installed app
- **THEN** the client SHALL show the existing upgrade-success user feedback (**升级完成** / **Upgrade successful** or the same string resources already used for OTA success)
- **AND** SHALL keep that feedback visible (and SHALL NOT call `UpgradeActivity.finish()` or otherwise tear down the upgrade screen solely due to success) until **at least three seconds** have elapsed on the main thread after the success UI is shown, unless the process is terminated earlier by the system or installer (**best-effort**)
- **AND** after that dwell, the client SHALL **start the application’s normal launcher / main entry activity** for this package (so the app **restarts immediately** into a fresh task as appropriate) and then **finish** `UpgradeActivity`, rather than only closing the upgrade screen without relaunching the app.

#### Scenario: User can read success before activity closes

- **WHEN** silent install is started on the success path and the app process remains alive
- **THEN** at least three seconds SHALL pass after the success indication is shown before `UpgradeActivity` finishes

#### Scenario: App relaunches after success dwell

- **WHEN** silent install is started on the success path, the success UI has been shown, and at least three seconds have elapsed without the process being killed by the system
- **THEN** the client SHALL start the app’s configured main/launcher activity and **THEN** finish `UpgradeActivity`, so the user returns to the application entry (updated build) without manually tapping the icon

#### Scenario: APK skipped does not require install-specific dwell

- **WHEN** the OTA outcome is success but no silent install is invoked (APK not newer than installed)
- **THEN** this requirement’s **3 second** minimum dwell **SHALL NOT** be mandatory beyond any existing dialog behavior unless product chooses to align timings in implementation
