# Field validation: dual-stream (tasks 5.1 / 5.2)

## Device with sub-stream (`PR1` reachable)

- [ ] AI Vision log: first `RTSP start request` uses sub URL (`profile=sub`, `candidate=1/2`).
- [ ] `LIVE_VIDEO_SIZE` matches IPC sub-stream configuration.
- [ ] Start recording from Dev / feature path: `RECORD_RTSP` uses main URL (`profile=main` in path).
- [ ] Unplug network or block `PR1` (if safe): app switches to main with `Switching live RTSP candidate` / `LIVE_RTSP_FALLBACK` logs.

## Device or camera **without** usable sub-stream

- [ ] Configure bogus sub path **or** use `Live stream policy = main only` in Dev → only one candidate; live still works.
- [ ] Recording remains on main stream.

## Regression (5.2)

Document subjective motion smoothness and `firstFrameMs` vs previous build in `baseline-metrics-template.md`.
