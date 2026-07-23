## 1. Network and models

- [x] 1.1 Add `CameraDeviceInfo` Gson model with `appVersion` (and optional API fields per contract)
- [x] 1.2 Add `GET` method on `CameraRemoteApi` (`@GET`, `@Url`, Basic auth header) returning `CameraDeviceInfo`
- [x] 1.3 Implement `CameraRemote.fetchCameraDeviceInfo(Context, callback)` building URL via `CameraConfig.baseCameraAppUrl(context) + "System/deviceinfo"`; map failures and blank `appVersion` to display fallback

## 2. ViewModel and UI

- [x] 2.1 Add `cameraVersionDisplay` `LiveData<String>` on `DeviceInfoViewModel` (default `-`)
- [x] 2.2 Trigger fetch from `DeviceInformationFragment` on screen entry (`onViewCreated` and/or `onResume`); post result to ViewModel
- [x] 2.3 Add **Camera Version** as last row in `fragment_device_information.xml` with data binding to `cameraVersionDisplay`
- [x] 2.4 Add `camera_version` strings in `values` and `values-zh`

## 3. Verification

- [x] 3.1 Manual: camera online → row shows `appVersion` from deviceinfo
- [x] 3.2 Manual: camera offline or wrong host → row shows `-`
- [x] 3.3 Optional: unit test for URL builder / response-to-display mapping (blank vs valid `appVersion`)
