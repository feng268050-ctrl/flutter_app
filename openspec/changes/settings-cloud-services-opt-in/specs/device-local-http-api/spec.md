## MODIFIED Requirements

### Requirement: Local HTTP server bind and lifecycle

The system SHALL run an embedded HTTP server bound to `0.0.0.0:5580` **only while LAN enhancement (局域网增强) is enabled** and the application process is active. When LAN enhancement is enabled, the server SHALL start from application scope (after first frame or immediately on preference enable) and SHALL stop when LAN enhancement is disabled or the application terminates. Bind failure MUST NOT crash the process (MUST log the failure). When LAN enhancement is disabled, the system MUST NOT keep `:5580` listening. Port `8080` MUST NOT be used for new LAN integrations.

#### Scenario: Server accepts LAN connections when enhancement on

- **WHEN** LAN enhancement is enabled, the device has a LAN IP, and the local HTTP server has started successfully
- **THEN** a client MAY connect to `http://<device-lan-ip>:5580` and receive HTTP responses

#### Scenario: Bind failure is non-fatal

- **WHEN** LAN enhancement is enabled and port 5580 cannot be bound
- **THEN** the application MUST continue running
- **AND** MUST emit a diagnosable error log

#### Scenario: Disabled means not listening

- **WHEN** LAN enhancement is disabled
- **THEN** the application MUST NOT accept new connections on `:5580`
