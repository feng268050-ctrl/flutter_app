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
# Signs with keys/oem/vendor_ta.pem when present (gitignored).
make build-secrets-seal          # or FORCE=1 make rebuild-secrets-seal
# Override path if needed:
TA_SIGN_KEY=/path/to/other.pem FORCE=1 make rebuild-secrets-seal
```

Produces:

- `prebuilt/secrets_seal/aarch64/b8e4f2a1-9c3d-4e6f-8a1b-2c3d4e5f6071.ta`
- `prebuilt/secrets_seal/aarch64/secrets-seal-ca`
- Overlay copies under `usr/lib/optee_armtz/` and `usr/libexec/board/secrets-seal-ca`
  (merged `/usr`; do not use overlay top-level `lib/`)

TA is built against **OP-TEE OS 3.13** `export-ta_arm64` (matches ynh960 BL32
`optee: revision 3.13` / `9f2aca7d`). Default signing key is
`keys/oem/vendor_ta.pem` (BL32-matched vendor RSA). If missing, falls back to
optee_os `keys/default_ta.pem` (rejected by production Rockchip BL32).

### Device note (ynh960 / rk3568_bl32_v2.15)

Vendor BL32 rejects TAs signed with the OP-TEE default test key
(`TEEC_OpenSession` → **`0xffff000f` / `TEEC_ERROR_SECURITY`**). Place the
matching private key at `keys/oem/vendor_ta.pem` (see `keys/oem/README.md`)
before `make rebuild-secrets-seal`.

## Protocol

Same as `/usr/libexec/board/secrets-seal` → execs `secrets-seal-ca` when present:

- `probe` → exit 0 if TEE + TA session OK
- `seal` ← JSON `{"plaintext_b64","aad_b64"}` → one line `blob_b64`
- `unseal` ← JSON `{"blob_b64","aad_b64"}` → one line `plaintext_b64`

Wrong AAD fails closed (non-zero, no plaintext).
