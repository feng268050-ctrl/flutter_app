## Context

当前流程将 `assets/process-library/` 视为“单个 xlsx 文件来源”，启动时直接挑选一个 `.xlsx` 做版本比较与导入。新资产增加了 `工艺库_vX.Y.Z[-pre].zip` 形态，zip 内包含多个“设备型号.xlsx”。设计需要改为按后缀分支，并保留原单 xlsx 支持，因此需要同时改造：

- 构建阶段：按后缀分支，xlsx 直落盘；zip 解压后保证 APK 内 `assets/process-library/` 包含按型号命名的 xlsx 文件；
- 运行阶段：按资产形态分支，在保持现有版本比较/落库语义不变的前提下，执行“单 xlsx 直导入”或“按当前设备型号选择 xlsx 导入”。

约束：

- 版本来源仍以 process-library 包文件名中的 semver 为准（沿用现有 `LibraryVersionFilename`/`SemanticVersionHelper`）。
- 设备型号匹配前必须移除 `LaserCyber` 前缀，并进行空白规范化。
- 不能破坏 AI library 与现有工艺参数导入逻辑。

## Goals / Non-Goals

**Goals:**
- `make build` 支持 process-library `.xlsx/.zip` 双后缀分支（xlsx 直出、zip 解压）。
- 启动时根据设备型号（去掉 `LaserCyber` 前缀）选择对应 xlsx 导入。
- 保持现有 process-library 版本比较与导入事务语义（删除默认数据 + 批量写入 + 更新 `processLibVersion`）。
- 型号文件缺失时提供可诊断日志并执行可预期回退，避免 silent failure。

**Non-Goals:**
- 不改动工艺参数表结构与 `ProcessParametersData` 字段映射。
- 不引入云端按型号实时下发协议变更（仅覆盖本次打包与启动导入链路）。
- 不修改 AI library 打包/导入行为。

## Decisions

### 1) 按后缀分支：xlsx 直通，zip 解压
- **Decision**: 在 `make build` 流程对 process-library 资产按后缀分支：`.xlsx` 直接放入 `assets/process-library/`；`.zip` 解压后放入同目录，运行时统一只处理 `.xlsx` 输入。
- **Why**: 满足新 zip 能力的同时保留旧 xlsx 兼容；并继续避免启动时做 zip 解压。
- **Alternatives considered**:
  - 运行时在 app 内解压 zip：会增加冷启动成本与失败恢复复杂度，放弃。
  - 构建时保持 zip 原样进 assets：运行时仍需解压，不符合轻启动目标，放弃。

### 2) 版本比较以“资产文件名版本”统一处理
- **Decision**: process-library 版本比较统一从资产文件名版本段提取：若来源为 `.zip`，取 zip 文件名版本；若来源为单 `.xlsx`，取 xlsx 文件名版本。启动阶段不从目录内任意型号文件名推断包级版本。
- **Why**: 保持历史单文件语义，同时给 zip 场景提供明确包级版本来源。
- **Alternatives considered**:
  - 解析每个 xlsx 文件名取版本：与“同一包多型号同版本”模型冲突，易引入不一致，放弃。

### 3) 型号选择仅用于“多 xlsx”场景
- **Decision**:
  - 读取设备型号（现有设备信息来源）；
  - 标准化：去除前缀 `LaserCyber`（大小写不敏感）、trim、压缩多空白为单空格；
  - 当 `assets/process-library/` 存在多个 xlsx 时，按 `<normalizedModel>.xlsx`（大小写不敏感）精确匹配；
  - 若未命中，回退到目录中的第一个 xlsx（稳定排序）并记录 warning。
- **Why**: 在多型号场景满足“按型号区分”，同时保证单文件场景维持原行为。
- **Alternatives considered**:
  - 未命中直接失败终止导入：诊断明确但可用性差，放弃。
  - 模糊包含匹配：存在误匹配风险（如 `L1` vs `L1 Pro`），放弃。

### 4) 导入器保持复用，仅新增“后缀分支 + 选择层”
- **Decision**: `ProcessLibraryImporter.importFromXlsx(...)` 保持不变；在 `BundledLibraryBootstrap` 前置新增后缀分支与文件选择层，最终仍输出单一 xlsx 给导入器。
- **Why**: 最小化风险，避免重复改动 Excel 映射与 DB 落库关键路径。
- **Alternatives considered**:
  - 在导入器内部增加型号逻辑：职责耦合、测试范围扩大，放弃。

## Risks / Trade-offs

- **[Risk] 设备型号字符串格式不稳定** → **Mitigation**: 统一标准化函数；增加单元测试覆盖前缀剥离、大小写、空白差异。
- **[Risk] 型号文件缺失导致导入非目标参数** → **Mitigation**: 明确 warning 日志输出（型号、候选文件、回退文件）；后续可接告警埋点。
- **[Risk] 构建解压产物污染仓库** → **Mitigation**: 保持 `assets/process-library/` 在 `.gitignore`；每次构建前清理目标目录。
- **[Trade-off] 回退到首文件提升可用性但可能精度不足** → **Mitigation**: 将行为写入 spec，并通过日志让问题可观测。

## Migration Plan

1. 更新构建脚本，支持 process-library `.xlsx/.zip` 双分支下载与落盘/解压。
2. 在启动导入链路新增后缀/资产形态分支：单 xlsx 直导入，多 xlsx 按型号选择。
3. 保持并复用现有版本比较与导入落库逻辑；补充相关测试。
4. 灰度验证：用至少两个型号文件（如 `L1.xlsx`、`L1 Pro.xlsx`）验证匹配与回退行为。
5. 回滚策略：若新流程异常，可回退到上一版本 APK（仍使用旧资产组织），不涉及数据迁移脚本。

## Open Questions

- 设备型号的最终来源字段是否统一（例如 `Build.MODEL` vs 设备信息表字段），是否需要优先级策略？
- 回退策略是否需要改为“无匹配即不导入”并提示人工修复？
- zip 内是否允许包含非 xlsx 附件文件；若存在，是否需要构建阶段白名单过滤？
