## Why

After the initial `align-cloud-local-server` archive, Linux HMI still failed cloud presence and several lws-ui parity paths: `device.online` used non-canonical snapshot carriers (`payload`/`stat` mismatch), lock/clear_alerts/process acks diverged, process-parameters LAN routes and video R2 upload were incomplete, hyurl origin candidates were dropped, and registration vs bind classification missed Worker `INVALID_SN`. Cloud ingest and mobile UX therefore treated connected devices as offline or unregistered.

## What Changes

- Align **remote snapshot** with api-server `isCanonicalDeviceStatData` (`payload.stat` online; `request_id`+`data` on stat_response; `wifiInfo` object or JSON `null`).
- Align **WebSocket acks**: lock/unlock with no typed ack; clear_alerts and process/video mutation acks per lws-ui shapes; wire process library/parameters request/response and video list/upload/delete (R2 STS + metadata).
- Complete **LAN `:5580` process-parameters** CRUD + set-default; leave monitor/camera as structured 501 stubs until backends exist.
- Restore **hyurl** candidates beside workers.dev for test/prod origin probe.
- Clarify **registration vs bind**: `INVALID_SN` / needsRegistration → register QR; `users.ok && userCount == 0` → bind QR; resume auth latch and re-probe after reconnect.
- **Withdraw mDNS** when Wi‑Fi/LAN address disappears.
- Fix OpenSpec **Purpose TBD** stubs left from the prior archive and sync requirement text with the implemented behavior.

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `device-cloud-websocket`: Canonical online/stat carriers, ack/lock semantics, process CRUD + video WS handlers, auth-latch resume after SN becomes valid.
- `device-cloud-http`: Users probe classifies `INVALID_SN` as needs-registration; R2/video metadata used by WS upload path.
- `device-local-http-api`: Process-parameters LAN CRUD + set-default; explicit stub behavior for monitor/camera.
- `device-api-origin-selection`: Test/prod candidate lists include hyurl fallbacks.
- `device-mdns-advertise`: Withdraw advertisement on LAN/Wi‑Fi loss (not only on server stop).
- `device-registration-ui`: Separate register (unrecognized SN) vs bind (unbound) prompts; Reconnect re-probes users and clears auth latch.

## Impact

- **App:** `app/lws_hmi/lib/platform/cloud/**`, `local_http/**`, `app.dart` wiring, registration/bind guidance prompts.
- **Contracts:** Worker / api-server canonical device stat + lws-ui WS/HTTP shapes; OTA still deferred.
- **OpenSpec:** Main specs under `openspec/specs/device-*` updated; this change archives the parity delta.
