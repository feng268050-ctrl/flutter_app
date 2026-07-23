## Why

Process video upload today depends on Alibaba OSS (STS from legacy HTTP base URL, SDK resumable upload, then metadata POST to stage-api). We need a path that uploads video bytes directly to **Cloudflare R2** using **presigned PUT** URLs issued by the same **Workers** hosts already used for device WebSocket, so staging and production stay aligned without hard-coding duplicate host lists.

## What Changes

- Add a client flow to call **`https://{worker-host}/upload/device/presigned-put`** (worker host from the same source as WebSocket: `DeviceWebSocketConfig.resolveApiHost()` → prod `api-prod.lasercyber.workers.dev` / non-release `api-test.lasercyber.workers.dev`) with query parameters **`sn`**, **`content_type`**, **`file_name`**, and **`key`** shaped as `uploads/devices/{sn}/{date}/{file_name}`.
- Parse the JSON body as **`ApiResult<T>`** (`code`, `success`, `data`, `message`) **even when the HTTP status code is not 200**, per API contract; surface `message` on logical failure.
- On success, use **`data.upload_url`** with **`data.method`** (PUT) to upload the local video file, honoring **`expires_in_seconds`** for scheduling/timeouts where relevant; retain **`public_url`** / **`key`** for downstream metadata (existing `ProcessParamsVideo` / server registration flow to be wired in implementation).
- Replace or branch the current OSS-based video file upload in the process-video pipeline with this R2 presigned path (exact cutover vs feature flag left to design/tasks; **BREAKING** only if OSS video path is fully removed without migration).

## Capabilities

### New Capabilities

- `device-r2-presigned-upload`: Worker-hosted presigned-put API contract, Android client parsing rules (non-2xx + body), object key conventions, environment host selection aligned with device WebSocket, and integration expectations with the process-video upload UX.

### Modified Capabilities

- (none) — existing OpenSpec capabilities describe WebSocket envelopes, OTA, etc.; this change adds a parallel upload transport without altering those requirement documents.

## Impact

- **App**: `VideoAndProcessParamsHandler`, OSS helpers (`OSSManger`, `OssUploadFileRequestBuilder`), `RequestApi` / Retrofit usage for `uploadVideoAndProcessData`, and any UI callbacks for upload progress or failure.
- **Network**: New HTTPS calls to Workers (presign + R2 PUT); cleartext rules unchanged if all URLs stay `https`.
- **Backend / Worker**: Assumes Worker implements `/upload/device/presigned-put` and R2 signing; app only consumes contract described above.
