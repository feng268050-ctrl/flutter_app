## ADDED Requirements

### Requirement: Installed MediaMTX version tracking

The application SHALL persist the semver of the MediaMTX binary currently installed under application-private storage (distinct from the APK `versionName`) and SHALL compare it against bundled APK assets and OTA-delivered payloads.

#### Scenario: Fresh install uses bundled version

- **WHEN** no installed MediaMTX version exists
- **THEN** the system MUST install from bundled APK assets on first relay preparation

### Requirement: OTA may deliver newer MediaMTX binary

The `lws-app` OTA delivery mechanism SHALL support an optional MediaMTX artifact (binary or zip containing binary + metadata) with a semver. When OTA reports a newer MediaMTX version than installed, the system SHALL replace the installed binary atomically on a safe boundary (process not running or after relay stop).

#### Scenario: OTA upgrades MediaMTX

- **WHEN** OTA apply completes with a MediaMTX payload newer than the installed version
- **THEN** the next relay preparation MUST use the OTA binary and MUST update the persisted installed version

### Requirement: No downgrade without explicit policy

The system MUST NOT replace a newer installed MediaMTX with an older bundled APK asset solely because the APK shipped an older pin, unless an explicit downgrade policy is documented and triggered by operators.

#### Scenario: APK older than OTA-installed binary

- **WHEN** installed MediaMTX version is newer than the APK-bundled pin
- **THEN** startup MUST keep the newer installed binary until a newer OTA or APK bump mandates upgrade

### Requirement: Safe apply during active relay

If MediaMTX is running when an OTA payload arrives, the system SHALL defer binary replacement until the relay stops or SHALL restart the relay after swap with a diagnosable log entry.

#### Scenario: OTA during active viewers

- **WHEN** OTA delivers a new MediaMTX binary while the relay process is running
- **THEN** the system MUST NOT corrupt the active binary file in place mid-stream and MUST complete replacement only after a safe stop boundary
