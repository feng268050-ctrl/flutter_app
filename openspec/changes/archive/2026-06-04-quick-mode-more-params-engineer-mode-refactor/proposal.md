## Why

快速模式面向日常操作，但操作员有时需要在工程师模式中微调当前工艺参数。现有流程需手动切换模式并重新选择参数，且工程师模式的「内置/自定义」数据类型划分与「重置为默认」语义已不符合产品预期。需要在快速模式提供直达入口，并统一工程师模式常用参数的数据模型与重置行为。

## What Changes

- 在快速模式页面右上角新增带图标的「更多参数」按钮；点击后打开工程师模式，并将当前页面所选的快速模式工艺参数应用到工程师模式。
- 「CNC 切割」工艺类型下不显示该按钮。
- **BREAKING**：`ProcessDataType` 枚举重新定义：`1` 为 `ENGINEER_MODE_DATA`（工程师模式常用参数，替代原 `ENGINEER_MODE_DEFAULT_DATA`）；`2`（`ENGINEER_MODE_CUSTOM_DATA`）废弃，不再写入新数据。
- 工程师模式「重置为默认」行为变更：不再恢复到数据库中的内置/默认工程师参数，而是恢复到当前会话最初加载的常用参数快照（含从快速模式携带过来的参数）。
- Bootstrap / 工艺库导入时，从快速模式参数生成工程师模式常用参数的逻辑改为：按工艺类型选取**中位档 + 中位厚度（或中位摆宽）**的一条记录导入，名称使用所选行的**材料英文名称**（如 `Stainless Steel`、`Carbon Steel`）。

## Capabilities

### New Capabilities

- `quick-mode-more-params-entry`: 快速模式「更多参数」入口 UI、可见性规则（排除 CNC 切割）、导航至工程师模式并携带当前快速模式所选工艺参数。
- `engineer-mode-common-params`: 工程师模式常用参数数据模型（`ENGINEER_MODE_DATA`）、重置为初始快照语义、以及从快速模式跳转时的参数应用流程。

### Modified Capabilities

- `startup-bundled-library-import`: Bootstrap 工艺库导入时，从快速模式行生成工程师模式常用参数须按中位档 + 中位厚度/摆宽选取，并使用工艺类型英文名称。
- `process-lib-xlsx-import`: Excel「数据类型」列映射更新：`1` 对应工程师模式常用参数；`2`（自定义）标记废弃，导入时迁移或忽略。
- `device-ws-process-library-remote`: 远程工艺库 API 的 `dataType` 语义与删除/创建规则随 `ENGINEER_MODE_CUSTOM_DATA` 废弃而调整（仅 `ENGINEER_MODE_DATA` 可远程管理，删除保护规则更新）。

## Impact

- **UI**：`QuickModeActivity` / `GeneralOperationsFragment` 布局与状态栏；工程师模式各 Fragment 的「重置为默认」逻辑。
- **数据模型**：`ProcessDataType`、`ProcessParametersDataDao` 查询、`ProcessLibraryImporter.ensureEngineerModeDefaults`。
- **ViewModel**：`ProcessParametersDataViewModel.resetDefaultData`、`QuickProcessParametersDataViewModel` 与工程师模式参数传递。
- **远程 API**：WebSocket / HTTP 工艺库管理（`DeviceWsProcessParametersPayload`、`ProcessParametersRemoteService`、`ServerPushMessageHandler`）。
- **数据库**：现有 `dataType=2` 行需迁移策略或只读兼容；新写入统一为 `dataType=1`。
- **测试**：工艺库导入、WS payload、重置行为相关单元测试。
