## 1. Prerequisites

- [x] 1.1 Confirm local `device-cloud-ed25519-activate` can mint `access_token`
- [x] 1.2 Confirm sibling api-server `device-access-token-auth` + `device-ed25519-activate` contracts (v1 paths, Bearer, no v2)

## 2. Token attachment

- [x] 2.1 Add shared device Bearer header helper / HTTP interceptor fed by token cache from activate/mint
- [x] 2.2 Attach Bearer on `GET /v1/devices/:sn/users`, `POST /v1/devices/:sn/ai-report`, device `POST /v1/storage/r2/sts` (and device presign if present)
- [x] 2.3 Attach Bearer on `GET /ws/device` upgrade; keep URL path `/ws/device`
- [x] 2.4 Ensure activate + token mint calls omit Bearer
- [x] 2.5 On 401: one re-mint + single retry (HTTP); WS reconnect with new token

## 3. Lifecycle / docs

- [x] 3.1 Gate cloud connect path so mint runs before first gated call when 云服务 is on
- [x] 3.2 Update any client docs/comments that describe device cloud as SN-only forever
- [x] 3.3 Manual checklist against api-test: users + WS with Bearer after activate
