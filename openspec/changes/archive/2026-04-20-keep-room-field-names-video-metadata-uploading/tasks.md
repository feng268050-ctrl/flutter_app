## 1. Payload builders and call sites

- [x] 1.1 Change `DeviceWsVideoMetadataPayload.fromRow` to emit camelCase keys matching `ProcessParamsVideo` getters (`videoId`, `processData`, `processType`, `materialType`, `fileSize`, `duration`, `createTime`, `status`, `resolution`, `uploadStatus`, `uploadProgress`, `coverUrl`, `videoUrl`); keep omitting `id` and `videoPath`.
- [x] 1.2 Change `DeviceWebSocketConnectionManager#sendVideoUploading` to use camelCase keys (`videoId`, `uploadStatus`, `uploadProgress`, `videoUrl`); update method Javadoc accordingly.

## 2. Tests and verification

- [x] 2.1 Update `DeviceWsVideoMetadataPayloadTest` (rename test if needed) to assert camelCase keys and absence of `id` / `videoPath`.
- [x] 2.2 Update `VideoUploadingWsEnvelopeTest` to assert camelCase keys in the serialized payload.
- [x] 2.3 Search for other tests or docs referencing snake_case keys on `video.metadata` / `video.uploading` and align them.
- [x] 2.4 Run the affected unit tests (e.g. `./gradlew :app:testDebugUnitTest` with a filter on the ws package if available) and fix any failures.

## 3. Downstream coordination (outside repo if needed)

- [x] 3.1 Confirm server or other consumers accept camelCase for these two message types (or schedule a dual-key window per `design.md` migration plan) before shipping the app change.
