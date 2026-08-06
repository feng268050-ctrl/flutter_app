# host-cloud-login Specification

## Purpose

Host `make login` against sibling api-server, plus shared Bearer token resolution for register-device / publish.

## Requirements

### Requirement: make login authenticates against api-server and persists access_token

The host build system SHALL provide **`make login`** that authenticates an operator against sibling **api-server** at **`POST /v1/login`**. The request body SHALL be JSON **`{ "account", "password" }`** (`account` = username or email). On HTTP success with **ApiResult** `data.access_token`, the host SHALL persist at least **`access_token`** to a **gitignored** credentials file under the repo (default path documented as **`output/cloud/credentials.json`** or equivalent), with file mode restricting access to the owner when the filesystem supports it. The host MUST NOT persist the password. When a TTY is available and account/password are not supplied via documented env vars, the command SHALL prompt for account and password (password input SHALL NOT echo). The API base URL SHALL come from **`CLOUD_API_BASE`** (env / `.env`, no trailing slash), defaulting to the documented **production** Worker origin (`https://api-prod.lasercyber.workers.dev`). On auth failure (**404** / **401** / **403** or other non-success ApiResult), the command SHALL exit non-zero with a clear error and MUST NOT overwrite a previous good token with an empty value.

#### Scenario: Interactive login stores token

- **WHEN** the operator runs `make login`, enters a valid account and password, and the Worker returns success with `access_token`
- **THEN** the credentials file SHALL contain that `access_token`
- **AND** the password SHALL NOT appear in the credentials file

#### Scenario: Failed login leaves prior token intact

- **WHEN** a credentials file already holds a token and `make login` receives **401** `INVALID_PASSWORD`
- **THEN** the command SHALL exit non-zero
- **AND** the previous token file contents SHALL remain usable

#### Scenario: Non-interactive credentials via env

- **WHEN** the operator runs `make login` with documented `CLOUD_ACCOUNT` and `CLOUD_PASSWORD` set
- **THEN** the command SHALL NOT require a TTY prompt for those values
- **AND** SHALL still persist only the returned `access_token` (not the password)

### Requirement: Shared token resolution for publish and register-device

Consumers of the cloud user session on the host (**`make register-device`**, and **`make publish` / `publish-only`** when implemented) SHALL resolve the Bearer token in this order: (1) an explicit documented env override for that command when set (e.g. **`CLOUD_ACCESS_TOKEN`** or publish-specific **`PUBLISH_API_TOKEN`**), (2) the **`access_token`** from the login credentials file, (3) otherwise fail with a message that points operators to **`make login`**. Makefile `help`, README, and make-commands docs SHALL describe this shared login flow.

#### Scenario: register-device uses saved login token

- **WHEN** `make login` has stored a valid token and no explicit token env override is set
- **AND** the operator runs `make register-device` against a reachable board with identity provisioned
- **THEN** the admin register HTTP call SHALL send `Authorization: Bearer <saved access_token>`

#### Scenario: Missing token fails fast

- **WHEN** no credentials file exists and no token env override is set
- **AND** the operator runs `make register-device`
- **THEN** the command SHALL exit non-zero before SSH/register
- **AND** the error SHALL mention `make login`
