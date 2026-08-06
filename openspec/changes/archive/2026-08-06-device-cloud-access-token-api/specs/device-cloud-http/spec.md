## ADDED Requirements

### Requirement: Device Worker HTTP SHALL attach device access_token when available

Product cloud REST calls that identify the device by SN against the pinned Worker origin (including **`GET /v1/devices/:sn/users`**, **`POST /v1/devices/:sn/ai-report`**, and device-mode **`POST /v1/storage/r2/sts`**) SHALL include **`Authorization: Bearer <access_token>`** when **`device-cloud-access-token-api`** has a usable token. Paths SHALL remain under **`/v1/...`**.

#### Scenario: STS device mode sends Bearer

- **WHEN** the App requests R2 STS for device upload and a device token is available
- **THEN** **`POST /v1/storage/r2/sts`** SHALL include the Bearer header along with body **`sn`**
