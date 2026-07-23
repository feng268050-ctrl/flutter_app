## 1. Dependencies

- [x] 1.1 Confirm the `app` module (or target module) has no existing S3 client dependency; if absent, add AWS SDK v3 artifacts required for `S3Client` with session credentials (`software.amazon.awssdk:s3`, `auth`, and any BOM/version alignment used elsewhere in the repo).
- [x] 1.2 Sync Gradle and fix any minSdk / desugaring / R8 issues introduced by the new dependencies.

## 2. API models and HTTP call

- [x] 2.1 Add a request DTO for `POST /v1/storage/r2/sts` with `sn` and `ttl_seconds` (JSON field names as per API).
- [x] 2.2 Add a response type compatible with `ApiResult` (reuse or extend existing `ApiResult` patterns) and a `data` DTO for `access_key_id`, `secret_access_key`, `session_token`, `expires_at`, `endpoint_url`, `bucket`, `region`.
- [x] 2.3 Implement the HTTP client for `/v1/storage/r2/sts` using `DeviceApiOriginConfig.joinUnderBase` (or equivalent) for the path, POST JSON body, and parse the envelope using `success === true` as the only success signal.

## 3. S3 client construction

- [x] 3.1 Implement a small factory or builder that, given successful STS `data`, constructs a configured `S3Client` with endpoint override, region `auto`, and `AwsSessionCredentials` (access key, secret key, session token).
- [x] 3.2 Expose `bucket` and `expires_at` to callers (return type or side-car object) for subsequent `PutObject` / upload calls.

## 4. Logging and tests

- [x] 4.1 Add logs for STS fetch outcome (success vs failure; no secrets) and S3 client creation outcome (success vs failure with safe error classification).
- [x] 4.2 Add unit tests for JSON parsing of success and failure `ApiResult` bodies for the STS endpoint (mirror `ApiResultTest` / `PresignPutApiResultParseTest` style).
