## MODIFIED Requirements

### Requirement: OTA WebSocket protocol with unified apply

`command.check_update` and `command.update_system` SHALL be handled by the whole-device OTA pipeline (`cyber_ota`). Acknowledgements MUST use lws-ui-shaped `payload.data` (`ok`, optional `has_update`/`manifest`/`started`, `error_code`, `error_message`).

- **`command.check_update`:** SHALL run a manifest/version check without writing partitions, fetching the App-resolved cloud channel URL (or an explicit `manifest_url` in the payload when provided). The fetched document MUST be parsed with the same channel rules as Settings (`url` or `package_url`). On success `ok` is true and `has_update` / optional `manifest` reflect the result; on failure `ok` is false with an appropriate `error_code` (not the permanent `ota_not_supported` stub once OTA is enabled on the image).
- **`command.update_system`:** when an update may start, SHALL start (or continue) the unified session (safe shutdown → dedicated **upgrade progress page** (CyberUI-styled) → OTA `tar.gz` download → package verify → extract → apply) per product confirmation policy; payload MAY supply a manifest object using `url` or `package_url`. On acceptance `ok` is true and `started` may be true; failures use `error_code` / `error_message`.
- The system SHALL emit `device.update_progress` frames while a real upgrade session is transferring or writing, mapping `cyber_ota` progress phases (`transferring` = download progress for the package). The system MUST NOT emit `device.update_progress` when no upgrade pipeline is running.

#### Scenario: check_update reports availability

- **WHEN** `command.check_update` is received and the OTA client can reach the channel manifest
- **THEN** the device MUST reply `command.check_update_ack` with `data.ok` true and `data.has_update` set according to version compare
- **AND** MUST NOT write partitions as a side effect of check-only

#### Scenario: check_update accepts publish-shaped url

- **WHEN** `command.check_update` fetches a channel JSON that provides `url` without `package_url` and the remote version is newer
- **THEN** the ack MAY include a manifest usable for a subsequent update
- **AND** `data.has_update` is true

#### Scenario: update_system starts apply pipeline

- **WHEN** `command.update_system` is received and a newer package is available (and policy allows start)
- **THEN** the device MUST reply with `data.ok` true and begin or queue the unified OTA session
- **AND** MUST emit `device.update_progress` during transfer and/or write

#### Scenario: OTA failure uses structured error

- **WHEN** check or update fails (network, verify, or apply)
- **THEN** the corresponding ack MUST set `data.ok` false with a non-empty `error_code` suitable for clients
- **AND** MUST NOT claim partitions were updated
