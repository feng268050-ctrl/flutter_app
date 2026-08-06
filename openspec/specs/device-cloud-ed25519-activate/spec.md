# device-cloud-ed25519-activate Specification

## Purpose

First-online device cloud Ed25519 identity on the HMI: generate keypair, seal private key via HAL Secrets into Vendor Storage, call api-server activate, and mint signed device access tokens over TLS — gated by 云服务.

## Requirements

### Requirement: First-online Ed25519 key generation when sealed blob absent

When cloud services (云服务) is enabled, a suitable network is available, an API origin is pinned, and Vendor Storage product SN is non-empty, the system SHALL ensure a device cloud Ed25519 identity exists. If Vendor Storage has no sealed cloud private-key blob at the documented ID, the system SHALL generate a new Ed25519 keypair, seal the private key with HAL Secrets using AAD that includes purpose `cloud-ed25519-v1` and that product SN, write the sealed blob to Vendor Storage **before** calling activate, then submit activate with the matching public key. The system MUST NOT generate a new keypair when a sealed blob is already present.

#### Scenario: Generate seal and activate on first online

- **WHEN** 云服务 is on, network and origin are ready, product SN is `ABC123`, and no sealed cloud key blob exists
- **THEN** the system MUST generate an Ed25519 keypair, persist a Secrets-sealed blob bound to SN `ABC123`, and call activate with SN `ABC123` and the corresponding public key

#### Scenario: Existing sealed blob skips generation

- **WHEN** a sealed cloud key blob is already present in Vendor Storage
- **THEN** the system MUST NOT generate a new keypair and MUST NOT overwrite the sealed blob

#### Scenario: Empty product SN blocks generation

- **WHEN** Vendor Storage product SN is empty
- **THEN** the system MUST NOT generate a cloud keypair or call activate

### Requirement: Activate uses raw Ed25519 public key encoding

The activate request public key SHALL be the standard **base64** encoding of the raw **32-byte** Ed25519 public key. The HTTP contract SHALL match the api-server device activate capability (`POST /v1/devices/:sn/activate` with snake_case JSON `public_key`).

#### Scenario: Public key wire form

- **WHEN** the device builds an activate body
- **THEN** `public_key` MUST be base64 of exactly 32 raw public-key bytes

### Requirement: Activate retry keeps the same keypair

If activate fails after the sealed blob was written, subsequent retries SHALL unseal the existing key and resubmit the **same** public key. The system MUST NOT rotate keys because of transport or server errors. If the server reports already activated with the same public key, the client SHALL treat the outcome as success. If the server reports already activated with a different public key, the client SHALL fail closed and MUST NOT overwrite the local sealed blob.

#### Scenario: Retry after network failure

- **WHEN** sealed blob write succeeded and activate failed due to network error
- **THEN** the next ensure-activated attempt MUST reuse the same keypair and public key

#### Scenario: Foreign activation conflict

- **WHEN** the server indicates the SN is activated under a different public key
- **THEN** the client MUST NOT regenerate or replace the local sealed private key

### Requirement: Signed access-token mint over TLS

After a usable Ed25519 private key exists (and activation has succeeded or is confirmed), the device SHALL obtain a device `access_token` by signing the server-specified canonical message with that private key and calling the api-server token endpoint over the pinned HTTPS origin. The system MUST NOT attempt to decrypt the token with the device key; the token is delivered as a normal TLS response body field.

#### Scenario: Token mint uses signature

- **WHEN** the device needs a device access token and holds the sealed cloud private key
- **THEN** it MUST sign the canonical mint message with Ed25519 and submit that signature per the server contract
- **AND THEN** it MUST accept `access_token` from the TLS response without device-pubkey decryption

### Requirement: Cloud key immutability and flash survival

The sealed cloud private-key blob in Vendor Storage SHALL be treated as write-once for normal operation. Factory flash that preserves Vendor Storage geometry and omits vendor payloads SHALL leave the sealed blob intact so the device remains the same cryptographic identity without re-activation. Changing product SN via `FORCE` write-identity MUST NOT silently reseal or regenerate the cloud key under the new SN.

#### Scenario: Reflash keeps identity

- **WHEN** a sealed cloud key exists and the operator runs a compliant `make flash` that does not overwrite Vendor Storage
- **THEN** after reboot the device MUST still unseal the same private key and MUST NOT call activate as a first-time generation

### Requirement: Gating by cloud services preference

Ensure-activated and token mint for cloud identity SHALL run only while 云服务 is enabled. While 云服务 is disabled, the system MUST NOT generate keys, call activate, or mint device access tokens for this capability.

#### Scenario: Cloud services off

- **WHEN** 云服务 is disabled
- **THEN** the system MUST NOT perform Ed25519 generate/activate/token-mint for cloud identity
