## 1. Schema and persistence

- [x] 1.1 Extend `ProcessParamsVideo` / `ProcessParamsVideoVo` with `videoId`, `resolution`, `syncStatus`, `uploadProgress`; bump `AppDatabase` version and add `Migration` (`syncStatus`/`uploadProgress` default `0`; legacy rows nullable `videoId`/`resolution` as needed).
- [x] 1.2 Update `ProcessProcessVideoDao` (`selectPage`, `selectById`, etc.) to include new columns where required for UI or workers.
- [x] 1.3 Add `VideoSyncStatus` (or equivalent) constants: `0` NotInitiated, `1` MetadataUploaded, `2` VideoUploading, `3` VideoUploaded.

## 2. Recording save path

- [x] 2.1 On insert path in `CameraController.saveVideoAndProcess` (or helper): generate `videoId`, set textual `resolution`, `syncStatus=0`, `uploadProgress=0`, keep `createTime=System.currentTimeMillis()`.
- [x] 2.2 Implement JPEG first-frame extraction; on failure do not POST metadata and do not set `syncStatus` to `1`.

## 3. Worker HTTP client

- [x] 3.1 Add `DeviceWorkerVideoMetadataClient` (or equivalent): pinned base, `POST /v1/devices/{sn}/videos/metadata`, `MultipartBody.FORM`, parts `video_id`, `cover`, `duration`, `resolution`, `file_size`, `create_time`, `process_type`, `process_data`; no extra auth headers; parse `ApiResult`.
- [x] 3.2 Map `create_time` from row `createTime`: default **`String.valueOf(createTime)`** (ms); document that API also accepts seconds string for the same instant if a variant is needed.

## 4. WorkManager and network hook

- [x] 4.1 Add WorkManager worker that loads one row (or batches with strict sequential POST), runs cover + metadata POST, updates `syncStatus` to `1` on success.
- [x] 4.2 On pinned-base selection success in existing `NetworkCallback` / probe flow, query `syncStatus=0` eligible rows and enqueue unique work per row (or one chain) to drain backlog.
- [x] 4.3 After successful Room `insert` from recording, enqueue same worker when pin + SN are available (avoid duplicating HTTP logic).

## 5. Verification

- [x] 5.1 Record offline → row `syncStatus=0`; bring network + pin → WorkManager uploads → `syncStatus=1`. *(QA on device)*
- [x] 5.2 Cover extraction forced failure → no `syncStatus=1`, no successful completion path. *(Worker returns `retry` until backoff; QA on device)*
