## Why

零点 native 单帧检测在激光 ON 期间会产生多个 `ok=true` 样本，但坐标可能抖动、跳簇或混入离群点。当前 Java 端（`ZeroPointDetectCoordinator`、`ZeroPointManualAutoCoordinator`）对有效样本直接算术平均，无法像工艺视频 `LensStainBoxTemporalReducer` 那样在多帧/多次结果中去重与选主簇，导致误检或不稳定偏移写入风险。现场复测亦表明需先在 App 侧过滤多结果再聚合。

## What Changes

- 新增 **零点检测 Java 聚类归约器**（纯 Java、无 Android 依赖，可单测）：将一轮检测内多个 native `ok` 样本按空间邻近合并为簇，选出现次数最多的簇，再取距簇中心最近的样本为代表点。
- 新增 **轮次锚点过滤**（优先级低于聚类）：以该轮**第一次**有效零点坐标为锚点，与锚点距离超过 10px 的后续样本视为无效目标；一轮定义为 **激光 ON → OFF**（与 `ZeroPointDetectCoordinator` 任务边界及 Manual Auto 在线阶段一致）。
- **优先级**：聚类选簇（规则 1）高于锚点距离过滤（规则 2）；当两者冲突时以规则 1 的簇选择结果为准。
- **替换聚合方式**：`ZeroPointDetectCoordinator` 任务结束与 `ZeroPointManualAutoCoordinator` 各 stage 聚合 SHALL 使用归约器输出（代表 `offset_x`/`offset_y` 及有效样本计数），不再对原始列表简单求均值。
- **日志**：归约器 SHALL 输出簇数量、胜出簇大小、锚点过滤剔除数、代表点坐标，便于 logcat 验收。

## Capabilities

### New Capabilities

- `zero-point-detect-cluster-filter`: 零点多样本 Java 聚类、轮次锚点过滤、优先级与代表点选取契约。

### Modified Capabilities

- `zero-point-detect-on-laser-on`: 任务结束聚合 SHALL 经聚类归约器处理后再计算 `meanOffsetX` / `uiDelta`；有效样本计数 SHALL 反映归约后代表点（通常为 1）或归约失败为 0。

## Impact

- **Java**：新增 `ZeroPointDetectClusterReducer`（或同等命名）；修改 `ZeroPointDetectCoordinator`、`ZeroPointManualAutoCoordinator`（`StageAggregate` 构建路径）。
- **测试**：归约器单元测试（3px 簇合并、多簇取最大、簇内最近中心、10px 锚点过滤、规则 1 优先于规则 2、空输入）。
- **无 native / JNI 变更**；Modbus 写入路径与 `ZeroPointCorrectionMapper` 映射不变（仍对归约后的偏移量应用 3px 容差与 `uiDelta` 公式）。
