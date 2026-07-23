## ADDED Requirements

### Requirement: ZIP 包解压部署

YOLO 团队以 ZIP 包（`lens_guard_engine_v1.0.0.zip` 等）形式提供引擎的 **native 与配置** 文件。App 侧 SHALL 将 ZIP 包内容解压并合并到 `app/src/main/` 目录，路径一一对应。

ZIP 包内容（不再要求包含 `java/`）：
- `assets/config.yaml` → `app/src/main/assets/config.yaml`
- `jniLibs/arm64-v8a/libai.so` → `app/src/main/jniLibs/arm64-v8a/libai.so`
- `jniLibs/arm64-v8a/libc++_shared.so` → `app/src/main/jniLibs/arm64-v8a/libc++_shared.so`
- `jniLibs/arm64-v8a/librknnrt.so` → `app/src/main/jniLibs/arm64-v8a/librknnrt.so`

`NativeBridge.java` SHALL 由本仓库维护：`app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java`，包名 **`com.lasercyber.lws.ai`**。YOLO 更新 JNI 时，App 侧 SHALL 同步核对该类中的 `native` 声明与 `System.loadLibrary` 顺序。

#### Scenario: ZIP 解压后编译通过
- **WHEN** ZIP 包内容被正确合并到 `app/src/main/`，且仓库内 `NativeBridge.java` 与当前 `.so` 匹配
- **THEN** 项目 SHALL 能正常编译，`NativeBridge` 类 SHALL 可被 App 侧代码 import

#### Scenario: .so 库加载成功
- **WHEN** APK 安装到 arm64-v8a 设备上
- **THEN** `System.loadLibrary` SHALL 成功加载 **`libai.so`**（在静态块中于 `c++_shared`、`rknnrt` 之后加载）

### Requirement: NativeBridge 与本仓库及 YOLO JNI 对齐

`NativeBridge.java`（包路径 **`com.lasercyber.lws.ai`**）SHALL 在本仓库中维护，并与 YOLO 交付的 `libai.so` JNI 符号一致。该类包含：
- 静态块：`System.loadLibrary("c++_shared")`、`System.loadLibrary("rknnrt")`、`System.loadLibrary("ai")`
- 生命周期 native 方法：`nativeCreate`、`nativeSetListener`、`nativeStart`、`nativeStop`、`nativeDestroy`
- 数据推送 native 方法：`nativePushFrame`、`nativeSetLaserOn`
- 状态查询 native 方法：`nativeGetState`、`nativeGetStainLevel`、`nativeIsLensDirty`
- `NativeListener` 内部接口：`onStateChanged`、`onCheckResult`、`onAlert`

#### Scenario: App 侧正确引用 NativeBridge
- **WHEN** App 侧代码需要调用引擎
- **THEN** SHALL 通过 `import com.lasercyber.lws.ai.NativeBridge` 引入

### Requirement: ZIP 更新流程

当 YOLO 团队发布新版本 ZIP 包时，App 侧 SHALL 用新包中的 `jniLibs/`、`assets/` 覆盖对应路径，并核对 **`NativeBridge.java`** 是否需要随 JNI 变更而更新，确保 `.so` 与 Java 声明同步。

#### Scenario: 版本升级
- **WHEN** 收到新版 ZIP 包（如 `lens_guard_engine_v1.1.0.zip`）
- **THEN** SHALL 将新的 `.so` 与 `config.yaml` 覆盖到对应路径；若 YOLO 仍使用固定名 `libai.so`，`loadLibrary("ai")` 无需随 ZIP 文件名改动
