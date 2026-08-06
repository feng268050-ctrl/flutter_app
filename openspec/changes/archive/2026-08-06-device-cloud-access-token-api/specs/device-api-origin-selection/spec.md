## ADDED Requirements

### Requirement: Device WebSocket URL path remains /ws/device under token auth

Building the device WebSocket URL from the pinned HTTP base SHALL continue to append **`/ws/device?sn=<url-encoded-device-sn>`**. Device **`access_token`** authentication SHALL be supplied via the upgrade **`Authorization`** header per **`device-cloud-access-token-api`**, not by changing the path to a v2 endpoint.

#### Scenario: URL unchanged when token auth is used

- **WHEN** the App derives the device WebSocket URL after token mint is available
- **THEN** the path SHALL still end with **`/ws/device`** and query **`sn`**
