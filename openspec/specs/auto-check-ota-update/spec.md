# auto-check-ota-update Specification

## Purpose
TBD - created by archiving change auto-check-ota-update. Update Purpose after archive.
## Requirements
### Requirement: Device Information exposes auto-check OTA checkbox

The Device Information screen SHALL display an **Auto check for updates** (`自动检查更新`) checkbox directly below the **Check and Install Updates** button.

The checkbox SHALL use the project standard checkbox control (`FrostCheckboxView` / `@style/FrostCheckbox`) with inline label via `app:labelText`, matching the visual pattern of the engineer-mode laser reminder **Don't show again** option (`dialog_frost_action_laser_enable_reminder` / `important_reminder_check_box`).

Localized label strings SHALL be provided in `values`, `values-en`, and `values-zh`.

The checkbox SHALL default to **unchecked** for new installs and after upgrade until the user explicitly checks it.

#### Scenario: Checkbox visible below manual check button

- **WHEN** the user opens Settings → Device Information
- **THEN** the auto-check checkbox SHALL appear centered below the **Check and Install Updates** primary button with label **Auto check for updates**

#### Scenario: Default is unchecked

- **WHEN** the app is installed fresh or the user has never changed the setting
- **THEN** the auto-check checkbox SHALL be unchecked

### Requirement: Auto-check preference is persisted locally

The client SHALL persist the auto-check enabled flag in app-private storage (e.g. SharedPreferences) and SHALL restore it across process restarts.

#### Scenario: Preference survives restart

- **WHEN** the user enables auto-check and later cold-starts the app
- **THEN** the checkbox SHALL still be checked

### Requirement: Auto OTA check runs once per process on first home entry after device registration probe

When auto-check is **enabled**, the client SHALL run the OTA manifest check **at most once per app process**, triggered from the home screen prompt pipeline (`HomePromptQueue` / `AutoDialogQueue`) on the **first** `MainActivity` home `onResume` after boot self-check completes.

The auto check SHALL run **after** the home-screen device registration / bind probe (`BindDeviceHomePrompt` or equivalent) has finished and determined that **no** bind-device blocking dialog is required (device already has bound users, or bind prompt was dismissed for the session).

The auto check SHALL NOT run when auto-check is disabled.

The auto check SHALL NOT run on non-home screens.

#### Scenario: Enabled on first home after bind skip

- **WHEN** auto-check is on, boot self-check has completed, it is the first home resume this process, WiFi is usable, and the device registration probe reports existing bound users
- **THEN** the client SHALL enqueue an automatic OTA manifest check on the home prompt queue after bind-related prompts

#### Scenario: Disabled skips automatic check

- **WHEN** auto-check is off and the user enters the home screen
- **THEN** the client SHALL NOT run the automatic OTA manifest check

#### Scenario: Bind dialog still required defers auto check

- **WHEN** auto-check is on but the bind-device home prompt is still eligible to show
- **THEN** the automatic OTA check SHALL NOT run until bind eligibility is cleared for the session

#### Scenario: Second home resume in same process does not re-check

- **WHEN** auto-check is on and the automatic check already ran this process (regardless of outcome)
- **THEN** returning to the home screen again in the same process SHALL NOT trigger another automatic manifest check

### Requirement: Automatic check reuses standard OTA manifest and semver rules

The automatic check SHALL call the same manifest fetch and semver comparison used by manual **Check and Install Updates** (`OtaUpdateManifestService.checkAgainst` against installed `versionName`).

#### Scenario: Same newer-version decision as manual check

- **WHEN** the automatic check runs and the manifest `version` is greater than the installed app version under semver rules
- **THEN** the client SHALL treat the result as an available OTA update

#### Scenario: No update is silent

- **WHEN** the automatic check runs and the manifest version is not greater than the installed version
- **THEN** the client SHALL NOT show any dialog for that outcome

### Requirement: Automatic check failures are silent

When the automatic OTA check cannot complete successfully (pinned API base absent, network error, invalid manifest, timeout, etc.), the client SHALL NOT show an error or “already latest” dialog to the user.

The client MAY log the failure for diagnostics.

#### Scenario: Unpinned API base

- **WHEN** the automatic check runs and no Worker API base is pinned
- **THEN** no user-visible dialog SHALL be shown

#### Scenario: Network or parse failure

- **WHEN** the automatic manifest request throws or returns unusable data
- **THEN** no user-visible error dialog SHALL be shown

### Requirement: Available update shows confirm dialog with Go to update action

When the automatic check finds an available update, the client SHALL enqueue a `FrostDialog` confirmation on `AutoDialogQueue` with fixed localized copy:

- Title: **New Version Available** (English) / **新版本可用** (Chinese), Title Case in English.
- Body: **A new version {version} is available, download and install updates in Settings.** (English) or equivalent Chinese, with `{version}` replaced by the manifest `version` string normalized via `SemanticVersionHelper.toCoreVersion` (strips `-alpha`, `-beta`, build metadata, etc., same as `UpgradeActivity` title fallback).
- Confirm: **Go to Update** (English, Title Case) / **前往更新** (Chinese).
- Cancel: **Cancel** / **取消**.

Dismissal or cancel SHALL complete the home prompt without starting upgrade.

#### Scenario: Update available shows prompt

- **WHEN** the automatic check finds a newer manifest version (e.g. `2.1.0`)
- **THEN** the user SHALL see title **New Version Available** and body containing `2.1.0` and Settings guidance, with confirm **Go to Update**

#### Scenario: Cancel dismisses without navigation

- **WHEN** the user dismisses or cancels the auto-update dialog
- **THEN** the app SHALL remain on the home screen and SHALL NOT open `UpgradeActivity`

### Requirement: Confirm navigates to UpgradeActivity with cached manifest

When the user taps **Go to update** on the automatic-update dialog, the client SHALL start `UpgradeActivity` with the manifest fields already obtained by the automatic check (`title`, `content`, `version`, `downloadUrl`, optional `sha512`, optional current `DeviceInfo`).

The client SHALL NOT issue a second manifest fetch solely to populate `UpgradeActivity` after the user confirms.

#### Scenario: Confirm opens upgrade page without re-fetch

- **WHEN** the user confirms **Go to update** after a successful automatic check
- **THEN** `UpgradeActivity` SHALL open with Intent extras from the cached manifest and SHALL NOT repeat `OtaUpdateManifestService.checkAgainst` before navigation

