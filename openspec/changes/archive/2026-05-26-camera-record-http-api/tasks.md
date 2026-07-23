## 1. Recording coordinator extraction

- [x] 1.1 Add `CameraRecordCoordinator` with `applySwitch("on"|"off")` returning effective state + error code; move preflight/start/stop logic from `CameraController` (recorder ready, YNH storage, `CameraUtils.checkCamera`, `CameraRemote.updateCameraTime`, `EasyPlayerClientManger` start/stop)
- [x] 1.2 Refactor `CameraController` to delegate tap path to coordinator; preserve timer animator, listener snapshot, and `EasyPlayerClientManger` callbacks
- [x] 1.3 Add `CameraRecordUiBridge` (weak ref) + `applyExternalRecordOn` / `applyExternalRecordOff` on `CameraController` for animation/binding sync without duplicate preflight

## 2. HTTP route

- [x] 2.1 Add request/response DTOs with Gson `@SerializedName("switch")` for JSON field `switch`
- [x] 2.2 Register `POST /v1/camera/record` in `DeviceLocalHttpServer`; parse body, run coordinator off main thread, return `DeviceApiResultHttp` success/failure
- [x] 2.3 Wire UI bridge: on HTTP success call `CameraRecordUiBridge.syncUiIfPresent()` for on/off

## 3. Tests and documentation

- [x] 3.1 Add `DeviceLocalHttpCameraRecordRouteTest` (invalid body → failure; mocked coordinator or integration stub)
- [x] 3.2 Document `POST /v1/camera/record` in `docs/network-api-reference.md` (request/response, error codes, curl example, Fast/Engineer parity note)
- [x] 3.3 Field checklist: Fast Mode float visible → HTTP on shows timer; HTTP off saves row; duplicate on/off idempotent; concurrent `GET /v1/camera/live` while recording
