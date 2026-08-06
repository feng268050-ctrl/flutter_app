# Device cloud Ed25519 — emulator / no Vendor Storage

Ensure-activated and token mint **require**:

1. 云服务 enabled
2. Pinned **HTTPS** API origin
3. Non-empty **Vendor Storage** product SN (`read-identity sn`)
4. Working `/dev/vendor_storage` + sealed-blob helpers

**Emulator / QEMU (`sim_virt`) and boards without Vendor Storage:** board helpers
exit non-zero (`/dev/vendor_storage` missing). The App coordinator treats this as
**skip** (fail closed) — it does **not** invent an SN, write plaintext keys, or
call activate against production. Local HMI features keep working.

**After `make flash` that preserves vendor0–vendor3:** the sealed blob at ID 22
survives; ensure-activated must not regenerate or re-activate as first-time.
