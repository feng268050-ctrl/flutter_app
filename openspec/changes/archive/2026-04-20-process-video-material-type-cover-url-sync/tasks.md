## 1. Schema and Room

- [x] 1.1 Add `Migration_36_37` (rename `materials` → `materialType`, add nullable `coverUrl` and `videoUrl` per design); register in `AppDatabase` and bump `version` to **37**
- [x] 1.2 Update entity `ProcessParamsVideo` fields; update `ProcessParamsVideoVo` and `ProcessProcessVideoDao.selectPage` column list / mappings
- [x] 1.3 Regenerate or hand-update Room `app/schemas/.../37.json` if the repository requires schema exports on version bump

## 2. Metadata sync and API parsing

- [x] 2.1 Parse successful `ApiResult.data` for optional string `cover_url` in `DeviceWorkerVideoMetadataClient` (or helper); expose to caller (e.g. `Outcome` field)
- [x] 2.2 Extend DAO: single update setting `syncStatus` and `coverUrl` (nullable arg) for a row id; remove or narrow standalone `updateSyncStatus` if redundant
- [x] 2.3 In `ProcessVideoMetadataWorker.runMetadataUploadForRow`, after successful POST, persist `syncStatus = MetadataUploaded` and `coverUrl` when returned

## 3. Call sites and UI

- [x] 3.1 Rename usages on the video row: `CameraController`, `ProcessVideoViewHolder`, `ProcessVideoDetailsViewModel`, and any other `getMaterials`/`setMaterials` references **on `ProcessParamsVideo` / Vo**
- [x] 3.2 Update `DeviceWorkerVideoMetadataClient` KDoc / multipart builder to use `getMaterialType()`

## 4. Verification

- [x] 4.1 Update or add unit tests (e.g. metadata outcome parsing, migration smoke if present) and run relevant `./gradlew` test tasks
- [x] 4.2 After implementation, merge delta into `openspec/specs/device-video-metadata/spec.md` during archive per project OpenSpec workflow
