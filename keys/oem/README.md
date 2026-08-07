# OEM TA signing key

Place the Rockchip / Innohi BL32-matched RSA private key here:

```text
keys/oem/vendor_ta.pem
```

`make build-secrets-seal` / `rebuild-secrets-seal` loads this path by default.
Override with `TA_SIGN_KEY=/path/to/other.pem` when needed.

The `*.pem` files in this directory are gitignored — do not commit private keys.
