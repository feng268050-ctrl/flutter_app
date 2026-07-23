## Why

YOLO/native 已调整 `nativeInferImageAndSave` 的语义：成功执行（JNI、读图、推理、落盘）统一返回 `0`；`CLEAN` / `LIGHT` / `HEAVY` 等检测结论不再通过整型错误码表达。若 App 仍用返回码区分“脏净”或 expect 非零“成功”，会出现误判、错误文案和测试不稳定。需要把 native 与 App 的契约对齐，并明确检测结论的交付方式（回调或结果侧车文件）。

## What Changes

- **Native (lensinspector / 交付 libai.so)**：`nativeInferImageAndSave` 仅表示管线是否成功；检测等级/状态通过现有 listener 回调或侧车 JSON 输出，**不**用返回码承载 `HEAVY`/`CLEAN` 等结论。
- **return 码（约定）**：
  - `0`：调用、推理、保存结果图均成功（与检测等级无关）。
  - `-1`：参数错误
  - `-2`：图片读取失败
  - `-3`：模型推理失败
  - `-4`：保存结果图失败
- **App (`LensGuardManager` 等)**：`code == 0` 为执行成功；失败时用 `switch` 映射用户可读文案；成功路径仍校验输出文件存在且非空；业务展示 `HEAVY`/`LIGHT`/`CLEAN` 不依赖 `nativeCode`，而依赖回调或 `*_result.json`（若实现）。
- **Instrumented 测试**：在 `native` 返回 `0` 为唯一成功码后，现有 `isSuccess` + 输出文件校验可稳定计数成功。

**BREAKING**：依赖“非零表示某种检测状态”或旧成功码的调用方需迁移；返回码与检测结论解耦后，只认 `0`/负错误码。

## Capabilities

### New Capabilities

- `native-infer-image-contract`：定义 `nativeInferImageAndSave` 的整型返回语义、成功条件，以及检测结论的交付面（事件回调与/或结果目录 JSON 文件格式）。

### Modified Capabilities

- _（无：现有 `openspec/specs/` 中无同名“单图推理 JNI 合同” spec；本变更以新增能力为主。若后续将“诊断回调”纳入 `ai-rknn-native-call-safety`，可再开 delta 变更。）_

## Impact

- **Native**：`jni_bridge.cpp`（或等效）中 `nativeInferImageAndSave` 的返回值与日志；若提供 JSON 侧车，与 `CentralScheduler::inferImageAndSave` 协同。
- **App**：`NativeBridge.guardedInferImageAndSave` 诊断文案、`LensGuardManager.inferJpgAndSaveResult`、可能的事件订阅或结果文件读取。
- **测试**：`InferPicturesDirectoryInstrumentedTest` 与相关集成测试的期望与说明。
- **依赖**：与 YOLO/算法包版本同步发布，避免旧 `libai.so` 与 App 新契约混用。
