## Context

当前 AI 初始化和推理链路包含多个模块：`BundledLibraryBootstrap` 负责解压资产，`NativeBridge.ensureLoaded` 负责按版本目录加载 so，`AssetDeployer` 负责准备 `config.yaml`，`LensGuardManager` 负责创建引擎并执行推理。

实测表明这几处约定存在偏差：版本目录格式不一致（`1.0` vs `1.0.0`）、配置文件部署不稳定、异常输入下 native 可能崩溃。问题会连锁放大并阻断上传链路。

## Goals / Non-Goals

**Goals:**
- 统一 AI 版本目录解析策略，避免库查找路径错位。
- 保证 `config.yaml` 在引擎启动前可用，不可用时给出明确错误。
- 在 Java 层增加推理前置保护，尽量避免因输入无效触发 native 崩溃。
- 让 instrumentation 用例可稳定复现并验证链路修复。

**Non-Goals:**
- 不修改云端上传协议与服务端逻辑。
- 不在本变更中深改 native 引擎算法，仅做接口与稳定性防护。

## Decisions

### D1: 版本目录规范化

**Decision:**
- 新增统一方法将 AI 版本规范化（优先读取设备上报版本，空值回退到默认版本）。
- 当精确目录不存在时，允许在 `ai-library/` 下做有限 fallback（例如 `1.0` <-> `1.0.0`）并记录告警日志。

**Rationale:**
- 历史数据与打包产物可能存在版本字符串格式差异，规范化+fallback 可兼容存量设备。

### D2: config.yaml 部署改为“显式校验 + 明确失败”

**Decision:**
- `AssetDeployer` 在返回路径前必须验证 `config.yaml` 是否存在且可读。
- 若 assets 中缺失该文件，返回带上下文的错误（包含预期 assets 路径、目标落地路径），并阻止进入 `nativeCreate`。

**Rationale:**
- 配置缺失时继续调用 native 会造成后续故障难定位。

### D3: Java 侧推理防护与崩溃隔离

**Decision:**
- `LensGuardManager.start` 与 `inferJpgAndSaveResult` 增加完整前置检查：
  - 库是否已加载
  - config 是否可读
  - 输入图片是否存在、后缀合法、大小 > 0
  - 输出目录可创建
- 对 `UnsatisfiedLinkError`、`RuntimeException` 做分类处理并产生日志事件。

**Rationale:**
- SIGSEGV 发生在 native，Java 无法直接捕获，但可通过收紧输入与前置检查显著降低触发概率。

### D4: 以 instrumentation 用例做端到端验收

**Decision:**
- 保留并完善 `LensGuardInferenceUploadInstrumentedTest`：
  - 启动前执行 bootstrap
  - 明确断言库目录、config、推理结果图存在
  - 上传后断言成功

**Rationale:**
- 单元级验证不足以覆盖真实设备文件系统和 native 加载行为，instrumentation 更贴近生产路径。

## Validation Plan

1. 在设备上运行 `LensGuardInferenceUploadInstrumentedTest`，确认完整通过。
2. 人工复核日志中不再出现：
   - `UnsatisfiedLinkError: .../ai-library/1.0/...`
   - `FileNotFoundException: config.yaml`
3. 验证结果图成功落盘并上传返回成功。
4. 若仍出现 native 崩溃，补充最小复现输入并输出给 C++ 团队定位。

## Risks / Trade-offs

- fallback 规则过宽可能掩盖真正版本管理问题，因此仅允许受控的少量候选并打强日志。
- 额外校验会让启动路径更严格，短期可能暴露更多历史脏数据，但这是可控的“提前失败”。
