## 1. Shared cloud credential helpers

- [ ] 1.1 Add gitignored credentials path under `output/cloud/` (update `.gitignore`) and document `CLOUD_API_BASE` / `CLOUD_ACCESS_TOKEN` / `CLOUD_ACCOUNT` / `CLOUD_PASSWORD` in `.env.example`
- [ ] 1.2 Implement a small shared host helper (sourced by login/register/publish) to resolve API base, read/write credentials JSON (`chmod 600`), and resolve Bearer token (env override → file → fail with `make login` hint)

## 2. make login

- [ ] 2.1 Implement `scripts/cloud-login.sh` (or equivalent): TTY prompts or env account/password → `POST /v1/login` → persist `access_token` (+ optional account/role/api_base/updated_at); never persist password; fail-fast on ApiResult errors without clobbering a prior good token on failure
- [ ] 2.2 Wire Makefile target `login` with `WITH_DOTENV` and `make help` text

## 3. make register-device

- [ ] 3.1 Implement `scripts/register-device.sh`: reuse USB-SSH / device-target selection; SSH `read-identity` for sn + model; honor optional `PRODUCT_SN=` / `MODEL=` overrides; refuse empty identity with `write-identity` guidance
- [ ] 3.2 Call `POST /v1/admin/devices` with Bearer token from shared helper; print key DeviceInfo fields on success; map 401/403/409 to clear errors
- [ ] 3.3 Wire Makefile target `register-device` with `WITH_DOTENV`, device-selection vars, and `make help` text

## 4. Docs and sibling publish alignment

- [ ] 4.1 Update README Make-commands, `docs/make-commands.md`, and AGENTS.md rebuild table for `login` / `register-device` (host-only; no firmware rebuild)
- [ ] 4.2 Update sibling change `make-publish-ota` design/tasks (and implementation when present) so publish token resolution uses shared helper: `PUBLISH_API_TOKEN` override first, else login credentials file, else fail pointing to `make login` / static token docs

## 5. Verification

- [ ] 5.1 Smoke `make login` against test `CLOUD_API_BASE` (interactive or env); confirm credentials file mode and contents omit password
- [ ] 5.2 Smoke `make register-device` on a board with `write-identity` done; confirm Worker inventory shows the SN; confirm duplicate run yields clear 409
- [ ] 5.3 Confirm missing-token and empty-model paths fail before/without incorrect API calls as specified
