# Java Integration Guide (Deprecated)

该文档已不再作为当前 Android 集成的权威说明。

请改看以下文档：

- 根目录 `APP_INTEGRATION_GUIDE.md`：App 团队如何消费 `libai_<version>.zip`
- 根目录 `README.md`：仓库维护者如何构建、打包与理解当前工程结构

## Current Canonical Contract

- Java package: `com.lasercyber.lws.ai`
- Native bridge class: `com.lasercyber.lws.ai.NativeBridge`
- Native library naming: `libai.so` (fixed name; load with `System.loadLibrary("ai")`)
- Delivery package: `libai_<version>.zip` (runtime assets and JNI libraries only; no Java source files)
- Java bridge handoff: `NativeBridge.java` is delivered separately and placed at `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java`
- Equivalent beta package: `libai_<version>-beta.zip` (same content, different filename)

如果本文件中的历史描述与上述两份文档冲突，以 `README.md` 和 `APP_INTEGRATION_GUIDE.md` 为准。
