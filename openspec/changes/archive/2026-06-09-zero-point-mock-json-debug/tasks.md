## 1. Mock loader

- [x] 1.1 Add `ZeroPointMockJsonLoader` with constant path `/sdcard/lws_debug/zero_point_mock.json`, `RELEASE_CHANNEL` gate, file read, and `ZeroPointDetectJson.parse`; return `Optional<Sample>` or nullable API matching project style
- [x] 1.2 Log mock hit/miss with TAG `ZeroPointMock` (info on hit, debug on miss reason)
- [x] 1.3 Unit tests: release channel → always empty; staging + valid file → parsed sample; missing file → empty; invalid JSON → empty

## 2. Coordinator integration

- [x] 2.1 `ZeroPointDetectCoordinator.runNativeSample`: try mock before native; on hit use sample and skip `nativeOpencvZeroPointDetectFromI420`
- [x] 2.2 `ZeroPointManualAutoCoordinator.detectFrame`: try mock first; on hit return without requiring `zpHandle`; on miss keep existing native path
- [x] 2.3 Compile `:app:compileDebugJavaWithJavac` and run new unit tests

## 3. Documentation and device verification

- [x] 3.1 Document mock workflow in `docs/OPENCV_DETECT_APP_INTEGRATION.md` (path, example JSON, adb push/rm, logcat filters, production vs Manual Auto steps)
- [ ] 3.2 Staging device: push mock with `offset_x=-9`, run Manual Auto or production laser-on task, confirm `ZeroPointCorrection` applied and optional offset alert after laser off
- [x] 3.3 Confirm `RELEASE_CHANNEL=true` build ignores mock file (file present, native path only)
