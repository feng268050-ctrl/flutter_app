## ADDED Requirements

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
