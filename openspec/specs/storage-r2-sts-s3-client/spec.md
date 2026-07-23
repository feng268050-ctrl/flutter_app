## Purpose

Define the Android client contract for **R2 S3-compatible uploads** using **temporary credentials** from **`POST /v1/storage/r2/sts`**: request shape, **`ApiResult`** handling, STS **`data`** fields, S3 client configuration (including region **`auto`**), logging without secrets, and Gradle dependency expectations.

## Requirements

### Requirement: STS issuance endpoint

The client SHALL obtain R2 S3-compatible temporary credentials by issuing an HTTP **`POST`** to **`/v1/storage/r2/sts`** on the same API base URL used for other pinned **`/v1`** device API calls.

#### Scenario: Request shape

- **WHEN** the client requests STS credentials for a device
- **THEN** it SHALL send **`Content-Type: application/json`** with a JSON object containing **`sn`** (device serial) and **`ttl_seconds`** (positive integer, e.g. `900`)

### Requirement: ApiResult handling

The client SHALL interpret the response using the standard **`ApiResult`** contract: logical success SHALL be **`success === true`**; the client SHALL NOT treat HTTP status alone as success.

#### Scenario: Success envelope

- **WHEN** the HTTP response body is **`ApiResult`** with **`success`** true and **`data`** present
- **THEN** the client SHALL parse **`data`** as the STS payload fields required for S3 access

#### Scenario: Failure envelope

- **WHEN** **`success`** is false or **`data`** is unusable
- **THEN** the client SHALL surface failure using **`message`** from **`ApiResult`** where available and SHALL not treat the operation as authorized

### Requirement: STS data fields

On success, **`data`** SHALL be treated as containing at least: **`access_key_id`**, **`secret_access_key`**, **`session_token`** (maps to AWS SDK session token), **`expires_at`** (Unix epoch milliseconds), **`endpoint_url`**, **`bucket`**, and **`region`** with value **`auto`** for S3 client configuration.

#### Scenario: Field mapping for AWS SDK

- **WHEN** building an S3 client from successful STS data
- **THEN** the implementation SHALL pass **`session_token`** into the SDK as the session credentials’ session token property and SHALL use **`endpoint_url`**, **`bucket`**, and **`region`** as required by **`@aws-sdk/client-s3`**-equivalent configuration on the platform

### Requirement: Logging without secrets

The implementation SHALL log whether STS authorization succeeded and whether an S3 client was created successfully, using the project’s logging facilities.

#### Scenario: No credential leakage

- **WHEN** logging outcomes or errors for STS or S3 client setup
- **THEN** logs SHALL NOT include **`secret_access_key`**, **`session_token`**, or full **`access_key_id`** if redaction is required by policy; at minimum secrets and session tokens SHALL never appear in logs

### Requirement: S3 client dependency

If the application module does not already include an S3-compatible AWS SDK client dependency suitable for **`S3Client`** usage, the change SHALL add the minimal Gradle dependency set required to compile and run the STS-based client.

#### Scenario: Fresh module

- **WHEN** no S3 client library is present in the module’s dependencies
- **THEN** the change SHALL add the required artifacts (for example AWS SDK v3 **`s3`** and supporting **`auth`** modules) consistent with the app’s Android API level and build tooling
