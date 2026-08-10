## MODIFIED Requirements

### Requirement: make build-ai stages prebuilt stamp

The build system SHALL provide `make build-ai` that cross-compiles the first-party `lws_ai_daemon` into `prebuilt/ai/linux-arm64/` and SHALL stage App-owned companion shared libraries required at runtime **other than** the Rockchip RKNN runtime. Link-time RKNN inputs remain `prebuilt/rknn-rt` (`make fetch-rknn-rt`). The staged `prebuilt/ai/linux-arm64/lib/` tree MUST NOT include `librknnrt.so` (product runtime uses `/usr/lib/librknnrt.so`). Missing OpenCV or RKNN inputs MUST fail with a clear message pointing at `make build-opencv` / `make fetch-rknn-rt`.

`make build-ai` is an app-like product build: after editing `native/lws_ai`, the default operator command SHALL be `make build-ai`. The build MUST NOT skip compilation solely because a `.lws-prebuilt` file exists under the AI prebuilt directory. The build MUST NOT require writing `.lws-prebuilt` for correctness of later `make build-app` packaging.

#### Scenario: Successful stage

- **WHEN** OpenCV and RKNN prebuilts are present and `make build-ai` completes
- **THEN** `prebuilt/ai/linux-arm64/lws_ai_daemon` exists and is executable
- **AND** `prebuilt/ai/linux-arm64/lib/librknnrt.so` MUST be absent

#### Scenario: Source edit uses build-ai

- **WHEN** an operator changes a file under `native/lws_ai` and a prior staged daemon already exists
- **AND** the operator runs `make build-ai`
- **THEN** the build MUST compile/link as needed and restage an updated `prebuilt/ai/linux-arm64/lws_ai_daemon`
- **AND** MUST NOT exit successfully solely because `.lws-prebuilt` was already present

## ADDED Requirements

### Requirement: Incremental CMake build for lws_ai_daemon

`make build-ai` SHALL reuse the cached CMake build directory under `.cache/lws_ai/` for incremental compilation of `lws_ai_daemon` when the configure fingerprint matches and `FORCE` is not set. It MUST NOT delete that build directory on every plain `build-ai`. `make rebuild-ai` and `FORCE=1 make build-ai` SHALL wipe the CMake build tree before configure, then perform a full configure + build + restage, consistent with other repository `rebuild-*` / `FORCE=1` targets. When configure inputs change such that the fingerprint no longer matches, the build SHALL wipe or otherwise reconfigure cleanly before producing a new daemon (MUST NOT silently link against a stale cache for mismatched toolchain/OpenCV/RKNN options). The AI path MUST NOT introduce a separate `CLEAN=` flag for this purpose.

#### Scenario: Second build-ai keeps object cache

- **WHEN** an operator runs a successful `make build-ai`, then changes a single `native/lws_ai` source file and runs `make build-ai` again without `FORCE=1`
- **THEN** the CMake build directory from the previous run MUST still be present for reuse
- **AND** the build MUST restage an updated `prebuilt/ai/linux-arm64/lws_ai_daemon`

#### Scenario: rebuild-ai / FORCE wipes CMake tree

- **WHEN** an operator runs `make rebuild-ai` or `FORCE=1 make build-ai`
- **THEN** the previous CMake build directory MUST be removed before configure
- **AND** a subsequent build MUST recreate it and produce `lws_ai_daemon`

#### Scenario: Fingerprint mismatch forces clean reconfigure

- **WHEN** the recorded configure fingerprint does not match the current toolchain or OpenCV/RKNN configure inputs
- **THEN** the build MUST NOT reuse the stale CMake cache as-is
- **AND** MUST reconfigure (after wipe or equivalent) before staging the daemon
