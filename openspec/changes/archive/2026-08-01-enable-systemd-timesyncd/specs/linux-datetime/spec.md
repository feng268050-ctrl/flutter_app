## MODIFIED Requirements

### Requirement: Abstract date/time controller

The HMI SHALL provide a reusable Dart `DateTimeController` (name may vary) that exposes wall-clock get/set, timezone get/set, sync mode get/set (`manual` | `network`), and network time sync. Callers (Demo and later product Settings) MUST depend on the abstract API. Linux SHALL implement the controller via system tools (`date` / `timedatectl` / `hwclock` when present) and the shared network sync helper path. Unit-testable fakes MUST be sufficient for host tests without a board. Default sync mode when no preference exists SHALL be **`network`** (Settings Automatic on). On ynh960, offline wall clock SHALL use the external PCF8563 RTC (not the RK809 PMIC RTC); network NTP MUST NOT be required for offline operation, but SHALL be enabled by default when the device can reach NTP.

#### Scenario: Default sync mode is network

- **WHEN** no persisted sync-mode preference exists
- **THEN** `getSyncMode` returns `network`

#### Scenario: Sync mode persists

- **WHEN** the caller sets sync mode to `manual` and later restarts the HMI process
- **THEN** `getSyncMode` returns `manual`

### Requirement: Network time sync

When sync mode is `network` (the product default), Linux SHALL enable OS NTP via `systemd-timesyncd` through `setSyncMode(network)` and HMI/HAL bring-up `applyPersistedSyncMode` (`timedatectl set-ntp true` or equivalent; soft-fail if absent). `syncFromNetwork` / Sync Now SHALL run the one-shot ladder only and MUST NOT itself toggle OS NTP. For immediate correction (explicit Sync Now / Settings Automatic toggle, primary link-up while Automatic, or TLS emergency when the UTC year is before 2025), the controller SHALL attempt the shared one-shot ladder: existing board helper (`sync-time` / successor) if present, else `rdate`, else HTTP `Date` header parsing, then attempt `hwclock -f /dev/rtc0` write when a usable RTC device exists. Sync SHALL be best-effort: failure returns a structured result and MUST NOT crash the HMI. When `onlyIfStale` is requested, the one-shot ladder MAY no-op if the UTC year is already in the sane window (2025–2030 inclusive). Offline devices MUST still keep correct time via the external RTC when NTP is unreachable.

#### Scenario: Sync Now succeeds with connectivity

- **WHEN** network connectivity can reach a sync source and the user/API requests `syncFromNetwork`
- **THEN** the wall clock becomes sane (UTC year ≥ 2025) and the result reports success

#### Scenario: Sync fails without connectivity

- **WHEN** no sync source is reachable
- **THEN** the result reports failure/error and the HMI remains running

#### Scenario: Stale-only skip when already sane

- **WHEN** `syncFromNetwork(onlyIfStale: true)` is called and the UTC year is already in 2025–2030
- **THEN** the implementation MUST NOT churn the one-shot network ladder and reports success (or no-op success)

#### Scenario: Network mode enables OS NTP

- **WHEN** sync mode is set to `network` (or bring-up applies persisted `network` / default with no prefs)
- **THEN** the implementation enables OS NTP (`timedatectl set-ntp true` or equivalent) so `systemd-timesyncd` can synchronize the clock when reachable

#### Scenario: Link-up triggers immediate one-shot sync

- **WHEN** sync mode is `network` and the **primary** network (product `PrimaryNetworkController` / `/var/lib/network/primary.conf`, else lowest board `route_metrics`) transitions to having a usable IPv4 address
- **THEN** the implementation attempts `syncFromNetwork` (one-shot ladder) without requiring the UTC year to be stale
- **AND** Manual sync mode MUST NOT trigger that link-up sync
- **AND** a non-primary iface (e.g. camera Ethernet) MUST NOT trigger that sync

## ADDED Requirements

### Requirement: Manual sync mode disables OS NTP

When sync mode is `manual`, or when a successful manual wall-clock set switches mode to `manual`, Linux SHALL disable OS NTP (`timedatectl set-ntp false` or equivalent) so timesyncd does not overwrite the operator-set time. TLS emergency one-shot sync MUST still be allowed without changing persisted mode (existing `ensureSaneForTls` behavior).

#### Scenario: Manual mode turns NTP off

- **WHEN** the caller sets sync mode to `manual`
- **THEN** OS NTP is disabled and a subsequent `timedatectl` (or equivalent) shows NTP inactive

#### Scenario: Manual wall-clock set turns NTP off

- **WHEN** the caller successfully applies a manual wall-clock set
- **THEN** persisted sync mode is `manual` and OS NTP is disabled

### Requirement: Offline external RTC without NTP

Linux on ynh960 SHALL persist and restore wall clock via the external PCF8563-compatible RTC (`rtc0` after DT bind and with `CONFIG_RTC_DRV_RK808` unset) without requiring NTP or the RK809 PMIC RTC. Manual set and Automatic NTP MUST still update the running system clock and write the RTC (`hwclock -f /dev/rtc0`) when the UTC year is sane.

#### Scenario: rtc-systohc timer enabled

- **WHEN** the appliance image is built
- **THEN** `rtc-systohc.timer` is enabled by preset
- **AND** `rtc-systohc.service` runs `hwclock -w -u -f /dev/rtc0`

### Requirement: Appliance NTP server preference

The image SHALL ship `etc/systemd/timesyncd.conf.d/10-appliance.conf` with primary `NTP=pool.ntp.org` and `FallbackNTP` ordered Cloudflare → Google → Aliyun (`time.cloudflare.com`, `time.google.com`, `ntp.aliyun.com`). After HMI/HAL bring-up, Linux SHALL write `/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf` with `NTP=<persisted ntp_server>` (default `pool.ntp.org`) and `FallbackNTP=` the remaining curated presets (including Windows, Apple, Tencent, `cn.pool.ntp.org`), then restart timesyncd when possible (soft-fail).

#### Scenario: timesyncd drop-in prefers pool then Cloudflare Google Aliyun

- **WHEN** the rootfs overlay timesyncd seed drop-in is inspected
- **THEN** it lists `pool.ntp.org` as primary NTP and Cloudflare, Google, and Aliyun as fallbacks in that order

#### Scenario: HMI bring-up writes curated runtime drop-in

- **WHEN** HAL `applyPersistedNtpServer` runs with default prefs
- **THEN** `/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf` contains `NTP=pool.ntp.org` and `FallbackNTP` listing the other curated presets

### Requirement: Automatic timezone from IP (product Settings)

HAL datetime SHALL support optional `auto_timezone` (default off) and `syncTimezoneFromNetwork` via public IP geolocation (HTTP ip-api.com, then HTTPS ipapi.co). No GPS.

#### Scenario: Auto timezone off by default

- **WHEN** prefs omit `auto_timezone`
- **THEN** `getAutoTimezone` returns false
