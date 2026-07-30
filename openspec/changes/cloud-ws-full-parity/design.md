## Context

lws-ui `DeviceWebSocketConnectionManager` is the SoT for device↔cloud WS. HMI already has envelope, online/stat carriers, and most command stubs; gaps block production parity (process push, video semantics, lock safety, OTA ack shapes).

## Goals / Non-Goals

**Goals:** Full non-OTA command behavior parity with lws-ui; documented matrix; OTA protocol-correct unsupported outcomes.

**Non-Goals:** Firmware download/apply UI; LAN `:5580` full matrix; AI WS (none upstream).

## Decisions

1. **Catalog in design** — Matrix below is the implementation checklist; main spec carries MUST requirements.
2. **Process lib wipe** — Prefer HMI `replaceBuiltins` + engineer deriver (not Android dual-copy of every row as quick+engineer). Wipe all quick/engineer builtins regardless of prior `source`, keep `user` presets.
3. **OTA** — Reply with lws-ui-shaped `data` and `error_code: ota_not_supported` / `ok:false`; do not emit progress without a real upgrade pipeline.
4. **Upload ack** — Send `upload_video_ack` when upload is **accepted/started**; completion via `video.uploading` + `video.metadata`.

## WS command matrix (lws-ui SoT → HMI)

| Dir | type | Payload / ack | Side effects | HMI (pre) | Target |
|-----|------|---------------|--------------|-----------|--------|
| ↑ | `device.online` | `stat` snapshot | after connect | ok+deviceInfo | keep |
| ↓↑ | `stat_request`/`stat_response` | `request_id`+`data` | — | ok | keep |
| ↓ | `lock`/`unlock` | no ack | persist; lock→Modbus stop+eject modes | persist only | +safety+eject |
| ↓↑ | `clear_alerts`/`_ack` | data-ack | wipe alarm history | ok | keep |
| ↓ | `disconnect` | no ack | forced no-reconnect + notice | forced ok | +UI notice |
| ↓↑ | `send_process_param`/`_ack` | code 200/500 | save engineer/user row | not_wired | wire |
| ↓↑ | `send_process_lib`/`_ack` | code 200/500 | replace builtins+version | not_wired | wire |
| ↓↑ | process library/params CRUD | data-ack / responses | string ids; missing process_type→[] | partial | align |
| ↓↑ | video list/upload/delete | filters; videoId vs video_id | upload ack=start; metadata | partial | align |
| ↑ | `video.uploading` / `video.metadata` | camelCase | during/after upload | uploading only | +metadata |
| ↓↑ | OTA check/update | data ok/manifest/started | no apply here | ota_deferred | protocol |
| — | `connected`/`ack`/unknown | ignore/log | — | ok | keep |

### Quirks

1. online=`stat`; stat_response=`request_id`+`data`
2. Process push: flat `code`/`message`; others: `data.{success,message}`
3. Upload `videoId`; delete `video_id`
4. lock/unlock/disconnect: no typed ack
5. `update_system` payload = flat manifest

## Risks / Trade-offs

- Process push unit for `perforationDuration`: treat values ≤20 as seconds→ms (`×1000`), else ms (HMI catalog).
- Mode eject needs navigator/callback from `app.dart` (no Activity stack).

## Migration Plan

Ship via `make build-app` + `make push-app`. No DB schema migration beyond existing process tables; video query uses new repo API with filters.
