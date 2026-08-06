# Manual smoke — device cloud Ed25519 activate

1. `make write-identity BRAND=… MODEL=… PRODUCT_SN=…` on a real board (VS present).
2. Enable 云服务; ensure Wi‑Fi + HTTPS Worker/API origin pins.
3. Confirm logs: `cloud-ed25519: activated` once; VS ID 22 non-empty
   (`read-cloud-ed25519-sealed --present`).
4. Reboot HMI / toggle 云服务: no new keypair; activate may idempotent-200 same key.
5. `make flash` without vendor payloads → same sealed blob → still same pubkey /
   no first-time generate.
6. Optional: `POST /v1/devices/:sn/token` path via mint log `access_token minted`.
