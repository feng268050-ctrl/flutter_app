## Why

当前工艺库资产原先支持单个 `.xlsx` 文件；新工艺库改为 zip 打包并包含多型号文件。需要在保持原单 `xlsx` 兼容的同时，新增 zip 解析与按型号选择能力。

## What Changes

- 更新构建流程：`process-library` 按后缀分支处理，`.xlsx` 直接落盘，`.zip` 解压到 `assets/process-library/`。
- 更新启动导入流程：按资产形态分支导入；单 `xlsx` 走原路径，多文件目录按设备型号选择对应 `.xlsx` 后导入。
- 增加型号规范化：设备型号用于匹配文件名时需去除 `LaserCyber` 前缀并做空白/大小写容错。
- 保持版本比较与导入落库语义不变：仍基于 `DeviceInfo.processLibVersion` 与资产版本比较，导入后更新版本字段。
- 当型号文件缺失时提供可诊断行为（日志与回退策略），避免静默失败。

## Capabilities

### New Capabilities
- `process-lib-model-specific-selection`: 启动时按设备型号选择对应工艺库文件并导入，含型号标准化与缺失回退规则。

### Modified Capabilities
- `build-bundled-libraries`: process-library 资产改为支持 `.xlsx/.zip` 双后缀分支处理。
- `startup-bundled-library-import`: process-library 启动导入改为支持“单 xlsx 直导入 + 多文件目录按型号选择”。

## Impact

- 构建脚本与打包流程（`make build` 相关脚本/Makefile）。
- 启动导入链路（`BundledLibraryBootstrap`、`ProcessLibraryImporter` 及版本比较辅助逻辑）。
- 设备型号读取与标准化逻辑（使用现有设备信息，新增 `LaserCyber` 前缀剥离规则）。
- 工艺库资产组织方式：兼容单文件 xlsx 与 zip 解压后的多型号 xlsx 目录结构。
