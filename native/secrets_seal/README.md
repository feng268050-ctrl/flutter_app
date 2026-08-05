# secrets-seal CA + TA (OP-TEE)

Native Client Application + Trusted Application for HAL Secrets seal/unseal.

## Layout

```
native/secrets_seal/
  include/seal_ta.h   # UUID + commands (shared)
  ta/                 # User TA — AES-GCM + TEE secure-storage KEK
  host/               # CA — libteec JSON stdin / b64 stdout
  README.md
```

## Build

```bash
make build-secrets-seal          # or FORCE=1 make rebuild-secrets-seal
# Optional: sign with vendor key (required for Rockchip rkbin BL32):
TA_SIGN_KEY=/path/to/vendor_ta.pem FORCE=1 make rebuild-secrets-seal
```

Produces:

- `prebuilt/secrets_seal/aarch64/b8e4f2a1-9c3d-4e6f-8a1b-2c3d4e5f6071.ta`
- `prebuilt/secrets_seal/aarch64/secrets-seal-ca`
- Overlay copies under `usr/lib/optee_armtz/` and `usr/libexec/board/secrets-seal-ca`
  (merged `/usr`; do not use overlay top-level `lib/`)

TA is built against **OP-TEE OS 3.13** `export-ta_arm64` (matches ynh960 BL32
`optee: revision 3.13` / `9f2aca7d`). Default signing uses optee_os
`keys/default_ta.pem`.

### Device note (ynh960 / rk3568_bl32_v2.15)

Hot-deploy smoke (2026-08-01): `tee-supplicant` + `/dev/tee*` OK, but
`TEEC_OpenSession` returns **`0xffff000f` (TEEC_ERROR_SECURITY)** — vendor BL32
rejects TAs signed with the OP-TEE default test key. **Need Innohi/Rockchip
`TA_SIGN_KEY`** (or a BL32 built with our public key) before seal/unseal works
on hardware.

## Protocol

Same as `/usr/libexec/board/secrets-seal` → execs `secrets-seal-ca` when present:

- `probe` → exit 0 if TEE + TA session OK
- `seal` ← JSON `{"plaintext_b64","aad_b64"}` → one line `blob_b64`
- `unseal` ← JSON `{"blob_b64","aad_b64"}` → one line `plaintext_b64`

Wrong AAD fails closed (non-zero, no plaintext).
