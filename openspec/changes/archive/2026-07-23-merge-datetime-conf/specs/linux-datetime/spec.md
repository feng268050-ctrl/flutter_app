## MODIFIED Requirements

### Requirement: Timezone get and set

The controller SHALL get and set a timezone identifier. Linux SHOULD use IANA names when zoneinfo/`tzdata` is present (at least `UTC` and `Asia/Shanghai` for ynh960). The preferred timezone SHALL be persisted in `/var/lib/hmi/datetime.conf` under key `timezone` (mouse-style `key=value`, upsert preserves sibling keys such as `sync_mode`). If full zoneinfo is unavailable, the implementation MUST document the fallback and still accept the curated Demo identifiers without crashing.

#### Scenario: Timezone preference persists

- **WHEN** the caller sets timezone to `Asia/Shanghai` and restarts the HMI process
- **THEN** `getTimezone` returns `Asia/Shanghai` (or the documented equivalent token) and `/var/lib/hmi/datetime.conf` contains `timezone=Asia/Shanghai`

## ADDED Requirements

### Requirement: Sync mode and timezone share datetime.conf

Linux datetime preferences SHALL persist in a single file `/var/lib/hmi/datetime.conf` with keys:

- `sync_mode` — `manual` | `network` (default `network` when absent)
- `timezone` — IANA timezone id (empty/missing falls through to timedatectl / `UTC` as today)

HAL MUST NOT use standalone `/var/lib/hmi/time-sync-mode` or `/var/lib/hmi/timezone` as the primary write path after this change. When `datetime.conf` is missing both keys but a legacy file exists, the controller SHALL one-shot import that value into the conf before serving reads/writes.

#### Scenario: Sync mode persists in datetime.conf

- **WHEN** the caller sets sync mode to `manual`
- **THEN** `/var/lib/hmi/datetime.conf` contains `sync_mode=manual` and a later `getSyncMode` returns `manual`

#### Scenario: Upsert preserves sibling key

- **WHEN** `datetime.conf` already has `timezone=Asia/Shanghai` and the caller sets sync mode to `manual`
- **THEN** the file still contains `timezone=Asia/Shanghai` and `sync_mode=manual`

#### Scenario: Legacy files migrate once

- **WHEN** `datetime.conf` is absent, `/var/lib/hmi/time-sync-mode` contains `manual`, and `/var/lib/hmi/timezone` contains `UTC`
- **THEN** the first datetime get or set creates `/var/lib/hmi/datetime.conf` with `sync_mode=manual` and `timezone=UTC`
