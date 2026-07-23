## ADDED Requirements

### Requirement: OTA manifest check supports automatic home-screen entry

In addition to the manual **Check and Install Updates** action on Device Information, the OTA client SHALL support an automatic manifest check entry point invoked from the home-screen prompt pipeline when the user has enabled **Auto check for updates**.

The automatic entry SHALL use the same pinned-base manifest URL, fetch implementation, and semver comparison requirements as the manual check.

When the automatic entry determines an update is available and the user confirms navigation, the client SHALL pass the already-fetched manifest data to `UpgradeActivity` without performing a redundant manifest request.

#### Scenario: Automatic entry uses pinned lws-app manifest URL

- **WHEN** the automatic home-screen OTA check runs with a pinned Worker API base
- **THEN** the client SHALL request the same `/view/lws-app/<json_file>` manifest as the manual OTA check

#### Scenario: Automatic entry honors semver no-download rule

- **WHEN** the automatic check compares manifest `version` to local `versionName` and local is equal or newer
- **THEN** the client SHALL NOT open `UpgradeActivity` and SHALL NOT download the OTA payload

#### Scenario: Confirmed automatic navigation reuses manifest result

- **WHEN** the automatic check found a newer manifest and the user confirms **Go to update**
- **THEN** `UpgradeActivity` SHALL receive `downloadUrl` and `version` from that check result without a second manifest GET
