# 统计聚合与持久化迁移方案

**状态：已落地（P1–P4；旧端数据需通过受控导出文件导入）**  
**目标：为 `lws-ui` → `lws-hmi` 的首页/自定义首页统计迁移提供统一的数据模型、聚合规则与落地指导。**

## 1. 背景

当前 `lws-ui` 的首页统计依赖单行 Room 表 `static_data`。这张表已经满足了“单行持久化 + 首页展示”的基本要求，但它仍然带有早期实现痕迹：

- 字段语义偏混合：既有累计总量，也有周对比锚点，也有“常用材料”这类派生业务值。
- 字段展开程度不够：例如“出光总时长”不直接存，而是由焊接/切割/清洗三项运行时相加得到。
- 聚合口径分散：有的值在停光时累加，有的值靠定时任务累加，有的值在页面层现算。
- 面向迁移时不够自描述：新 HMI 若直接复用现状字段，很难形成稳定的跨端契约。

本方案的目标不是引入事件流水表，而是在**仍坚持“单行持久化”**的前提下，把统计口径、字段命名、聚合函数和迁移顺序彻底整理清楚，作为 `lws-hmi` 后续实现的指导基线。

## 2. 设计目标

围绕需求关键词，本方案采用以下设计原则：

1. **满足统计要求和数据收集**
   - 覆盖首页、自定义首页、远程快照、后续报表可能需要的核心累计指标。
   - 明确每个统计值的采集时机、来源和单位。

2. **每一个字段尽量展开**
   - 不依赖“隐式相加”或模糊命名。
   - 能直接持久化的累计值尽量直接持久化。
   - 派生值保留明确来源字段，不与原始累计字段混写。

3. **单行持久化**
   - 整体仍是一张单行聚合表，主键固定为 `id=1`。
   - 所有累计更新使用原子 `UPDATE ... SET field = field + ?`。

4. **聚合函数统计**
   - 统计更新统一抽象为有限的聚合动作：`SUM`、`COUNT`、`MAX`、`SET_LATEST`、`ROLL_WINDOW_ANCHOR`。
   - 页面不再偷偷做业务累计，只负责展示或计算纯派生值。

5. **为迁移做准备和指导**
   - 新方案应允许 `lws-hmi` 用 SQLite 单行表直接落地。
   - 需给出从 `lws-ui static_data` 到新结构的映射方式。

### 2.1 评审后的落地原则

本方案采用“**事实累计字段 + 窗口锚点 + 最近一次快照 + 页面派生值**”四层结构：

- 事实累计字段是唯一写入统计结果的来源，所有相关字段在同一事务中更新。
- 页面派生值（占比、周增幅、格式化单位）不持久化，避免多个冗余字段发生漂移。
- 单行约束只适用于统计聚合表；工作会话的临时状态可以作为同一行的状态字段保存，不引入事件流水表。
- 每次工作结算必须带稳定且可比较的 `session_id`（设备会话序号优先，其次使用持久化 UUID）。同一个 `session_id` 只能结算一次；无法提供稳定 ID 的来源不得直接累加。
- 统计字段都必须有单位、默认值、非负约束和溢出处理规则。

## 3. 对现状的结论

`lws-ui` 当前 `static_data` 实质上是：

- 一张**单行聚合统计表**
- 不是事件日志
- 也不是完整快照历史表

当前字段大致分为三类：

| 类别 | 现有字段 | 问题 |
|---|---|---|
| 累计总量 | `weldingTimeLength` / `cuttingTimeLength` / `washTimeLength` / `jobTimeLength` / `consumableTimeLength` | 可继续保留，但命名和单位可更清晰 |
| 周锚点 | `topStartTime` / `topDay` / `currStartTime` / `currDay` | 语义不直观，建议显式改成“周累计快照锚点” |
| 派生/业务 | `commonUse` | 与累计统计不是同一层概念，应保持字段独立，并注明其非物理累计属性 |

另外，`出光总时长`、`周环比`、`焊接/切割/清洗占比` 都是**展示时计算的派生值**，并未作为展开字段持久化。

## 4. 推荐的新统计模型

### 4.1 总体原则

新表仍建议单表单行，命名可以采用：

- SQLite / Room: `stats_aggregate`
- 主键：`id INTEGER PRIMARY KEY CHECK (id = 1)`

推荐把字段按语义分区：

1. **累计总量字段**
2. **窗口锚点字段（周/月/班次扩展位）**
3. **最近一次会话字段**
4. **展示/偏好辅助字段**
5. **审计字段**

### 4.2 推荐字段设计

下面给出面向迁移的推荐版单行聚合表字段。字段刻意“展开”，避免把多个概念挤在一起。

#### A. 元信息 / 审计

| 字段 | 类型 | 含义 |
|---|---|---|
| `id` | INTEGER | 固定 `1` |
| `schema_version` | INTEGER | 统计表结构版本 |
| `created_at_ms` | INTEGER | 首次创建时间 |
| `updated_at_ms` | INTEGER | 最近一次任何统计更新的时间 |
| `last_reset_at_ms` | INTEGER | 最近一次人工清零/出厂重置时间 |
| `last_settled_session_id` | TEXT | 最近一次已结算工作会话 ID，用于幂等去重 |

#### B. 总累计时长

单位统一用 `秒`，字段名带上 `_seconds_total`：

| 字段 | 类型 | 含义 |
|---|---|---|
| `weld_seconds_total` | INTEGER | 焊接累计时长 |
| `cut_seconds_total` | INTEGER | 切割累计时长 |
| `clean_seconds_total` | INTEGER | 清洗累计时长 |
| `laser_on_seconds_total` | INTEGER | 出光累计总时长（建议直接展开存储） |
| `job_runtime_seconds_total` | INTEGER | 应用运行工作时长累计 |

说明：

- `laser_on_seconds_total` 不再依赖 `weld + cut + clean` 在展示层现算，建议在更新时同步累加，作为一等字段。
- `laser_on_seconds_total` 与三类模式时长必须在同一工作结算事务中写入，并记录不变量：`laser_on_seconds_total >= weld + cut + clean`；若工艺定义保证三者互斥，则进一步要求相等。
- 若旧端只能提供三类模式时长，迁移阶段可以按旧口径回填，但新端不得分别在多个入口重复累加。

#### C. 工艺分类累计计数

这些是对“工作会话”的 `COUNT` 聚合：

| 字段 | 类型 | 含义 |
|---|---|---|
| `weld_session_count_total` | INTEGER | 焊接会话次数 |
| `cut_session_count_total` | INTEGER | 切割会话次数 |
| `clean_session_count_total` | INTEGER | 清洗会话次数 |
| `laser_enable_count_total` | INTEGER | 成功开启 Laser Enable 次数 |

说明：当前 `lws-ui` 未完整沉淀这些次数。只有在来源能提供稳定会话/事件 ID 时才启用 `COUNT`；否则先不采集，避免重试造成虚增。

#### D. 耗材累计

建议单位不要混在名称说明里，直接写在字段名：

| 字段 | 类型 | 含义 |
|---|---|---|
| `wire_feed_length_mm_total` | INTEGER | 累计送丝长度（毫米） |
| `wire_feed_length_display_total` | 可不存 | 展示层再做英制/公制格式化 |

说明：

- 现有 `consumableTimeLength` 本质是“时间 × 送丝速度”得到的长度，但命名像时间，建议迁移时改正。
- 若历史值沿用旧字段，应在迁移脚本中把它映射到 `wire_feed_length_mm_total`。

#### E. 最近一次会话统计

这些字段是“最后一次工作”的快照，但仍放在同一行里：

| 字段 | 类型 | 含义 |
|---|---|---|
| `last_session_mode_type` | INTEGER | 最近一次工作模式 |
| `last_session_duration_seconds` | INTEGER | 最近一次工作持续时间 |
| `last_session_wire_feed_speed_mm_s` | REAL | 最近一次焊接会话使用的送丝速度 |
| `last_session_material_type` | INTEGER | 最近一次工作材料 |
| `last_session_ended_at_ms` | INTEGER | 最近一次工作结束时间 |

说明：

- 这类字段不做累计，只做 `SET latest`。
- 适合作为远程快照和首页“上次工作”类展示的数据来源。

#### F. 周窗口锚点

保留“单行 + 聚合函数”的前提下，推荐把窗口锚点语义显式化：

| 字段 | 类型 | 含义 |
|---|---|---|
| `week_anchor_started_at_ms` | INTEGER | 本周窗口开始时间（周一 00:00） |
| `week_anchor_laser_on_seconds_total` | INTEGER | 本周开始时的累计出光总时长快照 |
| `prev_week_anchor_started_at_ms` | INTEGER | 上周窗口开始时间 |
| `prev_week_anchor_laser_on_seconds_total` | INTEGER | 上周开始时的累计出光总时长快照 |

用这四个字段即可稳定算出：

- 本周出光时长
- 上周出光时长
- 较上周增长率

相比旧的 `topStartTime/currStartTime/topDay/currDay`，新命名更清晰，也更容易迁移到 `lws-hmi`。

#### G. 常用材料 / 展示辅助

| 字段 | 类型 | 含义 |
|---|---|---|
| `favorite_material_type` | INTEGER | 当前统计出的高频材料代码 |
| `favorite_material_updated_at_ms` | INTEGER | 最近一次刷新高频材料的时间 |

为了让“高频”结果可追溯，单行中还应展开保存每种材料已结算会话次数：

| 字段 | 类型 | 含义 |
|---|---|---|
| `stainless_steel_session_count_total` | INTEGER | 不锈钢已结算会话次数 |
| `carbon_steel_session_count_total` | INTEGER | 碳钢已结算会话次数 |
| `galvanized_sheet_session_count_total` | INTEGER | 镀锌板已结算会话次数 |
| `aluminum_alloy_session_count_total` | INTEGER | 铝合金已结算会话次数 |
| `brass_session_count_total` | INTEGER | 黄铜已结算会话次数 |
| `custom_material_session_count_total` | INTEGER | 自定义材料已结算会话次数 |

每次有材料信息的工作结算，先对对应材料字段执行 `COUNT`，再在同一事务内更新
`favorite_material_type`。次数并列时，以本次刚结算的材料为准，保证结果可预测；页面只读
`favorite_material_type`，不自行推断高频材料。

说明：

- 这类字段是“聚合派生结果”，不是物理计时累计。
- 可以继续单独存，避免页面层反复全量计算。

## 5. 聚合函数定义

建议在实现层把统计更新统一抽象为有限几类动作：

### 5.1 `SUM`

用于累计总量：

- `weld_seconds_total += session_seconds`
- `cut_seconds_total += session_seconds`
- `clean_seconds_total += session_seconds`
- `laser_on_seconds_total += session_seconds`
- `wire_feed_length_mm_total += auto_wire_feed_seconds * auto_wire_feed_speed_mm_s`
- `job_runtime_seconds_total += elapsed_seconds`（由运行计时器按实际经过时间结算，不能固定假设每次都是 60 秒）

### 5.2 `COUNT`

用于次数：

- `weld_session_count_total += 1`
- `laser_enable_count_total += 1`

### 5.3 `SET_LATEST`

用于最近一次会话快照：

- `last_session_mode_type = ...`
- `last_session_duration_seconds = ...`
- `last_session_ended_at_ms = now`

### 5.4 `ROLL_WINDOW_ANCHOR`

用于周窗口切换：

1. 发现“当前周标识”变化
2. 把当前锚点提升为上周锚点
3. 用当前累计总量覆盖本周锚点

周窗口计算必须固定为同一时区下的周一 00:00：

- 本周出光：`laser_on_seconds_total - week_anchor_laser_on_seconds_total`
- 上周出光：`week_anchor_laser_on_seconds_total - prev_week_anchor_laser_on_seconds_total`
- 较上周增长率：上周为 0 时返回 `null`/“暂无对比”，否则按 `(本周 - 上周) / 上周` 计算

跨周切换、应用重启和时区变化都必须先执行 `ROLL_WINDOW_ANCHOR`，再执行本次统计更新；切换和累加应处于同一 SQLite 事务。

这样周对比仍然是单行内可算，不需要历史表。

## 6. 推荐采集时机

### 6.1 工作结束时

当一次焊接/切割/清洗工作结束时，记录：

- 对应模式累计时长 `SUM`
- `laser_on_seconds_total SUM`
- 仅对会话工艺自动送丝：`wire_feed_length_mm_total += auto_wire_feed_seconds × auto_wire_feed_speed_mm_s`
- 对应会话计数 `COUNT`
- 最近一次会话字段 `SET_LATEST`

明确排除：手动送丝点动、调试点动、非会话状态下的送丝控制，不进入
`wire_feed_length_mm_total`。自动送丝时长和速度必须来自本次工作会话的工艺参数/实际会话计时，不能读取手动点动控制量代替。

### 6.2 Laser Enable 成功时

记录：

- `laser_enable_count_total += 1`

### 6.3 应用运行定时器

按实际经过时间定期结算（建议 30–60 秒一次，退出前再补结算）：

- `job_runtime_seconds_total += elapsed_seconds`
- 发生系统休眠、时间回拨或进程重启时，丢弃无法确认的区间，不使用负数或固定一分钟补偿

### 6.4 常用材料更新时

在工作会话结算事务中根据各材料会话次数更新：

- `favorite_material_type`
- `favorite_material_updated_at_ms`

## 7. 推荐展示口径

以下展示值推荐全部由聚合字段计算，不再引入新的持久化冗余：

| 展示项 | 推荐来源 |
|---|---|
| 出光总时长 | `laser_on_seconds_total` |
| 焊接总时长 | `weld_seconds_total` |
| 切割总时长 | `cut_seconds_total` |
| 清洗总时长 | `clean_seconds_total` |
| 焊接耗材总计 | `wire_feed_length_mm_total` 格式化 |
| 工作时长 | `job_runtime_seconds_total` |
| 焊接占比 | `weld_seconds_total / laser_on_seconds_total` |
| 切割占比 | `cut_seconds_total / laser_on_seconds_total` |
| 清洗占比 | `clean_seconds_total / laser_on_seconds_total` |
| 较上周增加出光时长 | `(本周累计 - 上周累计) / 上周累计`，基于周锚点计算 |

## 8. 迁移映射（`lws-ui` → 新结构）

### 8.1 直接映射

| `lws-ui static_data` | 新字段 |
|---|---|
| `weldingTimeLength` | `weld_seconds_total` |
| `cuttingTimeLength` | `cut_seconds_total` |
| `washTimeLength` | `clean_seconds_total` |
| `jobTimeLength` | `job_runtime_seconds_total` |
| `commonUse` | `favorite_material_type`（若仍沿用该口径） |

### 8.2 语义修正映射

| `lws-ui static_data` | 新字段 | 说明 |
|---|---|---|
| `consumableTimeLength` | `wire_feed_length_mm_total` | 仅在确认旧值单位和“时间 × 送丝速度”换算公式后迁移；否则进入待核对数据 |
| `currStartTime` | `week_anchor_laser_on_seconds_total` | 仅在确认旧字段实际存的是周窗口起点累计值后迁移，不能按字段名直接假设 |
| `topStartTime` | `prev_week_anchor_laser_on_seconds_total` | 同上 |
| `currDay` | `week_anchor_started_at_ms` | 迁移时建议转成 epoch 毫秒 |
| `topDay` | `prev_week_anchor_started_at_ms` | 同上 |

### 8.3 可新增但无历史来源

这些字段建议迁移后从 0 开始：

- `weld_session_count_total`
- `cut_session_count_total`
- `clean_session_count_total`
- `laser_enable_count_total`
- `last_session_*`
- `favorite_material_updated_at_ms`

### 8.4 迁移校验与失败策略

迁移必须幂等执行，并在单事务中完成“建表、回填、校验、标记版本”：

1. 读取旧行并记录源数据摘要（字段值、单位版本、迁移时间）。
2. 按已确认的映射回填新行；无法确认单位或语义的字段不得静默转换。当前实现仅读取旧表中已确认的四项秒数和材料代码；`consumableTimeLength`、周锚点均不从裸 `static_data` 自动回填。
3. 校验所有累计值非负，且 `laser_on_seconds_total` 满足既定不变量。
4. 对可比字段做迁移前后对账；失败则整体回滚，不写入 `schema_version`。
5. 使用 `schema_version` 保证重复启动不会重复累加。

## 9. `lws-hmi` 落地建议

### 9.1 存储建议

沿用 `lws-hmi` 当前独立 SQLite 路径约定，在 HMI 侧引入独立聚合统计表，例如：

```text
/var/lib/hmi/hmi-stats.db
  └── stats_aggregate
```

也可以放入已有业务库，但推荐独立文件，原因：

- 生命周期更清晰
- 出厂重置 / 数据导出更易控制
- 与工艺库、告警库职责分离

### 9.2 应用层接口建议

建议在 `lws-hmi` 新增统一仓库接口，例如：

```text
StatsAggregateRepository
  - StatsAggregate load()
  - void recordWorkStop(WorkStopEvent event)
  - void recordLaserEnable()
  - void addJobRuntimeSeconds(int seconds)
  - void refreshWeekAnchors(DateTime now)
```

强调：

- 页面层不得直接写 SQL
- Quick / Engineer / Home / Remote Snapshot 都走同一仓库
- 所有统计更新都应在 application/domain 层定义口径
- `recordWorkStop` 必须接收 `sessionId`，在仓库事务内拒绝已结算或过期会话；页面和远程接口不得直接调用累加 SQL。
- 仓库提供一次性 `migrateFromLegacyStaticData`，迁移完成后只读旧表，不再双写。导入仅在新表没有任何 HMI 统计时允许执行，已存在新数据会拒绝覆盖。
- Android 私有数据不能由 Linux HMI 直接读取。服务/迁移工具必须先导出一致的 SQLite 副本（包括 WAL checkpoint），放到 `/var/lib/hmi/legacy/lws-ui-static-data.db`；HMI 首启前读取该文件，文件不存在即当作新安装跳过。

## 10. 为什么该方案适合迁移

1. **与现有 `lws-ui` 统计思路兼容**
   - 仍是单行
   - 仍是累计更新
   - 不要求引入复杂事件表

2. **比现状更清晰**
   - 字段尽量展开
   - 单位写进字段语义
   - 周锚点不再晦涩

3. **便于跨端对齐**
   - Android 与 Linux HMI 可以共享同一统计口径说明
   - 远程快照和首页展示都能用同一模型解释

4. **可渐进迁移**
   - 第一阶段先按映射兼容旧数据
   - 第二阶段补会话次数、最近一次会话、直接展开的 `laser_on_seconds_total`

## 11. 实施步骤建议

### P1. 数据模型定稿（已完成）

- 定义 `StatsAggregate` 领域对象
- 定义 SQLite 表与迁移 SQL
- 定义字段单位与默认值

### P2. 聚合入口收口（已完成）

- Quick Mode 工作结束 → `recordWorkStop`
- Engineer Mode 工作结束 → `recordWorkStop`
- Laser Enable 成功 → `recordLaserEnable`
- 定时任务 → `addJobRuntimeSeconds`

### P3. 首页/自定义首页接线（已完成）

- 用 `StatsAggregate` 替换旧 `StaticData`
- 自定义首页仍只保存“卡片类型布局”，不保存统计值本身

### P4. 迁移兼容（已完成）

- 若导入旧 Android 统计：按 §8 做一次性映射；旧库通过受控导出文件提供给 HMI
- 导入记录源摘要和时间，重复启动不重复累加；新 HMI 数据已产生时拒绝覆盖
- 没有历史数据则建默认单行

## 12. 最终建议

**推荐结论：继续采用“单行持久化 + 聚合函数统计”的路线，但把当前 `static_data` 升级成一张字段展开、语义明确、对迁移友好的聚合统计表。**

这样既能满足首页/自定义首页统计、远程快照和未来报表的需求，又不会把 `lws-hmi` 引向不必要的事件流水系统；同时保留了从 `lws-ui` 迁移时最重要的兼容性。
