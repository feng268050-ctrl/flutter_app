## Context

Today PSKs are written by wpa `SaveConfig` into `/var/lib/wpa_supplicant/wpa_supplicant.conf` (→ `/userdata/wpa_supplicant/`), mode `600`. HAL passes the operator passphrase as D-Bus Network `psk`. Multi-profile My Networks is already in place.

**Dependency:** KEK seal/unseal, OP-TEE vs interim backends, and board selection are owned by sibling change **`hal-secrets-kek-provider`** (`hal-secrets-kek`). This change owns the Wi‑Fi-specific vault, `mem_only_psk`, inject into wpa, and migration from plaintext conf.

Stakeholders: product security / EU RED readiness; HAL Wi‑Fi; overlay wpa unit. Constraints: Flutter/HAL on Linux appliance; no NetworkManager; wpa still needs plaintext PSK **in memory** to associate.

## Goals / Non-Goals

**Goals:**
- At-rest Wi‑Fi secrets as encrypted vault blobs (scheme 2), sealed via HAL Secrets API
- No passphrase/PSK persisted in `wpa_supplicant.conf` after connect/SaveConfig
- Decrypt/unseal → inject at connect / selectSaved / post-wpa-start restore
- Migrate existing plaintext conf entries; Forget clears vault + network
- Wi‑Fi-specific threat-model notes (point to Secrets change for KEK/RED interim disclaimer)

**Non-Goals:**
- Implementing OP-TEE / KekProvider / PKCS#11 (→ `hal-secrets-kek-provider`)
- Full-disk userdata encryption as the primary control
- Desktop keyring; operator Wi‑Fi UX redesign
- Self-declaring RED conformity
- Encrypting proxy/cloud secrets in this change (reuse Secrets later)

## Decisions

### D1 — Vault owns Wi‑Fi secrets; wpa conf owns non-secret metadata

**Choice:** Persist SSID / `key_mgmt` / `disabled` (Auto Join) / `scan_ssid` / priority in `wpa_supplicant.conf`. Persist passphrase/PSK only in an encrypted vault under `/var/lib/wpa_supplicant/` (e.g. `credentials.vault`), with DEK or per-secret ciphertext sealed through HAL Secrets.

**Why:** Multi-profile D-Bus list stays intact; plaintext leaves conf.

### D2 — `mem_only_psk=1` on saved networks

**Choice:** Set `mem_only_psk=1` when injecting PSK so SaveConfig does not write `psk=` into conf.

**Why:** Native wpa feature; pairs with vault.

### D3 — KEK via HAL Secrets (not duplicated here)

**Choice:** Vault calls abstract Secrets seal/unseal for wrapping vault payload or per-SSID secrets. Backend (OP-TEE vs interim) is selected by board profile in the Secrets change.

**Why:** Single KEK story for Wi‑Fi and future secrets; avoids two Tee integrations.

**Alternatives:** Embed TeeKekProvider in Wi‑Fi module — rejected (duplication; superseded by `hal-secrets-kek-provider`).

### D4 — Inject timing

**Choice:**
- **connect / selectSaved:** unseal for that SSID → SetNetwork `psk` + `mem_only_psk` → SelectNetwork → SaveConfig (metadata only).
- **After wpa D-Bus ready:** inject all Auto Join vault secrets for reboot reconnect.

### D5 — Vault format

**Choice:** Versioned envelope with ciphertext map `ssid → secret` (or sealed whole-file payload); atomic rename. AAD SHOULD bind device identity + purpose (`wifi-psk`) via Secrets API.

### D6 — Logging and process memory

**Choice:** Never log PSK. Clear Dart strings where practical after inject; wpa RAM residual risk documented.

### D7 — Scope

**Choice:** Wi‑Fi operator PSK only in this change.

## Risks / Trade-offs

- [Secrets change not yet applied] → Implement vault against abstract Secrets + fake/interim; block production OP-TEE path on Secrets spike.
- [SaveConfig writes psk if mem_only_psk omitted] → Assert conf scrub in tests; migration rewriter.
- [Boot inject race] → After wpa D-Bus up; retry.
- [Factory wipe] → Userdata wipe clears vault; recovery = re-enter PSK.
- [Root dumps wpa memory] → Residual; production SSH lockdown separate.

## Migration Plan

1. Land/consume Secrets API (sibling change).
2. Deploy vault + `mem_only_psk` connect/selectSaved/boot inject.
3. Migrate plaintext `psk=` → vault + scrub conf.
4. When Secrets OP-TEE backend enabled: re-seal vault with hardware-bound backend (version bump).
5. Rollback: do not reintroduce plaintext SaveConfig; worst case wipe vault and re-enter PSK.

## Open Questions

- Boot inject in HAL only vs `/usr/libexec/wpa/` helper before HMI — same as before; prefer HAL unless Auto Join-before-HMI is required.
- Single vault file vs `credentials.d/` — default single file.
