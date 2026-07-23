## ADDED Requirements

### Requirement: WebSocket process parameter success notifies operator

When the device successfully persists an inbound `command.send_process_param` over WebSocket, the ingestion path SHALL trigger the operator-facing received-parameter confirmation dialog defined in **`remote-process-param-received-dialog`**, in addition to existing telemetry and ack behavior. Notification MUST occur only on successful persistence, not on validation or processing failure.

#### Scenario: Success path triggers UI notification

- **WHEN** `handleInboundSendProcessParam` completes persistence successfully
- **THEN** the system MUST schedule the received-parameter dialog on the main thread
- **AND** MUST still emit success telemetry and send `command.send_process_param_ack`

#### Scenario: Failure path skips UI notification

- **WHEN** `command.send_process_param` fails before or during persistence
- **THEN** the system MUST NOT schedule the received-parameter dialog
- **AND** MUST still record failure telemetry and send failure ack when applicable
