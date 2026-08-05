## ADDED Requirements

### Requirement: Device WebSocket connect SHALL attach device access_token when available

When connecting to **`/ws/device`**, the proxy-aware WebSocket client SHALL include **`Authorization: Bearer <access_token>`** on the upgrade request when **`device-cloud-access-token-api`** has a usable token. The URL path SHALL remain **`/ws/device`** (no v2 path). Application envelope and command handling SHALL remain unchanged.

#### Scenario: Connect with Bearer

- **WHEN** a pinned origin exists, network is available, 云服务 is enabled, and a device token is available
- **THEN** the WebSocket upgrade to **`/ws/device`** MUST include the Bearer header
