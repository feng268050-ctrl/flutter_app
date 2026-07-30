## 1. OpenSpec / matrix

- [x] 1.1 Land proposal, design matrix, delta spec, tasks for `cloud-ws-full-parity`
- [x] 1.2 Merge delta into main `openspec/specs/device-cloud-websocket/spec.md`

## 2. Lock / disconnect / snapshot

- [x] 2.1 On lock: Modbus safety stop (laser/gas/wire bits) + `onRemoteLockChanged` eject callback
- [x] 2.2 On unlock: clear UI notice callback
- [x] 2.3 On disconnect: forced suppress + foreground notice callback
- [x] 2.4 Wire callbacks from `app.dart` (pop locked modes / dialog)

## 3. Process push

- [x] 3.1 Add cloud↔HMI process parameter codec + envelope unwrap
- [x] 3.2 Implement `send_process_param` → `saveUser`
- [x] 3.3 Implement `send_process_lib` → wipe builtins + deriver + `replaceBuiltins`
- [x] 3.4 Unit tests for codec and ack codes

## 4. Process CRUD shapes

- [x] 4.1 Missing `process_type` → empty library response
- [x] 4.2 Outbound string ids; set_default applies preset (ack)
- [x] 4.3 Delete only non-builtin (dataType=2 / user)

## 5. Video

- [x] 5.1 Repository query API: page/filters/order/upload_status default
- [x] 5.2 Upload: early ack, `video.uploading`, `video.metadata`, update local status
- [x] 5.3 Delete error codes alignment

## 6. OTA protocol

- [x] 6.1 Replace OTA data-ack with check_update_ack / update_system_ack shapes
- [x] 6.2 `error_code: ota_not_supported`; no progress emission

## 7. Verify

- [x] 7.1 Protocol unit tests green
- [x] 7.2 `make build-app` + `make push-app`
- [x] 7.3 Mark tasks complete
