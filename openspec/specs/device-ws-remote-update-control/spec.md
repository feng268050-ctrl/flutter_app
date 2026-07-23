## ADDED Requirements

### Requirement: Device SHALL handle remote update-check command over WebSocket
The device MUST listen for `command.check_update` messages on the existing WS command channel and trigger local update-check logic when received.

`command.check_update_ack` responses MUST include `request_id` matching the incoming command envelope id, and `data` MUST include `ok` and `has_update`.  
When `has_update=true`, the ack data MUST include update manifest metadata required for subsequent upgrade start (version, filename, published_at, sha512, url).  
When the check fails, the ack data MUST include explicit error details (`error_code` and/or `error_message`).

#### Scenario: Check update success with new version
- **WHEN** device receives `command.check_update`, check succeeds, and a newer version is available
- **THEN** device SHALL send `command.check_update_ack` with matching `request_id`, `ok=true`, `has_update=true`, and manifest metadata

#### Scenario: Check update success without new version
- **WHEN** device receives `command.check_update` and check succeeds with no newer version
- **THEN** device SHALL send `command.check_update_ack` with matching `request_id`, `ok=true`, and `has_update=false`

#### Scenario: Check update failure
- **WHEN** device receives `command.check_update` but local check execution fails
- **THEN** device SHALL send `command.check_update_ack` with matching `request_id`, `ok=false`, and error details

### Requirement: Device SHALL acknowledge update-system command without waiting for completion
The device MUST listen for `command.update_system` messages and attempt to start system/software update flow immediately.

`command.update_system_ack` MUST be returned promptly and MUST only represent command acceptance outcome:
- accepted/start initiated: `ok=true`, `started=true`
- rejected/start failed: `ok=false`, `started=false`, with optional `error_code`/`error_message`

The ack MUST NOT be delayed until download/install/upgrade completion.

#### Scenario: Update command accepted
- **WHEN** device receives `command.update_system` and local preconditions allow starting update flow
- **THEN** device SHALL send `command.update_system_ack` with matching `request_id`, `ok=true`, and `started=true`

#### Scenario: Update command rejected
- **WHEN** device receives `command.update_system` but update flow cannot be started
- **THEN** device SHALL send `command.update_system_ack` with matching `request_id`, `ok=false`, `started=false`, and error details when available

### Requirement: Device SHALL serialize conflicting update-system requests
If an update execution is already in progress, additional `command.update_system` requests MUST NOT start a parallel update flow.

#### Scenario: Duplicate update request while updating
- **WHEN** device receives `command.update_system` during an ongoing update execution
- **THEN** device SHALL return `command.update_system_ack` indicating command rejection and keep the current update flow unchanged
