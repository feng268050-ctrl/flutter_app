## Context

快速模式（`QuickModeActivity` + `GeneralOperationsFragment`）通过材质、档位、厚度/摆宽滚轮从 `dataType=0` 行中匹配工艺参数并下发 Modbus。工程师模式（`EngineerModeActivity`）通过 `ProcessParametersDataViewModel` 管理 `dataType=1`（内置）与 `dataType=2`（自定义）两类参数；「重置为默认」依赖 `originId` 回退到内置行。

工艺库 bootstrap（`ProcessLibraryImporter.ensureEngineerModeDefaults`）在 xlsx 仅含快速模式行时，会将每条快速模式行克隆为 `ENGINEER_MODE_DEFAULT_DATA`，名称沿用快速模式行名称。

本次变更统一工程师模式为单一常用参数类型，并在快速模式提供「更多参数」入口，使操作员可带着当前所选参数进入工程师模式微调。

## Goals / Non-Goals

**Goals:**

- 快速模式非 CNC 工艺页面右上角展示「更多参数」按钮（含图标），点击跳转工程师模式并加载当前快速模式匹配到的 `ProcessParametersData`。
- `ProcessDataType` 值 `1` 重命名为 `ENGINEER_MODE_DATA`（工程师模式常用参数）；值 `2` 标记 `@Deprecated`，新代码不再写入。
- 「重置为默认」恢复为进入当前编辑会话时的初始参数快照（常用参数选中或快速模式携带），而非 DB 内置行。
- Bootstrap 导入：每个 `processType` 从快速模式行中选取**中位档 + 中位厚度（或中位摆宽）**一条生成 `ENGINEER_MODE_DATA`，名称使用所选行的**材料英文名称**（与工艺库 Excel「材料」列一致，如 `Stainless Steel`）。

**Non-Goals:**

- 不改变 CNC 切割快速模式页面本身的行为与布局（仅隐藏「更多参数」）。
- 不重做工艺库 xlsx 列结构或 OTA 整体流程。
- 不改变 Modbus 寄存器映射。
- 不在本变更中实现远程端（云）工艺库 UI 改版；仅同步设备侧 API 语义。

## Decisions

### 1. 「更多参数」按钮位置与可见性

**决定**：在 `activity_quick_mode.xml` 状态栏区域右上角增加独立按钮（图标 + 文案 `@string/more_parameters_text`），绑定 `modeType != CNC_CUT && !laserStatus && !cncOpening`。

**理由**：用户明确要求右上角；CNC 切割无厚度/材质滚轮与常规工艺参数流程，不提供入口。

**备选**：放在 `GeneralOperationsFragment` 内 — 拒绝，因 CNC 与通用 Fragment 切换时顶层 Activity 统一控制可见性更简单。

### 2. 快速模式 → 工程师模式参数传递

**决定**：通过 `Intent` 传递 `processType` + 当前匹配行 id（或完整字段快照 JSON）；工程师模式 `onCreate` 读取后：

1. 切换到对应 `processType` Tab；
2. 若 id 对应现有 `ENGINEER_MODE_DATA` 行则 `switchProcessParametersData`；否则以快照 **insert** 一条新的 `ENGINEER_MODE_DATA`（`originId=null`），并设为当前编辑行；
3. 在 ViewModel 中保存 **session baseline**（深拷贝）供「重置为默认」使用。

**理由**：复用现有工程师模式编辑与下发链路；快照 baseline 满足新重置语义，不依赖 `originId` 指向内置行。

### 3. ProcessDataType 重构

**决定**：

- 新增常量 `ENGINEER_MODE_DATA = 1`；`ENGINEER_MODE_DEFAULT_DATA` 保留为 `@Deprecated` 别名指向 `1`。
- `ENGINEER_MODE_CUSTOM_DATA = 2` 标记 `@Deprecated`；DAO 查询改为仅 `dataType = 1`（过渡期可读 `IN (1,2)` 并在 Room migration 将 2 更新为 1）。
- `saveCommonlyUsedParameter`：改为对当前行 **update**（已是独立常用参数）或 **insert** 新 `ENGINEER_MODE_DATA` 行，不再 fork 为 type 2。
- Excel 映射：`工程师模式常用参数` / 旧别名均解析为 `1`；`2` 列值导入时归一化为 `1` 并打日志。

**理由**：消除「内置 vs 自定义」产品概念，与「重置为会话初始值」一致。

### 4. 「重置为默认」新语义

**决定**：`ProcessParametersDataViewModel` 在加载编辑行时设置 `sessionBaseline`（不可变拷贝）。`resetDefaultData`：

- 若当前行相对 baseline 有未保存 DB 变更：用 baseline 字段覆盖当前 LiveData 值并 re-bind UI（若已 persist 则 update 行）；
- 若当前行为从 baseline fork 出的新 insert：delete 当前行并 reload baseline 行；
- 不再查询 `originId` 或 `selectEngineerOneData` 作为默认来源。

**理由**：用户明确要求恢复到所选常用参数或快速模式携带的原始数据。

### 5. Bootstrap 中位档 + 中位厚度/摆宽选取

**决定**：在 `ProcessLibraryImporter.ensureEngineerModeDefaults`（或提取的 `EngineerCommonParamsBootstrap` 工具类）中，对每个存在 `QUICK_MODE_DATA` 且尚无 `ENGINEER_MODE_DATA` 的 `processType`：

1. 收集该类型全部快速模式行；
2. 对 `gear` 去重排序，取中位索引对应的 gear 值；
3. 在该 gear 子集中，对 `thickness`（非清洗）或 `swingWidth`（`WELD_CLEAN` / `WIDTH_CLEAN`）去重排序，取中位值；
4. 取第一条完全匹配 `(processType, gear, thickness|swingWidth)` 的行（材质冲突时取列表稳定排序第一条）；
5. clone 为 `ENGINEER_MODE_DATA`，`name = ProcessDataExcelConvert.toEnglishMaterialName(materialType, materialName)`（如 `Stainless Steel`），`id/originId = null`。

**理由**：与快速模式默认滚轮中位体验一致；英文材料名称与 xlsx「材料」列一致。

**备选**：按材质分组各生成一条 — 拒绝，用户要求按工艺类型一条。

### 6. 远程 API（WS / HTTP）同步

**决定**：列表/查询仅返回 `dataType=1`；create/update 写入 `ENGINEER_MODE_DATA`；delete 允许删除任意工程师常用参数行（移除「不可删内置」限制），但若删除的是当前激活 preset 则按现有 set-default 逻辑处理。

**理由**：无内置/自定义区分后，远程管理与本地 UI 规则一致。HTTP 路由（`device-local-http-process-library`）与 WS 保持相同语义。

## Risks / Trade-offs

- **[Risk] 现有 DB 中大量 `dataType=2` 行** → Room migration 一次性 `UPDATE ... SET dataType=1 WHERE dataType=2`；查询过渡期兼容 `IN (1,2)` 直至 migration 完成。
- **[Risk] 「重置为默认」与「设为常用参数」交互重叠** → 文档与 UI 文案保持「重置为默认」按钮，行为改为恢复会话初始值；常用参数保存仍为 persist 当前编辑。
- **[Risk] 快速模式跳转 insert 新行导致列表膨胀** → 跳转时优先匹配已有 `(processType, material, gear, thickness/swingWidth)` 的 `ENGINEER_MODE_DATA` 行，仅无匹配时 insert；可选在 design 实现阶段用名称前缀标记来源（非必须）。
- **[Risk] 远程客户端仍发送 `dataType=2` 或期望 delete 保护** → WS ack 返回明确错误；OpenAPI/WS spec delta 记录 BREAKING 语义。

## Migration Plan

1. 发布含 Room migration（2→1）与应用代码的版本。
2. Bootstrap 重新导入仅在工艺库 semver 升级时触发；已有设备不自动重跑中位选取，除非 process-library 版本 bump。
3. 回滚：保留 migration down 不强制；若回滚 APK，旧版仍可通过 `IN (1,2)` 读取已合并数据。

## Open Questions

- 快速模式跳转工程师模式时，若用户已在工程师模式有同名英文 preset，是否合并还是始终打开匹配维度的行？**暂定**：按 material+gear+thickness/swingWidth 精确匹配已有行，否则 insert。
- 「设为常用参数」是否仍需要命名对话框？**暂定**：保留现有对话框流程，保存为 `ENGINEER_MODE_DATA` 新行或 update 当前行。
