## ADDED Requirements

### Requirement: Source tree lives under native/lws_ai

The repository SHALL vendor the welding AI C++ engine under `native/lws_ai/` (migrated from lws-ui `native/lensinspector`). The tree MUST include a top-level `CMakeLists.txt` that can produce `libai.so` and/or `lws_ai_daemon` for Linux aarch64. Android-only packaging scripts MAY remain unused on this product.

#### Scenario: Tree present for Linux maintainers

- **WHEN** a developer clones the repository
- **THEN** `native/lws_ai/CMakeLists.txt` exists
- **AND** `native/lws_ai/README.md` documents the Linux build entry (`make build-ai`)

### Requirement: Linux aarch64 daemon CMake target

The CMake build SHALL be able to build executable `lws_ai_daemon` when targeting Linux aarch64 (not only Android). The binary MUST be linkable against the project’s OpenCV and RKNN runtime inputs without requiring the Android NDK `log` library.

#### Scenario: Daemon target enabled off Android

- **WHEN** CMake is configured for Linux aarch64 with `BUILD_LWS_AI_DAEMON=ON`
- **THEN** the `lws_ai_daemon` target MUST be defined and buildable
- **AND** MUST NOT require linking Android `log`

### Requirement: make build-ai stages prebuilt stamp

The build system SHALL provide `make build-ai` that cross-compiles the daemon (and required companion shared libraries) into `prebuilt/ai/linux-arm64/` with a recognizable prebuilt stamp. Missing OpenCV or RKNN inputs MUST fail with a clear message pointing at `make build-opencv` / `make fetch-rknn-rt`.

#### Scenario: Successful stage

- **WHEN** OpenCV and RKNN prebuilts are present and `make build-ai` completes
- **THEN** `prebuilt/ai/linux-arm64/lws_ai_daemon` exists and is executable
- **AND** a stamp file exists under that directory for bundle gating
