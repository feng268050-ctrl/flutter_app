# Device cloud Ed25519 — emulator / no Vendor Storage

Ensure-activated and token mint **require**:

1. 云服务 enabled
2. Pinned **HTTPS** API origin
3. Non-empty product SN (`read-identity sn`) — Rockchip Vendor Storage or `provision/identity.env` on emulator
4. On Rockchip: working `/dev/vendor_storage` + sealed-blob helpers; emulator uses software secrets backend

**Emulator / QEMU (`sim_virt`):** no Vendor Storage; identity, tunables, and the sealed cloud Ed25519 blob live on virtio **`provision.img`** (`identity.env`, `cloud-ed25519.sealed`). First boot may autogen `SIM######` into `provision/identity.env` (per `provision.img`, not OEM). Secrets use the **software** KEK backend (`boards/sim.json`); board helpers write/read the sealed blob on provision instead of VS ID 22.

**After `make flash` that preserves vendor0–vendor3:** the sealed blob at ID 22
survives; ensure-activated must not regenerate or re-activate as first-time.

## Device Bearer (`access_token`)

After a successful mint, gated Worker calls (`GET /ws/device`,
`GET /v1/devices/:sn/users`, AI report, device R2 STS, …) send
`Authorization: Bearer <access_token>` on the **same v1** paths. Activate and
token mint remain without Bearer. Old “SN-only forever” admission applies only
to sample SNs on the **server** allowlist until those units OTA; new firmware
always mints and sends Bearer when 云服务 is on and a sealed key exists.
