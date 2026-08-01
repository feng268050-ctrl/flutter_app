## Why

Wi‑Fi PSKs today land in plaintext in `wpa_supplicant.conf` under userdata (`chmod 600` only). That is weak against root/SSH extraction and is unlikely to satisfy RED Delegated Regulation (EU) 2022/30 / EN 18031 expectations for a Secure Storage Mechanism on internet-connected radio equipment. We need encrypted at-rest credentials (scheme 2: encrypted blob + runtime unwrap into wpa) before EU market claims.

## What Changes

- Introduce a **secure Wi‑Fi credential vault**: per-SSID secrets as encrypted blobs on userdata; plaintext PSK MUST NOT remain in `wpa_supplicant.conf` after SaveConfig
- Use wpa `mem_only_psk=1` (or equivalent) so SaveConfig never writes passphrase/PSK to the conf file
- At connect / selectSaved / boot restore: unseal via HAL Secrets → inject PSK into the matching wpa network via D-Bus → associate; never log PSK
- **Depend on** sibling change `hal-secrets-kek-provider` for KEK seal/unseal (OP-TEE preferred, interim software for bring-up) — this change does **not** own Tee/KekProvider implementation
- One-shot **migration**: existing plaintext `psk=` entries moved into the vault and stripped from conf
- Forget deletes both the wpa network and the vault entry
- Technical-file oriented notes for Wi‑Fi vault threat model — not a self-declaration of conformity

## Capabilities

### New Capabilities
- `wifi-credential-secure-storage`: Wi‑Fi vault format, mem_only_psk, inject/migration/forget lifecycle; consumes `hal-secrets-kek` for sealing

### Modified Capabilities
- `linux-wifi`: Credential persistence MUST use the vault + Secrets unseal; plaintext PSK in `wpa_supplicant.conf` is forbidden after migration

## Impact

- HAL: Wi‑Fi session / D-Bus connect path; Wi‑Fi credential vault module calling abstract Secrets API
- Requires / pairs with: `openspec/changes/hal-secrets-kek-provider`
- Overlay: `run-wpa.sh` / boot restore hooks to reinject PSKs after wpa start; conf templates stay PSK-free
- App: no operator UX change; Forget/My Networks via HAL
- Docs: storage layout + Wi‑Fi vault notes; RED KEK details live primarily under the Secrets change
- Does **not** by itself certify RED conformity
