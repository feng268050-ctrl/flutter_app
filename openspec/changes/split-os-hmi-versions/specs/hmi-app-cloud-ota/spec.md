## ADDED Requirements

### Requirement: HMI Version is the Flutter app identity

The product HMI App SHALL treat its Flutter `pubspec.yaml` semver (synced Dart constants, e.g. `kHmiVersion` / `kHmiVersionCode`) as **HMI Version**, not as OS or umbrella System Version. Device Information and HMI Upgrade SHALL display this value as HMI Version.

#### Scenario: Running app reports HMI Version from constants

- **WHEN** `app_version.dart` has `kHmiVersion` `1.0.41`
- **THEN** HMI Upgrade and Device Information HMI Version rows show `1.0.41`

### Requirement: HMI Upgrade page shows HMI and Process Library versions

Settings SHALL provide an **HMI Upgrade** page (CyberUI Settings chrome / `cyber_upgrade_ui`) that, in check mode, shows read-only **HMI Version** and **Process Library Version** (value or `-`). Process Library Version MUST NOT remain on the OS/System Upgrade page after this change. Manual **Check for Updates** for the HMI channel SHALL live on this page.

#### Scenario: Check mode rows

- **WHEN** the operator opens HMI Upgrade from Device Information in check mode
- **THEN** HMI Version and Process Library Version are visible
- **AND** the page offers Check for Updates via `cyber_upgrade_ui` check-card chrome

#### Scenario: Process Library leaves OS Upgrade

- **WHEN** the operator opens OS/System Upgrade in check mode
- **THEN** Process Library Version is not listed on that page

### Requirement: HMI cloud check uses lws-hmi/app release.json only

HMI Check for Updates SHALL fetch **`https://cdn.lasercyber.com/{artifact}/app/release.json`** (default artifact `lws-hmi`) and compare the manifest `version` to the running **HMI Version**. The check MUST NOT require cloud services enabled or a Worker API origin pin. The HMI channel MUST NOT implement a “bundled HMI package version” or newest-wins against onboard assets — cloud manifest vs running app only. Unreachable CDN MUST report check failed/unavailable, not “up to date”.

#### Scenario: Newer cloud HMI available

- **WHEN** running HMI Version is `1.0.41` and `lws-hmi/app/release.json` reports a newer version with a package `url`
- **THEN** the HMI Upgrade check-card indicates an update is available
- **AND** MUST NOT consult a bundled HMI archive version

#### Scenario: CDN unreachable

- **WHEN** the operator activates Check for Updates and the app manifest cannot be fetched
- **THEN** the card reports failure/unavailable
- **AND** MUST NOT claim the HMI is up to date

### Requirement: HMI apply downloads signed tar.gz, installs /opt/hmi, restarts hmi.service

On **Update Now** (operator) or host-force apply, the App SHALL download the HMI `tar.gz` and sibling `.sig` (via `SignedBlobFetch` / equivalent), Ed25519-verify against `/etc/ota/ed25519.pub`, extract/install into **`/opt/hmi`** (same logical tree as `build-app` / former push-app), then **restart `hmi.service`** so the new app loads. Apply MUST NOT write A/B boot/rootfs/oem partitions. Verify failure MUST refuse install and MUST NOT claim success. Progress SHALL use `cyber_upgrade_ui` multi-phase chrome on the HMI Upgrade page.

#### Scenario: Successful cloud HMI upgrade

- **WHEN** Update Now runs against a valid signed HMI `tar.gz`
- **THEN** the archive is verified, `/opt/hmi` is updated, and `hmi.service` is restarted
- **AND** no rootfs/boot partition write occurs

#### Scenario: Bad signature refuses install

- **WHEN** Ed25519 verification fails
- **THEN** the App refuses to replace `/opt/hmi`
- **AND** reports failure via upgrade UI

### Requirement: Host download command for app package

The App SHALL watch **`/run/hmi/upgrade-app.cmd`** for at least **`download <url>`** (and documented clean/cancel if needed). Host `make upgrade-app` uses this cmd file; SSH is control-plane only. Host-force policy SHALL skip newer-version gates while still verifying signatures and showing progress.

#### Scenario: download url triggers fetch

- **WHEN** the cmd file receives `download http://192.168.55.2:PORT/app-v1.0.42.tar.gz`
- **THEN** the App downloads that URL and `url + ".sig"`, verifies, installs, and restarts `hmi.service`
