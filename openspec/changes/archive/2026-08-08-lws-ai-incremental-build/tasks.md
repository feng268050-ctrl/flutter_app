## 1. App-like build-ai (no stamp skip)

- [x] 1.1 Remove “`.lws-prebuilt` present → exit 0” skip in `scripts/build-ai.sh`
- [x] 1.2 Make plain `make build-ai` always enter incremental configure/build/restage (keep cmake tree)
- [x] 1.3 Stop writing AI `.lws-prebuilt`; fix any manifest helper that assumed it

## 2. Bundle on binary, not stamp

- [x] 2.1 Change `hmi_bundle_install_ai` to gate on executable `lws_ai_daemon` only
- [x] 2.2 Keep `REQUIRE_AI=1` failure message pointing at `make build-ai` when binary missing

## 3. Incremental vs rebuild-ai / FORCE

- [x] 3.1 Remove unconditional `rm -rf` from the default (non-FORCE) path
- [x] 3.2 On `FORCE=1` / `make rebuild-ai`, wipe cmake dir then full configure + build + restage
- [x] 3.3 Do not add a `CLEAN=` flag; keep Makefile `rebuild-ai` as `FORCE=1`

## 4. Configure fingerprint

- [x] 4.1 Record fingerprint (toolchain + OpenCV/RKNN + key `-D`s) under `.cache/lws_ai/`
- [x] 4.2 On mismatch, wipe/reconfigure (same as FORCE clean path); update fingerprint after success

## 5. Docs / help

- [x] 5.1 README + Makefile + AGENTS: daily `make build-ai` → `make build-app`; `make rebuild-ai` / `FORCE=1` for force clean rebuild (like other `rebuild-*`)

## 6. Verify

- [x] 6.1 Edit one AI `.cpp`, `make build-ai` restages daemon; cmake dir retained
- [x] 6.2 `make build-app` picks up daemon with **no** `.lws-prebuilt`
- [x] 6.3 Second `make build-ai` faster than `make rebuild-ai`
- [x] 6.4 `make rebuild-ai` wipes cmake and rebuilds; fingerprint-mismatch path works
