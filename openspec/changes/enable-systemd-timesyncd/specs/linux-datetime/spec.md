## MODIFIED Requirements

### Requirement: Abstract date/time controller

The HMI SHALL provide a reusable Dart `DateTimeController` (name may vary) that exposes wall-clock get/set, timezone get/set, sync mode get/set (`manual` | `network`), and network time sync. Callers (Demo and later product Settings) MUST depend on the abstract API. Linux SHALL implement the controller via system tools (`date` / `timedatectl` / `hwclock` when present) and the shared network sync helper path. Unit-testable fakes MUST be sufficient for host tests without a board. Default sync mode when no preference exists SHALL be **`manual`**. On ynh960, offline wall clock SHALL use the external PCF8563 RTC (not the RK809 PMIC RTC); network NTP MUST NOT be required for normal offline operation.

#### Scenario: Default sync mode is manual

- **WHEN** no persisted sync-mode preference exists
- **THEN** `getSyncMode` returns `manual`

#### Scenario: Sync mode persists

- **WHEN** the caller sets sync mode to `network` and later restarts the HMI process
- **THEN** `getSyncMode` returns `network`

### Requirement: Network time sync

When sync mode is `network`, or when the caller explicitly requests sync, Linux SHALL enable OS NTP via `systemd-timesyncd` (`timedatectl set-ntp true` or equivalent) as an **opt-in** convenience when the network can reach NTP. For immediate correction (explicit Sync Now / Settings Automatic toggle, or TLS emergency when the UTC year is before 2025), the controller SHALL still attempt the shared one-shot ladder: existing board helper (`sync-time` / successor) if present, else `rdate`, else HTTP `Date` header parsing, then attempt `hwclock` write when a usable RTC device exists. Sync SHALL be best-effort: failure returns a structured result and MUST NOT crash the HMI. When `onlyIfStale` is requested, the one-shot ladder MAY no-op if the UTC year is already in the sane window (2025–2030 inclusive). Product wall-clock operation MUST remain correct for offline devices that never enable network sync (external RTC + manual set).

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

- **WHEN** sync mode is set to `network`
- **THEN** the implementation enables OS NTP (`timedatectl set-ntp true` or equivalent) so `systemd-timesyncd` can synchronize the clock when reachable

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

Linux on ynh960 SHALL persist and restore wall clock via the external PCF8563-compatible RTC (`rtc0` after DT bind and with `CONFIG_RTC_DRV_RK808` unset) without requiring NTP or the RK809 PMIC RTC. Manual set and optional Automatic NTP MUST still update the running system clock and write the RTC when the UTC year is sane.

#### Scenario: rtc-systohc timer enabled

- **WHEN** the appliance image is built
- **THEN** `rtc-systohc.timer` is enabled by preset
