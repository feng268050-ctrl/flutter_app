## Context

- **现状**：`ZeroPointDetectCoordinator` 在四次定时采样后将所有 `ok` 样本的 `offset_x`/`offset_y` 直接求平均；`ZeroPointManualAutoCoordinator` 的 `StageAggregate.from` 同样算术平均在线/离线列表。
- **参考实现**：`LensStainBoxTemporalReducer` 对工艺视频多帧 box 做 union-find 聚类、按出现次数阈值保留、再取 canonical box（median）。零点场景是 **2D 点** 而非矩形，且一轮内样本数较少（通常 ≤4 在线 + 若干离线），但同样需要抑制离群与重复命中。
- **坐标空间**：native 返回 `offset_x`/`offset_y`（相对 `reference_zero_xy`）。一轮内 reference 固定，聚类与距离比较可在 **offset 空间** 进行（与绝对检测点坐标等价）。常量与 `ZeroPointCorrectionMapper.POSITION_TOLERANCE_PX`（3px）对齐。

## Goals / Non-Goals

**Goals:**

- 提供可单测的 `ZeroPointDetectClusterReducer`，输入一轮内按时间顺序到达的 `ok` 样本列表，输出 0 或 1 个代表样本（`offset_x`, `offset_y`）及元数据（簇数、胜出簇大小、锚点剔除数）。
- 规则 1（3px 簇 + 最多簇 + 最近中心）优先于规则 2（相对首样本 10px）。
- 接入 `ZeroPointDetectCoordinator.finalizeTaskLocked` 与 `ZeroPointManualAutoCoordinator.StageAggregate` 构建路径。

**Non-Goals:**

- 不修改 C++ `zero_point` 检测、ROI、`-5` 光斑尺寸阈值。
- 不改变四次采样时刻表、Manual Auto Modbus 流程、pending JSON 格式字段名（`meanOffsetX` 仍表示归约后用于写校正值的偏移）。
- 不引入跨轮次（多次出光之间）的全局历史聚类。

## Decisions

### 1. 独立 Reducer 类（对齐 `LensStainBoxTemporalReducer`）

**选择**：`com.lasercyber.lws.ai.ZeroPointDetectClusterReducer`，无 Android 依赖。

**常量**（public static final）：

| 常量 | 值 | 含义 |
|------|-----|------|
| `CLUSTER_TOLERANCE_PX` | `3` | 两样本属同一簇：\|Δoffset_x\| ≤ 3 **且** \|Δoffset_y\| ≤ 3（Chebyshev / 轴对齐，与位置容差一致） |
| `ROUND_ANCHOR_MAX_DEVIATION_PX` | `10` | 相对本轮首条 `ok` 样本，超过则规则 2 标记为无效 |
| `DISTANCE_METRIC` | 欧氏 | 规则 2 与「距簇中心最近」使用 `hypot(dx, dy)` |

### 2. 聚类算法（规则 1）

**选择**：对 **全部 native `ok` 样本**（按到达顺序）做 union-find 聚类，与 `LensStainBoxTemporalReducer` 相同模式，但成员为点：

1. 输入：`List<Sample>`，每项含 `offsetX`, `offsetY`, `index`（到达序号）。
2. 若 `i` 与 `j` 满足 `|ox_i - ox_j| ≤ 3` 且 `|oy_i - oy_j| ≤ 3`，则 union。
3. 每簇统计 **成员条数**（非 distinct 帧；零点一轮内同帧多样本也计数）。
4. 保留成员数 **最大** 的簇；并列时取 **平均 offset 字典序最小** 的簇（确定性 tie-break）。
5. 簇中心 = 成员 `offset_x`/`offset_y` 的算术平均。
6. **代表点** = 簇内欧氏距离到中心 **最小** 的成员；并列取 **到达序号最早** 的。

### 3. 轮次锚点过滤（规则 2）与优先级

**选择**：两阶段，**最终代表点以规则 1 为准**：

1. **规则 2 预过滤（次优先级）**：记 `anchor` = 列表中第一条 `ok` 样本坐标。对序号 > 0 的样本，若 `hypot(ox - anchor.x, oy - anchor.y) > 10`，标记为 `anchor_rejected`（不计入聚类输入）。**首条样本永不因规则 2 剔除**。
2. **规则 1 聚类**：对未被 `anchor_rejected` 的样本执行聚类选代表点。
3. **冲突处理**：若规则 2 后仅剩首条样本而规则 1 在 **全量 ok 样本** 上存在更大的簇，则 **忽略规则 2 预过滤结果，对全量 ok 样本执行规则 1**（规则 1 优先级最高）。

等价实现：先对全量样本做规则 1 得候选代表点；若胜出簇的成员数 **严格大于** 锚点过滤后子集上的胜出簇，采用全量结果；否则采用锚点过滤后子集上的规则 1 结果。

### 4. 一轮检测边界

| 调用方 | 一轮范围 |
|--------|----------|
| `ZeroPointDetectCoordinator` | 单次 laser OFF→ON 触发的四采样任务（`activeEventId`） |
| `ZeroPointManualAutoCoordinator` | `online_500ms` stage：从 `laser_on` 到该 stage finalize 的在线样本列表；`offline_200ms` / `offline_100ms` 各为独立一轮（各自视频扫帧列表） |

每轮独立调用 reducer；轮与轮之间不共享锚点。

### 5. 输出与下游

- 归约成功：`validSamples = 1`（或保留 `clusterSize` 于日志），`meanOffsetX/Y` = 代表点 offset。
- 归约失败（0 个 ok 输入，或聚类后无成员）：`validSamples = 0`，不写 Modbus / 不完成 Manual Auto stage。
- `ZeroPointCorrectionMapper.isWithinPositionTolerance` 仍作用于归约后的单点偏移。

## Risks / Trade-offs

- **[Risk] 首样本为离群点且规则 1 全量优先可能保留离群簇** → 通过「成员数最多」约束；若两簇同数，tie-break 选平均 offset 字典序最小，降低随机性。
- **[Risk] 3px 过紧导致一簇拆成多簇** → 与 UI 1 步 = 3px 一致；后续可调 `CLUSTER_TOLERANCE_PX` 常量。
- **[Risk] Manual Auto 离线帧数多、单帧误检仍可能形成第二大簇** → 规则 2 在成员数不占优时仍生效；日志记录 `anchorRejected` 便于现场调参。
- **[Trade-off] 不再算术平均** → 代表点更抗离群，但不再利用多样本噪声平均；符合「选主簇最近中心」产品语义。

## Migration Plan

1. 实现 reducer + 单元测试。
2. 替换 `ZeroPointDetectCoordinator` 与 `ZeroPointManualAutoCoordinator` 聚合调用。
3. 设备验收：logcat 过滤 `ZeroPointCluster`（或 reducer TAG）确认 `clusterWinnerSize`、`representativeOffset`。
4. 无数据迁移；无 native 部署依赖。

## Open Questions

- 离线 stage 是否将「整段视频」视为一轮，还是「激光 ON 时间段内帧」？**当前设计**：每个 offline stage 的全部有效帧为一轮（与现有 `StageAggregate.from` 列表范围一致）。若需仅保留激光 ON 区间帧，可在后续 change 收窄输入列表。
