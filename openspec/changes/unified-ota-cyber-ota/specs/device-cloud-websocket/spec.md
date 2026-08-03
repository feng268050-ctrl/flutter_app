## REMOVED Requirements

### Requirement: OTA WebSocket protocol without apply
**Reason:** Whole-device OTA is now in scope; check/update commands must drive `cyber_ota` instead of permanent `ota_not_supported` stubs.
**Migration:** Use the added “OTA WebSocket protocol with unified apply” requirement.

## ADDED Requirements

### Requirement: OTA WebSocket protocol with unified apply

`command.check_update` and `command.update_system` SHALL be handled by the whole-device OTA pipeline (`cyber_ota`). Acknowledgements MUST use lws-ui-shaped `payload.data` (`ok`, optional `has_update`/`manifest`/`started`, `error_code`, `error_message`).

- **`command.check_update`:** SHALL run a manifest/version check without writing partitions; on success `ok` is true and `has_update` / optional `manifest` reflect the result; on failure `ok` is false with an appropriate `error_code` (not the permanent `ota_not_supported` stub once OTA is enabled on the image).
- **`command.update_system`:** when an update may start, SHALL start (or continue) download+verify+apply per product confirmation policy; on acceptance `ok` is true and `started` may be true; failures use `error_code` / `error_message`.
- The system SHALL emit `device.update_progress` frames while a real upgrade session is transferring or writing, mapping `cyber_ota` progress phases. The system MUST NOT emit `device.update_progress` when no upgrade pipeline is running.

#### Scenario: check_update reports availability

- **WHEN** `command.check_update` is received and the OTA client can reach the manifest
- **THEN** the device MUST reply `command.check_update_ack` with `data.ok` true and `data.has_update` set according to version compare
- **AND** MUST NOT write partitions as a side effect of check-only

#### Scenario: update_system starts apply pipeline

- **WHEN** `command.update_system` is received and a newer package is available (and policy allows start)
- **THEN** the device MUST reply with `data.ok` true and begin or queue the unified OTA session
- **AND** MUST emit `device.update_progress` during transfer and/or write

#### Scenario: OTA failure uses structured error

- **WHEN** check or update fails (network, verify, or apply)
- **THEN** the corresponding ack MUST set `data.ok` false with a non-empty `error_code` suitable for clients
- **AND** MUST NOT claim partitions were updated
