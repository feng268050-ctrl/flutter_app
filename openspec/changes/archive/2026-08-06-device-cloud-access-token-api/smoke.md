# Manual smoke — device cloud access_token Bearer

Prerequisites: board with VS SN + sealed Ed25519 (`device-cloud-ed25519-activate`),
api-server with `device-ed25519-activate` + `device-access-token-auth` on **api-test**.

1. Enable 云服务; pin HTTPS api-test origin; Wi‑Fi up.
2. Confirm logs: `cloud-ed25519: activated` then `access_token minted` **before**
   `connecting ws` / users probe.
3. `GET /v1/devices/:sn/users` succeeds with `Authorization: Bearer …`
   (Worker logs or mitm / app debug — do not log the raw token in HMI).
4. `GET /ws/device?sn=…` upgrade connects; path remains `/ws/device` (no `/v2`).
5. Optional: expire/force-invalid token → one remint + single HTTP retry / WS
   reconnect; persistent 401 without `INVALID_SN` does **not** open registration UX.
6. Activate / token mint requests must **not** send Bearer.
