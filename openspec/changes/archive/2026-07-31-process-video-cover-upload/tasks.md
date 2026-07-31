## 1. Cover pipeline

- [x] 1.1 Add R2 object-key + `public_base_url` join helpers; extend STS client to parse `public_base_url`
- [x] 1.2 Add ffmpeg-based JPEG cover extractor writing under `/var/lib/hmi/video-covers/`
- [x] 1.3 Add cover uploader (0→1 + `coverUrl` + WS `video.metadata`) and pending drain

## 2. Full upload coordinator

- [x] 2.1 Implement single-flight cover-then-video runner with progress callbacks; fix object keys
- [x] 2.2 Wire Record Work save + API pin success to enqueue cover drain
- [x] 2.3 Point `command.upload_video` at the shared coordinator (keep early ack)

## 3. Monitor UI

- [x] 3.1 Add Upload control + progress dialog on Videos tab; disable when status 3 / in flight
- [x] 3.2 Add l10n strings for upload progress / errors

## 4. Verify

- [x] 4.1 Unit tests for keys, cover status transition helpers, and list Upload gating
- [x] 4.2 `flutter analyze` on touched paths
