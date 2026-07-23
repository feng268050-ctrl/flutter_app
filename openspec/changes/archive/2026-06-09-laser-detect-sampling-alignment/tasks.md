## 1. Sampling constants and burst coordinator

- [x] 1.1 Add `FRAME_REJECTED_BURST` (100ms) to `AiFrameSamplingInterval`
- [x] 1.2 Change `LIVE_WELD` from 2000ms to **500ms**; update tests/docs referencing 2000ms
- [x] 1.3 Add `LaserDetectSamplingCoordinator`: NORMAL vs BURST, enter on `code=-5`, exit when both modules have `code=0`, laser-off reset
- [x] 1.4 Gate resolver: normal → `LIVE_WELD` / `ZERO_POINT_ON_LASER` (both 500ms); burst → `FRAME_REJECTED_BURST` (100ms)
- [x] 1.5 Unit tests: burst enter/exit, single-module active, laser-off reset

## 2. zero_point PR1-driven continuous sampling

- [x] 2.1 Remove `postDelayed` schedule and four-sample finalize from `ZeroPointDetectCoordinator`
- [x] 2.2 Drive samples from PR1 callback while laser ON; first frame eligible immediately after gate reset
- [x] 2.3 Finalize round (cluster reducer + correction write) on **laser OFF**, not after sample count
- [x] 2.4 Report `code=-5` / `code=0` to burst coordinator; log `trigger=pr1`
- [x] 2.5 Remove or repurpose `ZeroPointDetectTaskSchedule` fixed deadline APIs
- [x] 2.6 Unit tests: continuous sampling, finalize on laser off, first frame before 500ms

## 3. lens_det burst integration

- [x] 3.1 Route `OpencvStainDetectCoordinator` gate through coordinator (500ms normal / 100ms burst)
- [x] 3.2 Report lens_det `code=-5` / `code=0` to burst coordinator
- [x] 3.3 Centralize PR1 dispatch in `LivePr1InferenceStreamClient`
- [x] 3.4 Unit tests: 500ms normal vs 100ms burst gate acceptance

## 4. Logging, docs, device verification

- [x] 4.1 Log `LaserDetectSampling: mode=burst|normal` transitions
- [x] 4.2 Update `docs/OPENCV_DETECT_APP_INTEGRATION.md` (PR1-first, continuous zero_point, LIVE_WELD 500ms, burst)
- [ ] 4.3 Device smoke on 192.168.0.44: short laser window; burst on `-5`; correction write on laser OFF
