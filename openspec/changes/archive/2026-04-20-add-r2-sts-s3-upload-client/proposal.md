## Why

The app needs to upload objects to Cloudflare R2 using **temporary S3-compatible credentials** from the backend, instead of (or alongside) presigned URLs or legacy OSS flows. A dedicated **`POST /v1/storage/r2/sts`** contract returns STS fields wrapped in **`ApiResult`**, enabling a standard **`@aws-sdk/client-s3`** (or equivalent) client with `sessionToken`, endpoint, bucket, and region **`auto`**.

## What Changes

- Add an HTTP client path that calls **`POST /v1/storage/r2/sts`** with JSON body **`{ "sn": "<device SN>", "ttl_seconds": <int> }`** (e.g. `900`), aligned with existing **`ApiResult`** parsing conventions.
- On success, build an **S3 client** (or factory) from **`access_key_id`**, **`secret_access_key`**, **`session_token`**, **`endpoint_url`**, **`bucket`**, **`region`** (`"auto"`), and **`expires_at`** (Unix ms) for credential lifetime awareness.
- Add **structured logging** indicating whether STS authorization was obtained and whether the S3 client was constructed successfully (without logging secrets).
- Ensure **S3 SDK dependencies** are present in the Android module (Gradle); add them if missing.

## Capabilities

### New Capabilities

- `storage-r2-sts-s3-client`: Contract for **`POST /v1/storage/r2/sts`**, **`ApiResult`** success/failure shape for `data`, credential field names, logging expectations for auth/client readiness, and dependency notes for AWS SDK v3 S3 on Android/JVM.

### Modified Capabilities

- (none) — existing R2 presigned-upload spec remains valid for the presigned path; STS S3 is a separate capability unless a later change unifies them at the requirement level.

## Impact

- **App**: New or extended API interface (Retrofit/OkHttp), STS response DTOs, S3 client wrapper/factory, logging (e.g. Timber / project logger), and call sites that need R2 uploads via STS.
- **Dependencies**: **`@aws-sdk/client-s3`** (and related auth/runtime modules as required for the project’s Kotlin/Java setup).
- **Backend**: Assumes **`/v1/storage/r2/sts`** returns the documented `data` fields on success and **`message`** on failure per **`ApiResult`**.
