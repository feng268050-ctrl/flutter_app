## 1. Domain + SQLite

- [x] 1.1 Add `process_video` domain models (`ProcessVideoRecord`, snapshot envelope with process type / material / parameters JSON / optional preset uuid + library version)
- [x] 1.2 Implement `ProcessVideoRepository` + `SqliteProcessVideoRepository` (`/var/lib/hmi/process-videos.db`, table `process_videos`, newest-first paging + count + delete)
- [x] 1.3 Add unit tests for schema create, insert, page, delete soft-fail (in-memory or temp DB)

## 2. Save pipeline + Record Work

- [x] 2.1 Implement `ProcessVideoSaveHandler`: probe duration/size/resolution, enforce min duration (~1 s), insert row, soft-fail messaging
- [x] 2.2 Define `ProcessVideoSnapshotSource` and wire Quick Mode + Engineer Mode to supply start/live snapshots from current process UI state
- [x] 2.3 Extend `RecordWorkController` to capture start snapshot on encode start and call save handler after successful stop (do not save Settings demo)
- [x] 2.4 Add controller/handler tests for discard-short, snapshot-on-save, and no-insert when camera unavailable
- [x] 2.5 Evaluate 10-minute segment roll on device; implement if HAL stop/start is reliable while armed+laser, otherwise document deferral in code comment only

## 3. Monitor Videos list

- [x] 3.1 Replace `VideosTab` stub with repository-backed table (columns + empty state + page/load-more or equivalent + reload on appear)
- [x] 3.2 Add Delete with confirmation; omit Upload controls
- [x] 3.3 Wire work-mode / material label mapping consistent with process-library enums
- [x] 3.4 Add widget/controller tests for empty list, populated row, cancel/confirm delete

## 4. Video detail + playback

- [x] 4.1 Add Monitor video detail route/page: local `video_player` (or equivalent) for `video_path`, transport controls, missing-file soft-fail
- [x] 4.2 Build parameter panel from `process_parameters_json` with mode-gated fields (lws-ui detail parity for visible rows)
- [x] 4.3 Detail Delete with confirmation → pop and refresh list
- [x] 4.4 Widget/smoke tests for detail open with fixture record; playback path unit-tested where platform allows

## 5. i18n + polish

- [x] 5.1 Move Record Work / Videos list / detail / delete / empty / save-failure strings into ARBs (`make l10n`)
- [x] 5.2 Ensure Settings demo copy still clarifies demo-only isolation if needed

## 6. Verification

- [x] 6.1 Run `flutter analyze` and targeted tests under `app/lws_hmi/`
- [x] 6.2 Device smoke (ynh960): Quick Record Work → laser on/off → Videos row → play → delete; confirm Settings demo clip not listed
