## ADDED Requirements

### Requirement: make register-device registers SN and model via admin API

The host build system SHALL provide **`make register-device`** that registers the selected board with sibling **api-server** using **`POST /v1/admin/devices`**. The JSON body SHALL be **`{ "sn", "model" }`** with non-empty trimmed strings. The request SHALL use **`Authorization: Bearer <token>`** resolved per **`host-cloud-login`** shared token rules. The API base URL SHALL use the same **`CLOUD_API_BASE`** as login. On success, the command SHALL print enough of the ApiResult **`DeviceInfo`** (at least **`sn`**, **`model`**, and activation-related fields when present) for the operator to confirm registration. On **409** (active SN conflict), **403** (insufficient role), **401** (bad/expired token), or other failures, the command SHALL exit non-zero with the Worker error message/code when available. The command MUST NOT send or require an Ed25519 **`public_key`** on this path (activation remains a separate device-facing flow).

#### Scenario: Successful admin register

- **WHEN** the operator has a valid operator/admin token from `make login`
- **AND** the selected board reports sn `LC-001` and model `L1 Pro`
- **AND** that SN is not already an active device
- **THEN** `make register-device` SHALL POST `{ "sn": "LC-001", "model": "L1 Pro" }` to `/v1/admin/devices`
- **AND** SHALL exit zero after a successful ApiResult

#### Scenario: Duplicate SN fails clearly

- **WHEN** the Worker responds **409** because the SN is already registered and active
- **THEN** `make register-device` SHALL exit non-zero
- **AND** SHALL surface a conflict error suitable for operators

#### Scenario: Expired token points to re-login

- **WHEN** the Worker responds **401** for the register call
- **THEN** the command SHALL exit non-zero
- **AND** SHOULD advise running `make login` again

### Requirement: register-device reads identity over SSH before calling the API

Before calling the admin register API, **`make register-device`** SHALL select a board using the same host device-selection rules as **`make write-identity` / `push-app` / `shell`** (`SN=` / `IP=` / USB-SSH as applicable; **`CHIP_ID=` MUST NOT be accepted** as a selector). The host SHALL SSH to the target and read product **`sn`** and **`model`** via on-board **`read-identity`** (or the equivalent `/usr/libexec/board/read-product-identity.sh` helpers). If either value is empty/missing, the command SHALL fail and point operators to **`make write-identity`**. The command MUST NOT accept **`PRODUCT_SN=`**, **`MODEL=`**, or **`BRAND=`** as identity payload overrides (those belong to **`make write-identity`**). Device-selection **`SN=`** SHALL only choose which board to SSH to; the admin POST body **`sn`** / **`model`** SHALL always come from Vendor Storage via **`read-identity`**, not from inventing values from the selection `SN=` alone when they differ.

#### Scenario: SSH identity drives register body

- **WHEN** Vendor Storage on the board selected by `SN=` has sn `LC-001` and model `YNH960`
- **AND** the operator runs `SN=<selection> make register-device`
- **THEN** the admin POST body SHALL use sn `LC-001` and model `YNH960`

#### Scenario: Missing model refuses register

- **WHEN** SSH `read-identity model` returns empty
- **THEN** `make register-device` SHALL exit non-zero without calling the admin API
- **AND** the error SHALL mention `make write-identity`

#### Scenario: PRODUCT_SN override is refused

- **WHEN** the operator runs `PRODUCT_SN=LC-OVERRIDE make register-device`
- **THEN** the command SHALL exit non-zero without calling the admin API
- **AND** the error SHALL point operators to `SN=` selection and `make write-identity`