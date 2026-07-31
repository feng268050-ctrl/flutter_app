## MODIFIED Requirements

### Requirement: R2 STS and object upload

The system SHALL obtain temporary credentials via `POST /v1/storage/r2/sts` on the pinned origin and SHALL upload objects with S3-compatible PutObject semantics for process-video **cover** (`image/jpeg`) and **media** (`video/mp4`) when an upload is requested (Monitor Upload or WebSocket). STS responses SHOULD include `public_base_url` (or camelCase equivalent); cover/video public URLs MUST be formed by joining that base with the object key. Credentials and secret keys MUST NOT be written to info-level logs.

#### Scenario: STS success yields usable credentials

- **WHEN** the pinned origin returns STS credentials
- **THEN** the client obtains access key, secret, session token, bucket, and endpoint sufficient for PutObject

#### Scenario: Cover uses public base

- **WHEN** cover PutObject succeeds and STS provided `public_base_url`
- **THEN** stored `coverUrl` MUST be that base joined with the cover object key
