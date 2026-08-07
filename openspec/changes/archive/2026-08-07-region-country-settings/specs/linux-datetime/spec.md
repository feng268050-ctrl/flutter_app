## MODIFIED Requirements

### Requirement: Sync mode and timezone share datetime.conf

Linux datetime preferences SHALL persist in a single file `/var/lib/hal/datetime.conf` with keys:

- `sync_mode` — `manual` | `network` (default `network` when absent)
- `timezone` — IANA timezone id (empty/missing falls through to timedatectl / product Country default via App region apply, else `UTC`)
- `ntp_server` — primary NTP hostname from the curated preset catalog (default `pool.ntp.org` when absent/unknown)
- `auto_timezone` — `0` | `1` (default off when absent)
- `use_24h` — `0` | `1` (default on when absent; App display preference only)

HAL MUST NOT use standalone `time-sync-mode` or `timezone` files (under `/var/lib/hal/` or legacy `/var/lib/hmi/`) as the primary write path. When `datetime.conf` is missing both keys but a legacy file exists under `/var/lib/hal/` or `/var/lib/hmi/`, the controller SHALL one-shot import that value into `/var/lib/hal/datetime.conf` before serving reads/writes. Product Country region apply MAY write `timezone` and `ntp_server` according to Country-linked default rules; manual Date & Time Settings remain authoritative afterward.

#### Scenario: Sync mode persists in datetime.conf

- **WHEN** the caller sets sync mode to `manual`
- **THEN** `/var/lib/hal/datetime.conf` contains `sync_mode=manual` and a later `getSyncMode` returns `manual`

#### Scenario: Upsert preserves sibling key

- **WHEN** `datetime.conf` already has `timezone=Asia/Shanghai` and the caller sets sync mode to `manual`
- **THEN** the file still contains `timezone=Asia/Shanghai` and `sync_mode=manual`

#### Scenario: Legacy files migrate once

- **WHEN** `/var/lib/hal/datetime.conf` is absent, a legacy `/var/lib/hmi/time-sync-mode` contains `manual`, and `/var/lib/hmi/timezone` contains `UTC`
- **THEN** the first datetime get or set creates `/var/lib/hal/datetime.conf` with `sync_mode=manual` and `timezone=UTC`

### Requirement: Curated NTP server preference

`DateTimeController` SHALL expose a curated NTP preset list and get/set for the primary `ntp_server` id (hostname). Unknown or empty preference SHALL normalize to `pool.ntp.org`. Setting the preference SHALL persist `ntp_server` in `/var/lib/hal/datetime.conf` and apply the timesyncd drop-in described under Network time sync. Settings Automatic MAY surface a server picker when sync mode is `network`. Product Country region apply MAY set the primary NTP from the Country → preferred-NTP table; Country-driven defaults MUST NOT select `cn.pool.ntp.org` (that preset MAY remain available for manual operator selection).

#### Scenario: Default NTP server is pool.ntp.org

- **WHEN** no `ntp_server` preference exists
- **THEN** `getNtpServerId` returns `pool.ntp.org`

#### Scenario: Selecting Cloudflare writes drop-in

- **WHEN** the caller sets NTP server id to `time.cloudflare.com`
- **THEN** `/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf` contains `NTP=time.cloudflare.com` and `FallbackNTP` listing the other curated presets including `pool.ntp.org`

#### Scenario: Country-driven default avoids China pool

- **WHEN** Country region apply sets NTP for Country `US` or a curated European country with no operator override
- **THEN** primary NTP is not `cn.pool.ntp.org`
