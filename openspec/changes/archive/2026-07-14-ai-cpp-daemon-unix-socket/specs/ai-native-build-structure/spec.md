## ADDED Requirements

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
