# ai-native-build-structure Specification

## Purpose
TBD - created by archiving change ai-library-optimization. Update Purpose after archive.
## Requirements
### Requirement: roi_config SHALL compile once via shared static library

Native build SHALL provide `roi_config_common` as a static library containing `src/zero_point/roi_config.cpp`. Both `zero_point_core` and `edgedrawing_core` MUST link `roi_config_common` and MUST NOT compile `roi_config.cpp` independently.

#### Scenario: No duplicate roi_config symbols in libai.so

- **WHEN** `make ai` completes
- **THEN** `roi_config.cpp` object code MUST appear only once in the link graph
- **AND** `verify_libai_jni.sh` MUST pass

### Requirement: libai.so sources SHALL use explicit CMake lists

`native/lensinspector/CMakeLists.txt` MUST list `libai.so` source files explicitly via `set(AI_JNI_SOURCES ...)` or equivalent per-target source lists. `file(GLOB SOURCES src/*.cpp)` MUST NOT be used for `libai.so` production targets (GLOB MAY remain for test-only targets).

#### Scenario: New cpp file requires explicit CMake entry

- **WHEN** a developer adds a new `.cpp` under `src/` intended for `libai.so`
- **THEN** CI `make ai` MUST fail or omit the file until it is added to the explicit source list
- **AND** test `main()` entry points MUST NOT be accidentally linked into `libai.so`

### Requirement: central_scheduler SHALL replace main.cpp naming

The `CentralScheduler` implementation currently in `src/main.cpp` MUST be renamed to `src/central_scheduler.cpp` with a corresponding `central_scheduler.h`. The old `main.cpp` filename MUST NOT remain as the scheduler implementation.

#### Scenario: Build succeeds after rename

- **WHEN** `central_scheduler.cpp` replaces `main.cpp` in CMake sources
- **THEN** `make ai` MUST succeed
- **AND** live stain scheduling behavior MUST be unchanged

### Requirement: Optional native modules SHALL be gated by CMake options

The build SHALL expose at minimum `ENABLE_EDGEDRAWING` (default ON) and `ENABLE_RKNN_STAIN` (default ON). When `ENABLE_EDGEDRAWING` is OFF, `stream_detect_core` MUST NOT link `edgedrawing_core`, and `verify_libai_jni.sh` MUST validate symbols for the active configuration.

#### Scenario: EdgeDrawing disabled reduces binary size

- **WHEN** the build runs with `ENABLE_EDGEDRAWING=OFF`
- **THEN** `libai.so` MUST NOT include EdgeDrawing detect symbols
- **AND** measured `libai.so` size MUST be documentable for comparison against default build

### Requirement: Shared JSON serialization helpers SHALL unify module output

Native code MUST provide shared JSON escape and summary serialization helpers (e.g. `json_escape.h` or extension of `det_callback_json`) used by `stream_detect_event`, `opencv_stain_detect_analyzer`, and other `*_json.cpp` modules to avoid behavioral drift.

#### Scenario: Consistent string escaping across modules

- **WHEN** two detect modules emit JSON containing special characters
- **THEN** both MUST use the shared escape helper
- **AND** MUST produce valid JSON parseable by Java `StreamDetectResultBus`

### Requirement: Build produces lws_ai_daemon executable

Native CMake for `native/lensinspector` (or the AI native root) SHALL define an executable target `lws_ai_daemon` that links the shared AI static libraries needed for the daemon process. The daemon target MUST provide its own `main` entry and MUST NOT accidentally link JNI `JNI_OnLoad`-only product entry as its process main. `make ai` (or the documented AI build target) MUST build this executable for device ABIs used by the App.

#### Scenario: Daemon target builds with make ai

- **WHEN** developers run the AI native build (`make ai` or equivalent)
- **THEN** `lws_ai_daemon` MUST be produced for the configured Android ABI
- **AND** `libai.so` MAY continue to build in parallel until product JNI removal (P3)

#### Scenario: Daemon does not embed test main

- **WHEN** `lws_ai_daemon` is linked
- **THEN** host/test `main()` sources MUST NOT be the daemon entry unless explicitly selected
- **AND** the daemon entry MUST initialize socket servers per the IPC package

### Requirement: APK packaging includes daemon binary

The Android packaging / makefile sync path SHALL install `lws_ai_daemon` into the location used by `AiDaemonSupervisor` spawn (jniLibs extract, assets unpack, or private files copy). Packaging MUST preserve execute bits as required after install.

#### Scenario: Supervisor can locate packaged binary

- **WHEN** an APK built with AI native packaging is installed
- **THEN** Supervisor MUST resolve a readable/executable path to `lws_ai_daemon`
- **AND** spawn MUST not depend on a developer host filesystem path

