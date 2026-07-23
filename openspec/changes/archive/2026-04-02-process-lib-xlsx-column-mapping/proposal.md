## Why

OTA 升级包中的工艺库 `.xlsx` 目前按**固定列下标**解析（`EasyExcelUtil`），列顺序一旦变化就会把错误数据写入 `t_process_parameters_data`，且难以发现。需要改为按**表头列名**绑定 `ProcessParametersData` 字段，并以可复用的解析抽象支撑后续模板演进。

## What Changes

- 引入**列名 → 实体字段**的映射层；首行作为表头，按列名取值而非索引。
- 解析逻辑**抽象**为可复用的组件（例如：表头解析、行→`ProcessParametersData` 构建、可选列别名/版本化 schema），供 OTA 与其它入口复用。
- 以参考模板 `工艺库_V1.4.xlsx`（首行中文列名）为**规范基线**；保留对缺失列、未知列的明确行为（见 spec）。
- **不**改变 Room 表结构与 `ProcessParametersDataDao` 的写入契约；`UpgradeActivity.resetAllProcessData` 仍批量插入解析结果。

## Capabilities

### New Capabilities

- `process-lib-xlsx-import`: 工艺库 Excel（xlsx）导入行为——表头驱动映射、校验、与 `ProcessParametersData` 的对应关系。

### Modified Capabilities

- （无）`openspec/specs/` 下暂无既有能力文档。

## Impact

- **代码**: `EasyExcelUtil`（或替代类）、`ProcessDataExcelConvert` 调用方式、可能新增 `upgrade`/`excel` 包内映射定义；`UpgradeActivity.proUp` 仅换用新 API。
- **依赖**: 仍使用 Alibaba EasyExcel；无强制新三方库。
- **数据**: 错误映射风险下降；需在实现阶段对参考 xlsx 做集成验证。
