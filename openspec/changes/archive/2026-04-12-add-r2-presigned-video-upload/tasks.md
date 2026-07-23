## 1. Contract and models

- [x] 1.1 Add Gson-friendly types for `ApiResult<T>` and presign `data` (`upload_url`, `method`, `public_url`, `key`, `expires_in_seconds`) under `bean/http` (or equivalent package), matching Worker field names.
- [x] 1.2 Confirm with backend/Worker owner the `{date}` format in `key` and lock `DateTimeFormatter` (or `SimpleDateFormat`) usage to that contract; adjust spec comment in code if different from `yyyy-MM-dd`.

## 2. Presign + PUT client

- [x] 2.1 Implement a small OkHttp-based presign client: build `DeviceApiOriginConfig.resolveHttpsApiOrigin()` + `/upload/device/presigned-put` with query `sn`, `content_type`, `file_name`, `key` (`uploads/devices/{sn}/{date}/{file_name}`).
- [x] 2.2 On presign response, read `ResponseBody` bytes/string for **any** HTTP status; parse JSON to `ApiResult`; on parse success, honor `success`/`message`/`data`; on parse failure, fail with HTTP code + body logging.
- [x] 2.3 Implement streaming `PUT` to `upload_url` with `Content-Type` from presign request; bound timeouts using `expires_in_seconds` where practical.
- [x] 2.4 Add unit tests for JSON parsing on synthetic non-200 responses with valid `ApiResult` bodies (no device required).

## 3. Pipeline integration

- [x] 3.1 Resolve ordering with `ProcessVideoRemoteApi.uploadVideoAndProcessData`: either keep POST-then-PUT (if URL may be provisional) or switch to presign+PUT-then-POST per server contract; wire `ProcessVideo` URL fields to `public_url` (and any required `key`) from presign `data`.
- [x] 3.2 Integrate into `VideoAndProcessParamsHandler` (and callbacks) so the video file upload path uses R2 presigned PUT instead of OSS resumable video upload when the chosen strategy flag/channel indicates R2; keep cover-image behavior per design until explicitly extended.
- [x] 3.3 Preserve existing failure/progress UX (`OSSAsyncResumableUploadFail` / `UploadFileType` or introduce parallel callbacks only if necessary); ensure `clearAllTask` / timeout logic still applies to the R2 upload duration.

## 4. Validation and cleanup

- [x] 4.1 Manual or instrumented test on `api-test` host: presign → PUT → metadata path; repeat on release channel against `api-prod`.
- [x] 4.2 If OSS video upload is fully replaced, remove dead OSS video-only code paths and unused STS fields **only after** R2 path is default and verified (separate commit acceptable).
