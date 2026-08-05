## 1. Cross-repo contract

- [ ] 1.1 Confirm sibling api-server OpenSpec change `device-ed25519-activate` defines `POST /v1/devices/:sn/activate` and token-mint paths matching design D4
- [ ] 1.2 Freeze wire fields: `public_key` base64(32), activate error cases (unknown SN / already activated same / different key)

## 2. Vendor Storage ID map

- [ ] 2.1 Add ID **22** / `VENDOR_CUSTOM_ID_16` for sealed cloud Ed25519 blob to `board/vendor-storage-ids.txt` and overlay copy under `/usr/libexec/board/`
- [ ] 2.2 Add thin board helper(s) or HAL path to read/write the sealed blob at ID 22 (no plaintext)
- [ ] 2.3 Update `docs/storage-layout.md` ID map note for ID 22

## 3. Device cloud Ed25519 identity (App / HAL)

- [ ] 3.1 Implement Ed25519 keypair generate + raw 32-byte pubkey base64 encode
- [ ] 3.2 Implement seal/unseal of private key via `BoardBindings.secrets()` with AAD `cloud-ed25519-v1` + product SN
- [ ] 3.3 Implement ensure-activated: VS presence check → generate/seal/write → activate POST → immutable retry
- [ ] 3.4 Implement signed access-token mint client against api-server contract (TLS only)
- [ ] 3.5 Gate ensure-activated / token mint on 云服务 + network + pinned origin + non-empty product SN
- [ ] 3.6 Unit/widget or package tests for seal round-trip AAD, no-regenerate-when-present, and activate retry same key

## 4. Runtime wiring

- [ ] 4.1 Hook ensure-activated into cloud runtime when 云服务 enables / network becomes ready
- [ ] 4.2 Document emulator/no-VS behavior (fail closed / skip) in App or HAL notes
- [ ] 4.3 Manual smoke: write-identity → enable 云服务 → activate once → reflash-preserving-VS → still same key / no re-activate
