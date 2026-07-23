## 1. Data model and enums

- [x] 1.1 Rename Room/SQLite column `syncStatus` to `uploadStatus` on `t_params_process_video` (entity `ProcessParamsVideo`, DAO queries, migrations) and update all Java/Kotlin references.
- [x] 1.2 Rename `VideoSyncStatus` to `VideoUploadStatus`; set value `1` to `CoverUploaded` and update all switch/UI strings that referred to metadata-uploaded semantics.
- [x] 1.3 Update `command.video_list_request` / `command.video_list_response` read path to filter on `uploadStatus != 0` and serialize `upload_status` (snake_case) in list items instead of `syncStatus` / `sync_status`.

## 2. Remove Worker multipart metadata path

- [x] 2.1 Remove or gut `POST /v1/devices/:sn/videos/metadata` client calls, DTOs used only for that path, and `ProcessVideoMetadataWorker` (or repurpose) so nothing enqueues multipart metadata after save.
- [x] 2.2 Remove hooks that drain `uploadStatus = 0` rows via WorkManager solely for HTTP metadata; replace with documented no-op or optional cover-retry strategy if still needed.

## 3. Presigned cover → DB → WebSocket

- [x] 3.1 Implement cover presigned-PUT success handler: persist `coverUrl` from `public_url`, set `uploadStatus` to `CoverUploaded` (`1`), then emit `video.metadata` with snake_case JSON excluding `id` and `video_path` but including `video_id` and other catalog fields from the row.
- [x] 3.2 Add/adjust WebSocket envelope builder for `video.metadata` alongside existing command serialization conventions.
- [x] 3.3 Ensure cover extraction, presign, PUT, DB write, and WS send run off the main thread.

## 4. Monitor list upload and progress reporting

- [x] 4.1 Update **Monitor → Videos** list upload orchestration: when `uploadStatus` is `0`, run cover presign+PUT+row update+`video.metadata` before STS video bytes; when `uploadStatus` is `1`, skip straight to STS.
- [x] 4.2 Update `video.uploading` payload to use `upload_status` (integer `VideoUploadStatus`) instead of `sync_status`, and align throttling/final-state scenarios with new enum semantics.
- [x] 4.3 On STS video failure after `VideoUploading`, reset `uploadProgress` to `0` and set `uploadStatus` back to `CoverUploaded` (`1`) per spec (unless resume supersedes).

## 5. Verification

- [x] 5.1 Update or add unit tests for key builders (`video.metadata`, `video.uploading`, list response mapping) and any renamed enums/keys.
- [x] 5.2 Manually verify: new recording row starts at `uploadStatus=0`; list command hides such rows until cover path promotes to non-zero; cover failure leaves `0`; successful cover shows in list with `cover_url`; video upload still reaches `3`.
