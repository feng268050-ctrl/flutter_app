# Wi‑Fi credential vault — security notes
#
# Change: openspec/changes/wifi-credential-secure-storage
# KEK / Secrets: openspec/changes/hal-secrets-kek-provider → docs/hal-secrets-kek.md

## What this is

Operator Wi‑Fi PSKs are stored in an **encrypted vault** at
`/var/lib/wpa_supplicant/credentials.vault` (→ `/userdata/wpa_supplicant/`).
`wpa_supplicant.conf` keeps non-secret metadata only; networks use
`mem_only_psk=1` so SaveConfig does not write plaintext `psk=`.

At connect / selectSaved / post-wpa-ready restore, HAL unseals via the abstract
Secrets API and injects the PSK into wpa memory over D-Bus.

## Secrets / KEK policy (do not duplicate here)

Vault sealing uses **`BoardBindings.secrets()` → `KekProvider`** only.
Backend selection (hardware OP-TEE vs device-bound software when TEE is
unavailable) is owned by the Secrets change:

- **Docs:** [`docs/hal-secrets-kek.md`](hal-secrets-kek.md)
- **Change:** `openspec/changes/hal-secrets-kek-provider` (and archived twin)
- OEM `board_profile.json` → `secrets_backend`: `software` | `optee`

This Wi‑Fi vault **does not** embed a second OP-TEE or software KEK module.
App Wi‑Fi UI must **not** import `cyber_hal/secrets.dart`.

## Threat model (Wi‑Fi-specific)

| Control | Effect |
|---------|--------|
| Encrypted vault + Secrets AAD (`wifi-psk\\0ssid`) | Conf / userdata dump alone does not yield PSK |
| `mem_only_psk=1` | SaveConfig cannot reintroduce plaintext into conf |
| Migration scrub | Legacy `psk=` lines imported then removed once |
| Forget | Removes wpa network **and** vault entry |

| Residual | Note |
|----------|------|
| wpa process RAM | Association still needs plaintext PSK in memory |
| Root on same device | Can call the same Secrets unseal path; SSH lockdown is separate |
| Factory wipe | Userdata wipe clears vault; operator re-enters PSK |

## What this is / is not

- This is scheme-2 **at-rest** protection for Wi‑Fi operator PSKs.
- This does **not** by itself claim **RED / EN 18031** conformity. KEK
  hardware-first policy and Notified Body evidence live under the Secrets
  change / product technical file — not this document alone.

## Device verification checklist

### 4.2 Basic vault path (any Secrets backend)

1. Connect two PSK SSIDs from Settings / Demo.
2. `grep -E '^\s*psk=' /var/lib/wpa_supplicant/wpa_supplicant.conf` → empty.
3. Confirm `credentials.vault` exists and does not contain the passphrase as
   plaintext (`strings` / visual check).
4. Reboot with Wi‑Fi wanted; Auto Join associates without re-entering PSK.
5. Forget one SSID; vault entry for that SSID is gone; conf network block gone.

### 4.3 OP-TEE vault smoke (ynh960 default)

1. Board profile uses `"secrets_backend": "optee"` (ynh960 OEM default) and
   vendor-signed seal TA (`keys/oem/vendor_ta.pem`).
2. If the unit previously sealed with software KEK, run
   `make migrate-secrets` (or `SCOPE=wifi` / `SCOPE=cloud`) once.
3. Connect or migrate so vault entries seal with OP-TEE backend.
4. Unseal / reconnect after reboot; `backendId` diagnostics show `optee`.
5. See Secrets notes for TA signing / `tee-supplicant` prerequisites.
   Existing **software**-sealed vault blobs will not unseal after the flip
   without `make migrate-secrets` (or re-entering PSKs).
