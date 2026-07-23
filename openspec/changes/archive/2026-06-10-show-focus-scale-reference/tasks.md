## 1. Data Model and Source

- [x] 1.1 Add a non-persisted `focusScaleRef` field to `DeviceInfo` for data binding and Gson serialization.
- [x] 1.2 Populate `DeviceInfo.focusScaleRef` from `DeviceModelConfig.getFocusScaleRef()` wherever `DeviceInfo` is assembled for Settings display/cache.
- [x] 1.3 Populate `DeviceInfo.focusScaleRef` from `DeviceModelConfig.getFocusScaleRef()` in `DeviceStatusPut` remote snapshot assembly alongside other transient ROM-derived fields.

## 2. Device Information UI

- [x] 2.1 Add localized string resources for the **Focus Scale Reference** label.
- [x] 2.2 Add a Device Information row bound to `deviceInfoViewModel.liveData.focusScaleRef`, displaying signed integer values including `0` and negatives.
- [x] 2.3 Verify row ordering and spacing remain consistent with existing Device Information rows.

## 3. Remote Snapshot Contract

- [x] 3.1 Update WebSocket snapshot tests so `command.stat_response` includes numeric `payload.data.deviceInfo.focusScaleRef`.
- [x] 3.2 Update WebSocket snapshot tests so `device.online` includes matching numeric `payload.stat.deviceInfo.focusScaleRef`.
- [x] 3.3 Confirm no Room schema migration is introduced for `focusScaleRef`.

## 4. Documentation and Validation

- [x] 4.1 Update any network API reference that lists `deviceInfo` fields for `command.stat_response` and `device.online`.
- [x] 4.2 Run the focused unit tests for `DeviceWebSocketConnectionTest` or the nearest available WebSocket snapshot test target.
- [x] 4.3 Manual: launch with `FOCUS_SCALE_REF=-3`, open Settings Device Information, and confirm the Focus Scale Reference row displays `-3`.
