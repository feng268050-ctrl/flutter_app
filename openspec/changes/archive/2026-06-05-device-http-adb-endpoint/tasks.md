## 1. HTTP route

- [x] 1.1 Register `POST /v1/adb` in `DeviceLocalHttpServer.serve`; return `notFoundJson` for non-POST methods on that path
- [x] 1.2 Add `serveAdbEnable(Context)` handler that runs `AdbRemoteDebugHelper.enableRemoteDebugging` off the main thread (executor + blocking wait, mirroring `serveCameraRecord` / coordinator pattern)
- [x] 1.3 Map helper `true` → `DeviceApiResultHttp.success(null)`; map `false` → `DeviceApiResultHttp.failure(503, "adb_enable_failed")` with HTTP 200 or 503 per design alignment with existing routes

## 2. Tests and documentation

- [x] 2.1 Add route-level JVM test for `POST /v1/adb` (success returns `data: null`; failure message; wrong method not successful)
- [x] 2.2 Document `POST /v1/adb` in `docs/network-api-reference.md` (purpose, `ApiResult` shape, `adb_enable_failed`, curl example on port **5580**, note shared behavior with five **System Version** taps)
- [x] 2.3 Field checklist: `curl -X POST http://<device-lan-ip>:5580/v1/adb` → `adb connect <device-ip>:5555` succeeds; repeated POST remains idempotent success
