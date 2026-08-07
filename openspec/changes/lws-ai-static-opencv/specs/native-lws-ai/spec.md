## MODIFIED Requirements

### Requirement: make build-ai stages prebuilt stamp

The build system SHALL provide `make build-ai` that cross-compiles the daemon into `prebuilt/ai/linux-arm64/` with a recognizable prebuilt stamp. The daemon MUST be **statically linked against the project OpenCV prebuilt** produced by `make build-opencv` (static archives). The staged tree MUST NOT include OpenCV shared libraries (`libopencv_*.so*`) under `prebuilt/ai/linux-arm64/lib/`. Link-time RKNN inputs remain `prebuilt/rknn-rt` (`make fetch-rknn-rt`); the staged tree MUST NOT include `librknnrt.so` (product runtime uses `/usr/lib/librknnrt.so`). Missing OpenCV or RKNN inputs MUST fail with a clear message pointing at `make build-opencv` / `make fetch-rknn-rt`.

#### Scenario: Successful stage without OpenCV companions

- **WHEN** OpenCV and RKNN prebuilts are present and `make build-ai` completes
- **THEN** `prebuilt/ai/linux-arm64/lws_ai_daemon` exists and is executable
- **AND** a stamp file exists under that directory for bundle gating
- **AND** no `libopencv_*.so*` files exist under `prebuilt/ai/linux-arm64/`
- **AND** `prebuilt/ai/linux-arm64/lib/librknnrt.so` MUST be absent

#### Scenario: Daemon does not DT_NEEDED OpenCV shared libs

- **WHEN** `lws_ai_daemon` is inspected after a successful `make build-ai`
- **THEN** its dynamic dependency list MUST NOT include any `libopencv_*` shared library
- **AND** MUST still declare a dynamic dependency on `librknnrt.so` (system runtime)

## ADDED Requirements

### Requirement: make build-opencv produces static libraries

`make build-opencv` SHALL cross-compile OpenCV for Linux aarch64 with shared libraries disabled (`BUILD_SHARED_LIBS=OFF`) into `prebuilt/opencv/linux-arm64/`, retaining `OpenCVConfig.cmake` for CMake consumers. The install MUST provide static archives suitable for linking `lws_ai_daemon`. This change MUST NOT require function-level LTO or `--gc-sections` tree-shake; the existing OpenCV `BUILD_LIST` module set MAY remain unchanged.

#### Scenario: Static OpenCV install usable by CMake

- **WHEN** `make build-opencv` completes successfully
- **THEN** `OpenCVConfig.cmake` is present under the prebuilt OpenCV tree
- **AND** the install provides static OpenCV libraries (`.a`) for the configured modules
- **AND** the install MUST NOT be required to ship `libopencv_*.so*` for the AI daemon packaging path
