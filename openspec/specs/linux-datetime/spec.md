# linux-datetime Specification

## Purpose

Reusable Dart `DateTimeController` for wall clock, timezone, sync mode (manual / network), and network time sync (rdate / HTTP Date / `wlan0-time-sync.sh` + RTC), shared by Demo and later product Settings.
## Requirements
### Requirement: Abstract date/time controller

The HMI SHALL provide a reusable Dart `DateTimeController` (name may vary) that exposes wall-clock get/set, timezone get/set, sync mode get/set (`manual` | `network`), and network time sync. Callers (Demo and later product Settings) MUST depend on the abstract API. Linux SHALL implement the controller via system tools (`date` / `timedatectl` / `hwclock`) and the shared network sync helper path. Unit-testable fakes MUST be sufficient for host tests without a board.

#### Scenario: Default sync mode is network

- **WHEN** no persisted sync-mode preference exists
- **THEN** `getSyncMode` returns `network`

#### Scenario: Sync mode persists

- **WHEN** the caller sets sync mode to `manual` and later restarts the HMI process
- **THEN** `getSyncMode` returns `manual`

### Requirement: Manual wall-clock set

The controller SHALL allow setting the system wall clock from a civil date/time and SHALL persist the value to the hardware RTC when `hwclock` is available. Applying a manual wall-clock set SHALL set sync mode to `manual`. Failures SHALL return a structured error and MUST NOT terminate the Flutter process.

#### Scenario: Manual set updates system time

- **WHEN** the caller sets a valid wall-clock time in manual flow
- **THEN** a subsequent `now()` (or OS `date`) reflects that time within a small tolerance (e.g. a few seconds)

#### Scenario: Manual set writes RTC when possible

- **WHEN** a manual set succeeds and `hwclock` is available
- **THEN** the implementation attempts `hwclock` write so a later reboot can restore the time

#### Scenario: Manual set switches mode to manual

- **WHEN** the caller successfully applies a manual wall-clock set while mode was `network`
- **THEN** persisted sync mode becomes `manual`

### Requirement: Timezone get and set

The controller SHALL get and set a timezone identifier. Linux SHOULD use IANA names when zoneinfo/`tzdata` is present (at least `UTC` and `Asia/Shanghai` for ynh960). The preferred timezone SHALL be persisted in `/var/lib/hal/datetime.conf` under key `timezone` (mouse-style `key=value`, upsert preserves sibling keys such as `sync_mode`). If full zoneinfo is unavailable, the implementation MUST document the fallback and still accept the curated Demo identifiers without crashing.

#### Scenario: Timezone preference persists

- **WHEN** the caller sets timezone to `Asia/Shanghai` and restarts the HMI process
- **THEN** `getTimezone` returns `Asia/Shanghai` (or the documented equivalent token) and `/var/lib/hal/datetime.conf` contains `timezone=Asia/Shanghai`

### Requirement: Sync mode and timezone share datetime.conf

Linux datetime preferences SHALL persist in a single file `/var/lib/hal/datetime.conf` with keys:

- `sync_mode` — `manual` | `network` (default `network` when absent)
- `timezone` — IANA timezone id (empty/missing falls through to timedatectl / `UTC` as today)

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

When sync mode is `network`, or when the caller explicitly requests sync, the controller SHALL attempt to obtain time from the network using the shared ladder: existing board helper (`wlan0-time-sync.sh` or successor) if present, else `rdate`, else HTTP `Date` header parsing, then write RTC via `hwclock` when available. Sync SHALL be best-effort: failure returns a structured result and MUST NOT crash the HMI. When `onlyIfStale` is requested, sync MAY no-op if the UTC year is already in the sane window (2025–2030 inclusive, matching the board helper).

#### Scenario: Sync Now succeeds with connectivity

- **WHEN** network connectivity can reach a sync source and the user/API requests `syncFromNetwork`
- **THEN** the wall clock becomes sane (UTC year ≥ 2025) and the result reports success

#### Scenario: Sync fails without connectivity

- **WHEN** no sync source is reachable
- **THEN** the result reports failure/error and the HMI remains running

#### Scenario: Stale-only skip when already sane

- **WHEN** `syncFromNetwork(onlyIfStale: true)` is called and the UTC year is already in 2025–2030
- **THEN** the implementation MUST NOT churn network sync and reports success (or no-op success)

### Requirement: TLS emergency sync respects survival over mode purity

The controller SHALL provide an `ensureSaneForTls` (name may vary) entry used by HTTPS clients. When the UTC year is before 2025, it MUST attempt network sync even if persisted mode is `manual`, and MUST NOT change the persisted sync mode solely because of that emergency sync.

#### Scenario: Emergency sync while manual

- **WHEN** sync mode is `manual` and UTC year is before 2025 and `ensureSaneForTls` is invoked
- **THEN** the implementation attempts network sync and leaves persisted mode as `manual`

