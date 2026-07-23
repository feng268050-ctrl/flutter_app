# Baseline metrics (fill during field test)

Use before/after comparisons when enabling dual-stream + IPC sub-stream tuning.

## Environment

- Date:
- Device (tablet) serial / build:
- Camera IP / host:
- IPC model & firmware:

## Single-stream baseline (if captured historically)

| Metric | Value |
|--------|--------|
| RTSP URL | |
| Subjective delay (VLC vs AI Vision) | |
| First frame (`VIDEO_DISPLAYED firstFrameMs`) | |
| `decodeType` (0=lite, 1=MediaCodec) | |
| Effective `LIVE_VIDEO_SIZE` | |
| Stutter under continuous motion (1–5) | |

## Dual-stream (sub → main fallback)

| Metric | Value |
|--------|--------|
| First connect profile (`profile=sub` / `main`) | |
| `LIVE_VIDEO_SIZE` on sub | |
| Motion stutter (1–5) | |
| Recording `RECORD_RTSP` URL path | |
| Playback resolution of recorded file | |
