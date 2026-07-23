## 1. Native (libai / lensinspector)

- [x] 1.1 Update `nativeInferImageAndSave` so success (JNI + read + infer + save) always returns `0`, independent of `CLEAN`/`LIGHT`/`HEAVY`.
- [x] 1.2 Return `-1` (args/handle), `-2` (read), `-3` (inference), `-4` (save) per failure stage; document any additional codes.
- [x] 1.3 Emit qualitative detection via listener/callback or optional `*_result.json` (per design), not via the int return value.
- [x] 1.4 Rebuild and pack `libai_*.zip`; align version tag with App release notes.

## 2. App (lws-ui)

- [x] 2.1 Keep `nativeCode == 0` as the only success path in `inferJpgAndSaveResult` / `guardedInferImageAndSave` handling.
- [x] 2.2 Add `nativeInferErrorMessage(int code)` (or equivalent) mapping `-1`…`-4` to user-facing strings; fallback for unknown codes.
- [x] 2.3 After `nativeCode == 0`, retain file existence and non-empty size check; keep or align App error code for missing output (e.g. `-6`).
- [x] 2.4 Wire UI or events to detection `level`/`status`/`message` from callback or JSON, not from `nativeCode` when `0`.
- [x] 2.5 Update or add logging/diagnostics so `RKNN_DIAG` remains the source of native stage detail.

## 3. Tests and validation

- [x] 3.1 Run `InferPicturesDirectoryInstrumentedTest` (or equivalent) and confirm success count matches images when `code==0` and files exist.
- [x] 3.2 Manual or instrumented check: forced read failure → `-2`, etc., if testable without hardware flakiness.

## 4. Documentation and release

- [x] 4.1 Add short “contract” note in project handoff or `LIBAI_SO_BUILD_GUIDE` pointer: return codes + breaking change notice.
- [x] 4.2 Coordinate YOLO release version with App so old `libai` is not mixed with new App expectations.
