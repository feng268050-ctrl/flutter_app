## MODIFIED Requirements

### Requirement: Network time sync

When sync mode is `network`, or when the caller explicitly requests sync, Linux SHALL keep OS NTP enabled via `systemd-timesyncd` (`timedatectl set-ntp true` or equivalent) so the clock is corrected continuously while the network can reach NTP. For immediate correction (explicit Sync Now, or TLS emergency when the UTC year is before 2025), the controller SHALL still attempt the shared one-shot ladder: existing board helper (`sync-time` / successor) if present, else `rdate`, else HTTP `Date` header parsing, then write RTC via `hwclock` when available. Sync SHALL be best-effort: failure returns a structured result and MUST NOT crash the HMI. When `onlyIfStale` is requested, the one-shot ladder MAY no-op if the UTC year is already in the sane window (2025–2030 inclusive). Continuous drift correction MUST NOT rely solely on the one-shot ladder.

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

- **WHEN** sync mode is set to `network` (or defaults to `network` with timesyncd present)
- **THEN** the implementation enables OS NTP (`timedatectl set-ntp true` or equivalent) so `systemd-timesyncd` can synchronize the clock

## ADDED Requirements

### Requirement: Manual sync mode disables OS NTP

When sync mode is `manual`, or when a successful manual wall-clock set switches mode to `manual`, Linux SHALL disable OS NTP (`timedatectl set-ntp false` or equivalent) so timesyncd does not overwrite the operator-set time. TLS emergency one-shot sync MUST still be allowed without changing persisted mode (existing `ensureSaneForTls` behavior).

#### Scenario: Manual mode turns NTP off

- **WHEN** the caller sets sync mode to `manual`
- **THEN** OS NTP is disabled and a subsequent `timedatectl` (or equivalent) shows NTP inactive

#### Scenario: Manual wall-clock set turns NTP off

- **WHEN** the caller successfully applies a manual wall-clock set
- **THEN** persisted sync mode is `manual` and OS NTP is disabled
