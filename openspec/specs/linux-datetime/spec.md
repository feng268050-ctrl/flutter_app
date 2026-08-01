# linux-datetime Specification

## Purpose

Reusable Dart `DateTimeController` for wall clock, timezone, sync mode (manual / network; default network), OS NTP via `setSyncMode`/`applyPersistedSyncMode`, one-shot ladder + primary link-up, and external RTC persist (`hwclock -f /dev/rtc0`).
## Requirements
### Requirement: Abstract date/time controller

The HMI SHALL provide a reusable Dart `DateTimeController` (name may vary) that exposes wall-clock get/set, timezone get/set, sync mode get/set (`manual` | `network`), and network time sync. Callers (Demo and later product Settings) MUST depend on the abstract API. Linux SHALL implement the controller via system tools (`date` / `timedatectl` / `hwclock`) and the shared network sync helper path. Unit-testable fakes MUST be sufficient for host tests without a board. Default sync mode when no preference exists SHALL be **`network`** (Settings Automatic on). On ynh960, offline wall clock SHALL use the external PCF8563 RTC (not the RK809 PMIC RTC); network NTP MUST NOT be required for offline operation, but SHALL be enabled by default when the device can reach NTP.

#### Scenario: Default sync mode is network

- **WHEN** no persisted sync-mode preference exists
- **THEN** `getSyncMode` returns `network`

#### Scenario: Sync mode persists

- **WHEN** the caller sets sync mode to `manual` and later restarts the HMI process
- **THEN** `getSyncMode` returns `manual`

### Requirement: Manual wall-clock set

The controller SHALL allow setting the system wall clock from a civil date/time and SHALL persist the value to the hardware RTC via `hwclock -f /dev/rtc0` when `hwclock` is available. Applying a manual wall-clock set SHALL disable OS NTP before writing time, then set sync mode to `manual` (which keeps NTP off). Failures SHALL return a structured error and MUST NOT terminate the Flutter process.

#### Scenario: Manual set updates system time

- **WHEN** the caller sets a valid wall-clock time in manual flow
- **THEN** a subsequent `now()` (or OS `date`) reflects that time within a small tolerance (e.g. a few seconds)

#### Scenario: Manual set writes RTC when possible

- **WHEN** a manual set succeeds and `hwclock` is available
- **THEN** the implementation attempts `hwclock -f /dev/rtc0` write so a later reboot can restore the time

#### Scenario: Manual set switches mode to manual

- **WHEN** the caller successfully applies a manual wall-clock set while mode was `network`
- **THEN** persisted sync mode becomes `manual`
- **AND** OS NTP is disabled

### Requirement: Manual sync mode disables OS NTP

When sync mode is `manual`, Linux SHALL disable OS NTP (`timedatectl set-ntp false` or equivalent) so timesyncd does not overwrite the operator-set time. TLS emergency one-shot sync (`ensureSaneForTls`) MUST still be allowed without changing persisted mode.

#### Scenario: Manual mode turns NTP off

- **WHEN** the caller sets sync mode to `manual`
- **THEN** OS NTP is disabled and a subsequent `timedatectl` (or equivalent) shows NTP inactive

### Requirement: Timezone get and set

The controller SHALL get and set a timezone identifier. Linux SHOULD use IANA names when zoneinfo/`tzdata` is present (at least `UTC` and `Asia/Shanghai` for ynh960). The preferred timezone SHALL be persisted in `/var/lib/hal/datetime.conf` under key `timezone` (mouse-style `key=value`, upsert preserves sibling keys such as `sync_mode`). If full zoneinfo is unavailable, the implementation MUST document the fallback and still accept the curated Demo identifiers without crashing.

#### Scenario: Timezone preference persists

- **WHEN** the caller sets timezone to `Asia/Shanghai` and restarts the HMI process
- **THEN** `getTimezone` returns `Asia/Shanghai` (or the documented equivalent token) and `/var/lib/hal/datetime.conf` contains `timezone=Asia/Shanghai`

### Requirement: Sync mode and timezone share datetime.conf

Linux datetime preferences SHALL persist in a single file `/var/lib/hal/datetime.conf` with keys:

- `sync_mode` — `manual` | `network` (default `network` when absent)
- `timezone` — IANA timezone id (empty/missing falls through to timedatectl / `UTC` as today)
- `ntp_server` — primary NTP hostname from the curated preset catalog (default `pool.ntp.org` when absent/unknown)
- `auto_timezone` — `0` | `1` (default off when absent)
- `use_24h` — `0` | `1` (default on when absent; App display preference only)

HAL MUST NOT use standalone `time-sync-mode` or `timezone` files (under `/var/lib/hal/` or legacy `/var/lib/hmi/`) as the primary write path. When `datetime.conf` is missing both keys but a legacy file exists under `/var/lib/hal/` or `/var/lib/hmi/`, the controller SHALL one-shot import that value into `/var/lib/hal/datetime.conf` before serving reads/writes.

#### Scenario: Sync mode persists in datetime.conf

- **WHEN** the caller sets sync mode to `manual`
- **THEN** `/var/lib/hal/datetime.conf` contains `sync_mode=manual` and a later `getSyncMode` returns `manual`

#### Scenario: Upsert preserves sibling key

- **WHEN** `datetime.conf` already has `timezone=Asia/Shanghai` and the caller sets sync mode to `manual`
- **THEN** the file still contains `timezone=Asia/Shanghai` and `sync_mode=manual`

#### Scenario: Legacy files migrate once

- **WHEN** `/var/lib/hal/datetime.conf` is absent, a legacy `/var/lib/hmi/time-sync-mode` contains `manual`, and `/var/lib/hmi/timezone` contains `UTC`
- **THEN** the first datetime get or set creates `/var/lib/hal/datetime.conf` with `sync_mode=manual` and `timezone=UTC`

### Requirement: Network time sync

When sync mode is `network` (the product default when prefs are absent), Linux SHALL enable OS NTP via `systemd-timesyncd` through `setSyncMode(network)` and HMI/HAL bring-up `applyPersistedSyncMode` (`timedatectl set-ntp true` or equivalent; soft-fail if absent). `syncFromNetwork` / Sync Now SHALL run the one-shot ladder only and MUST NOT itself toggle OS NTP. The primary NTP server SHALL be the persisted `ntp_server` preference (default `pool.ntp.org`); Linux SHALL write `/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf` with `NTP=<primary>` and `FallbackNTP=` remaining curated presets, then restart timesyncd (soft-fail if absent). The image seed `10-appliance.conf` (pool → Cloudflare → Google → Aliyun) covers first boot before App runs. For immediate correction (explicit Sync Now / Settings Automatic toggle, primary link-up while Automatic, or TLS emergency when the UTC year is before 2025), the controller SHALL attempt the shared one-shot ladder: existing board helper (`sync-time` / successor) if present, else `rdate`, else HTTP `Date` header parsing, then write RTC via `hwclock -f /dev/rtc0` when available. Sync SHALL be best-effort: failure returns a structured result and MUST NOT crash the HMI. When `onlyIfStale` is requested, sync MAY no-op if the UTC year is already in the sane window (2025–2030 inclusive). Offline wall clock MUST remain correct via the external RTC when NTP is unreachable.

#### Scenario: Sync Now succeeds with connectivity

- **WHEN** network connectivity can reach a sync source and the user/API requests `syncFromNetwork`
- **THEN** the wall clock becomes sane (UTC year ≥ 2025) and the result reports success

#### Scenario: Sync fails without connectivity

- **WHEN** no sync source is reachable
- **THEN** the result reports failure/error and the HMI remains running

#### Scenario: Stale-only skip when already sane

- **WHEN** `syncFromNetwork(onlyIfStale: true)` is called and the UTC year is already in 2025–2030
- **THEN** the implementation MUST NOT churn network sync and reports success (or no-op success)

#### Scenario: Network mode enables OS NTP

- **WHEN** sync mode is set to `network` (or bring-up applies persisted `network` / default with no prefs)
- **THEN** the implementation enables OS NTP (`timedatectl set-ntp true` or equivalent)

#### Scenario: Link-up triggers immediate one-shot sync when Automatic

- **WHEN** sync mode is `network` and the **primary** network (product [PrimaryNetworkController] / `/var/lib/network/primary.conf`, else lowest board `route_metrics`) gains a usable IPv4 address (offline → online)
- **THEN** the implementation attempts `syncFromNetwork` without requiring a stale UTC year
- **AND** Manual sync mode MUST NOT trigger that link-up sync
- **AND** a non-primary interface gaining IPv4 (e.g. camera Ethernet) MUST NOT trigger that sync

### Requirement: Offline external RTC without NTP

Linux on ynh960 SHALL persist and restore wall clock via the external PCF8563-compatible RTC (`rtc0` after DT bind and with `CONFIG_RTC_DRV_RK808` unset) without requiring NTP or the RK809 PMIC RTC. The image SHALL enable `rtc-systohc.timer` whose service runs `hwclock -w -u -f /dev/rtc0`.

#### Scenario: rtc-systohc timer enabled

- **WHEN** the appliance image is built
- **THEN** `rtc-systohc.timer` is enabled by preset
- **AND** `rtc-systohc.service` runs `hwclock -w -u -f /dev/rtc0`

### Requirement: Appliance NTP seed drop-in

The image SHALL ship `etc/systemd/timesyncd.conf.d/10-appliance.conf` with primary `NTP=pool.ntp.org` and `FallbackNTP` ordered Cloudflare → Google → Aliyun. Runtime curated preference overrides via `20-hmi-ntp.conf` as described under Network time sync / Curated NTP server preference.

#### Scenario: Seed prefers pool then Cloudflare Google Aliyun

- **WHEN** the rootfs overlay timesyncd seed drop-in is inspected
- **THEN** it lists `pool.ntp.org` as primary NTP and Cloudflare, Google, and Aliyun as fallbacks in that order

### Requirement: Product selects primary network role

HAL network SHALL expose get/set for the product primary uplink as a [NetRole] (`wifi.station` / `ethernet.primary`), persisted under `/var/lib/network/primary.conf`. Setting primary SHALL update effective RouteMetric (primary preferred, others secondary) so OS routing matches. Board `route_metrics` remain defaults only when the product preference is absent.

#### Scenario: Product sets ethernet as primary

- **WHEN** the product App calls `setPrimaryRole(ethernet.primary)` on a board that maps that role to an iface
- **THEN** a later `getPrimaryRole` returns `ethernet.primary` and ranked primary iface is that ethernet iface

### Requirement: TLS emergency sync respects survival over mode purity

The controller SHALL provide an `ensureSaneForTls` (name may vary) entry used by HTTPS clients. When the UTC year is before 2025, it MUST attempt network sync even if persisted mode is `manual`, and MUST NOT change the persisted sync mode solely because of that emergency sync.

#### Scenario: Emergency sync while manual

- **WHEN** sync mode is `manual` and UTC year is before 2025 and `ensureSaneForTls` is invoked
- **THEN** the implementation attempts network sync and leaves persisted mode as `manual`

### Requirement: Curated NTP server preference

`DateTimeController` SHALL expose a curated NTP preset list and get/set for the primary `ntp_server` id (hostname). Unknown or empty preference SHALL normalize to `pool.ntp.org`. Setting the preference SHALL persist `ntp_server` in `/var/lib/hal/datetime.conf` and apply the timesyncd drop-in described under Network time sync. Settings Automatic MAY surface a server picker when sync mode is `network`.

#### Scenario: Default NTP server is pool.ntp.org

- **WHEN** no `ntp_server` preference exists
- **THEN** `getNtpServerId` returns `pool.ntp.org`

#### Scenario: Selecting Cloudflare writes drop-in

- **WHEN** the caller sets NTP server id to `time.cloudflare.com`
- **THEN** `/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf` contains `NTP=time.cloudflare.com` and `FallbackNTP` listing the other curated presets including `pool.ntp.org`

### Requirement: Automatic timezone from IP geolocation

`DateTimeController` SHALL persist `auto_timezone` (`0`|`1`, default off) and expose get/set plus `syncTimezoneFromNetwork`. Enabling auto timezone SHALL attempt IP-based timezone detection over HTTP first (e.g. ip-api.com), with optional HTTPS fallback, and apply `setTimezone` on success. Failure MUST leave the current timezone unchanged, MUST NOT flip `auto_timezone` off, and MUST return a structured failure. Bring-up and primary link-up MAY call `syncTimezoneFromNetwork` when `auto_timezone=1`. Settings SHALL hide or disable the manual Time Zone row while auto timezone is on. GPS/GNSS is out of scope.

#### Scenario: Auto timezone defaults off

- **WHEN** no `auto_timezone` preference exists
- **THEN** `getAutoTimezone` returns false

#### Scenario: Enable auto timezone applies geo zone

- **WHEN** the caller enables auto timezone and a geo API returns an IANA zone
- **THEN** the system timezone becomes that zone and `auto_timezone=1` is persisted

#### Scenario: Geo failure keeps preference and zone

- **WHEN** auto timezone is enabled and geo lookup fails
- **THEN** `auto_timezone` remains enabled, timezone is unchanged, and the result reports failure

### Requirement: 24-hour display preference

`DateTimeController` SHALL persist `use_24h` (`0`|`1`, default on) for App clock display. This preference MUST NOT change the OS locale or NTP behavior.

#### Scenario: Default is 24-hour

- **WHEN** no `use_24h` preference exists
- **THEN** `getUse24HourFormat` returns true

