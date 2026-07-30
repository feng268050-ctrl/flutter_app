## Context

`align-cloud-local-server` landed scaffolding (origin pin, WS lifecycle, `:5580`, mDNS, registration UI). Runtime gaps blocked cloud presence: snapshots failed Worker validation (`VALIDATION_ERROR` / `command.error`), ack shapes broke mobile command UX, and SN classification conflated “unknown device” with “unbound”. This change tightens contracts to match lws-ui + api-server without expanding OTA scope.

## Goals / Non-Goals

**Goals:**

- Cloud shows the device online after WS connect + successful `device.online` ingest.
- Lock, clear_alerts, process, and video commands follow lws-ui ack / no-ack rules.
- LAN process-parameters routes match lws-ui CRUD + set-default.
- Origin probe includes workers.dev and hyurl for test/prod.
- Register vs bind UX matches Worker `INVALID_SN` vs empty users.
- OpenSpec main specs reflect the above (no TBD Purpose stubs for these capabilities).

**Non-Goals:**

- Product/firmware OTA (`command.check_update` / `command.update_system` remain no-ops).
- Monitor SSE / camera AI-control backends (structured 501 only).
- Full process-push import when local importer is not wired (structured failure / 500 `not_wired` allowed).
- Android `cyber_hal` backends.

## Decisions

1. **Canonical snapshot roots** — Pack `staticData`, `deviceInfo` (with `deviceSn`), `commonSettings`, `deviceStatus`/`deviceData` objects, `warns` array, `wifiInfo` as object or JSON `null`. Online uses `payload.stat`; stat_response uses `request_id` + `data`.
2. **Lock without ack** — Persist lock flag only; mobile reads via subsequent online/stat.
3. **Ack families** — clear_alerts and video/process-parameter mutations: `request_id` + `data.{success,message}`; process push import: `request_id` + `code` + `message`.
4. **Auth latch** — INVALID_SN / 401 sets latch; when users probe later succeeds (`ok`), clear latch and connect (`resumeAfterAuth`). Boot probe may race Wi‑Fi — retry on Wi‑Fi up and delayed timers.
5. **Origin candidates** — test: `api-test.lasercyber.workers.dev` then `lasercyber.hyurl.com/test`; prod analogous. Pin first reachable.
6. **mDNS** — Publish when `:5580` up and LAN address usable; `withdraw()` on Wi‑Fi drop / no usable address.

## Risks / Trade-offs

- **Importer gaps** — Process push may still return 500 until library importer is fully wired; preferred over silent success.
- **Hyurl vs workers** — First reachable wins; operators may pin hyurl if workers.dev is blocked — intentional for field networks.
- **Monitor/camera 501** — Mobile may show errors until later backends land; better than hanging SSE.
