# lws-ui 工艺库迁移方案

**状态：实施中（A–D 含工程师内置预设派生已完成；正式签收、E 的导入包 UI/审计、F 待实施）**  
**目标阶段：P4.4 本地 HTTP 与数据、P4.6 产品功能迁移**  
**范围：将 `lws-ui` 的工艺库迁移至 `app/lws_hmi/`，以 SQLite 作为设备端唯一持久化存储。**

## 1. 背景与结论

`lws-ui` 的工艺库以 Android Room 表 `t_process_parameters_data` 保存快速模式、工程师模式预设和用户自定义工艺；内置 Excel 在 APK 启动/升级时导入，后续还可由云端下发更新。当前 `L1 Pro.xlsx` 本身只包含快速模式行，工程师模式默认参数由导入后的快速模式数据派生。

`lws-hmi` 已具备 Dart `sqlite3` 依赖和 `/var/lib/hmi/` 持久化约定，告警历史已使用该模式。工艺库数据层、快速/工程师页面、Modbus 应用，以及由 quick 行派生 `engineer_preset` 均已落地。当前 `L1 Pro.xlsx` 已转换并推送为内置 asset；剩余重点是工艺参数正式签收与离线导入 UI。

**推荐结论：**

- 继续使用 SQLite，但新建独立数据库 `/var/lib/hmi/process-library.db`，不与 `alarm-logs.db` 混用。
- 不直接复用 Android Room 数据库文件、Java 实体或 Android 的迁移链；迁移其业务语义、数据、Excel 格式和参数规则。
- Excel 继续作为工艺人员的维护源格式；设备端不解析 Excel。构建时将其校验、转换为版本化 JSON，并在 HMI 首启/升级时事务导入 SQLite。
- 本地内置库、快速模式、工程师预设派生/用户工艺、Modbus 应用已实现。云同步、录像关联和 Android 用户数据迁移仍为后续切片。

## 2. 现状盘点

| 项目 | `lws-ui` | `lws-hmi` |
|---|---|---|
| 工艺主表 | Room `t_process_parameters_data` | ✅ `process-library.db` 的 `process_presets` / `process_library_meta` |
| 存储技术 | SQLite（Room） | ✅ SQLite `sqlite3`（独立工艺库 DB；告警库亦已使用） |
| 内置库 | `assets/process-library/L1 Pro.xlsx` | 🟡 已生成并推送 `l1-pro.1.0.4-beta.json`（366 条 quick + 派生 engineer_preset）；待正式工艺签收 |
| 导入行为 | 替换快速模式行；补齐工程师默认项 | ✅ 版本化 JSON 导入、quick 重建、导入时按中位数派生/重建 `engineer_preset`、用户工艺保留 |
| 数据类型 | 快速 `0`、工程师 `1`、旧自定义 `2`、旧视频 `3` | ✅ 收敛为 `quick`、`engineer_preset`、`user` |
| 控制输出 | Java → Modbus 寄存器 | ✅ `ProcessParameterApplier` + HAL 22 个 `process.*` 属性批量写入/读回 |

旧库的核心字段包括材料、厚度、档位、工艺类型以及激光功率、摆动、送丝、延时、功率缓升/缓降等参数。`lws-hmi` 的 HAL 已明确寄存器单位和缩放比例，应成为新实现的唯一设备协议依据。

### 2.1 `L1 Pro.xlsx` 到工程师模式的现有规则

`L1 Pro.xlsx` 有 367 行（1 行表头和 366 行数据），其数据类型均为“快速模式工艺数据”；它不是一张工程师模式预设表。Android 的内置库导入流程如下：

1. `EasyExcelUtil` 读取首个 sheet，按中文表头及别名映射为 `ProcessParametersData`。必填列为“参数名称、工艺类型、数据类型”；“摆动频率/扫描频率”“关气延时/气体关闭延迟”等标题会规范化为同一字段。
2. `ProcessLibraryImporter` 只保留 `dataType=0` 的快速模式行，删除数据库中旧的快速模式行，并按工艺类型、材料、厚度/摆宽、档位排序后写入。
3. `ensureEngineerModeDefaults` 对每个“工艺类型 × 非 Custom 材料”检查是否已有工程师预设；缺失时从该组快速模式行生成一条工程师模式常用参数。
4. 选行规则不是平均值：先取不同档位排序后的**下中位数**（索引 `(n - 1) / 2`）；再在该档位中取维度的下中位数。焊道清洗、宽幅清洗按摆动宽度选取，其余工艺按厚度选取；空维度按 `0` 比较。
5. 选中快速模式行的全部参数列直接复制，随后清空 `id`/`originId`、设置为工程师模式类型，并按材料和厚度/摆宽生成名称，例如 `Stainless Steel-2mm`；英制设置下后缀为 `in`。

该逻辑不会从 Excel 直接导入工程师行：即使 Excel 含非快速模式行，内置导入也会忽略。并且旧实现只“补缺”，不刷新已经存在的工程师预设，因此新 Excel 的快速模式参数可能已更新而旧工程师预设仍保留。

云端下发是另一条旧路径：它删除默认快速/工程师数据后，将每条下发参数各复制一次为快速模式和工程师模式，不使用中位数派生规则。此差异不应在新 HMI 中继续保留为两个不一致的业务语义。

## 3. 范围与非目标

### 3.1 首期范围

- [x] 内置工艺库的版本化导入、查询与持久化（当前 asset 为 366 条 `quick`）。
- [x] 快速模式：按工艺类型、材料、厚度/摆宽、档位选择预设并应用。
- [x] 工程师模式：页面、用户工艺 CRUD，以及由 quick 派生的内置 `engineer_preset` 浏览。
- [x] 参数校验与一次性 Modbus 应用。
- [x] 本地备份/恢复的底层接口（UI 可后置）。
- [x] 参考 `lws-ui`：由 quick 行按“工艺类型 × 材料”的中位数规则派生 `engineer_preset`，并加入 golden test。
- [~] 生产工艺库 asset：`l1-pro.1.0.4-beta.json` 已生成并推设备，待工艺负责人正式签收。
- [ ] USB/OTA 外部导入包 UI 与导入审计报告。
- [ ] ynh960 真机 Modbus smoke（选参 → 应用 → 读回）。

### 3.2 不在首期范围

- 云端 WebSocket 下发与双向同步。
- 工艺视频的上传、关联和播放；录像只应保存不可变的参数快照。
- 直接读取或原地升级 Android Room 数据库。
- 旧 `dataType=2/3` 的继续写入；新库不再产生这些类型。

## 4. 架构与分层

```text
工艺 Excel（维护源）
        │ 构建时校验、转换、生成清单与哈希
        ▼
versioned process-library JSON asset / OTA 导入包
        │ 版本比较、完整性校验、单事务导入
        ▼
/var/lib/hmi/process-library.db
        │
ProcessLibraryRepository
        ├── QuickModeUseCase
        ├── EngineerPresetUseCase
        ├── ProcessLibraryImportUseCase
        └── ProcessParameterApplier
                       │
            cyber_hal / Modbus `process.*`
```

建议目录：

```text
app/lws_hmi/lib/features/process_library/
  domain/           # 工艺、枚举、Repository 接口、校验规则
  application/      # 查询、保存、导入、应用 Use Case
  infrastructure/   # SQLite、JSON asset/导入器、HAL 写入适配器
  presentation/     # 快速模式与工程师模式页面
app/lws_hmi/assets/process-library/
  manifest.json
  l1-pro.<version>.json
```

UI、导入器和 SQLite Repository 均不得直接操作 Modbus；已实现的 `ProcessParameterApplier` 负责将已校验的领域参数映射为 HAL 属性并写入设备。

## 5. SQLite 设计

### 5.1 数据库与运行策略

- 路径：`/var/lib/hmi/process-library.db`（经现有持久化布局映射到 `/userdata/hmi/`）。
- 每个数据库连接启用 `PRAGMA foreign_keys = ON` 和 `PRAGMA journal_mode = WAL`。
- 所有导入、批量替换、备份恢复使用单一 SQLite transaction。
- SQLite/I/O 失败不得阻塞已经运行的焊机；UI 显示错误并保留上一次已成功加载的库。
- 应用进程退出时关闭数据库；测试可注入内存 `Database`。

### 5.2 表结构

#### `process_library_meta`

每个库来源一行，记录可比较的版本和导入状态。

| 字段 | 含义 |
|---|---|
| `source` PK | `bundled`、`ota`、`cloud` 等 |
| `library_version` | 语义化版本或已规范化版本 |
| `schema_version` | JSON/数据库格式版本 |
| `content_sha256` | 导入内容哈希 |
| `installed_at_ms` | 成功安装时间（UTC epoch ms） |
| `row_count` | 成功导入的行数 |

#### `process_presets`

工艺参数主体；快速、工程师预设与用户工艺统一存储。

| 分组 | 建议字段 |
|---|---|
| 身份 | `id INTEGER PK`、`uuid TEXT UNIQUE`、`name TEXT NOT NULL` |
| 所有权 | `kind TEXT CHECK (quick, engineer_preset, user)`、`source TEXT`、`is_builtin INTEGER` |
| 检索条件 | `process_type`、`material_type`、`material_name`、`thickness`、`gear`；清洗工艺的快速筛选维度为参数列 `swing_width`（厚度可为空） |
| 参数 | 与 `process.*` 映射的一组 nullable 数值列 |
| 版本与审计 | `library_version`、`created_at_ms`、`updated_at_ms`、`revision` |

参数采用具名列而不是一个 JSON blob，以支持按材料、工艺类型、厚度、档位查询，并让数值范围校验与数据库检查更清晰。可选的未知/扩展参数才放入 `extra_json`。

建议索引：

```sql
CREATE INDEX idx_process_presets_quick_lookup
  ON process_presets(kind, process_type, material_type, thickness, gear);
-- 清洗快速行以 swing_width + gear 区分；应用层按参数列筛选，必要时可加覆盖索引。
CREATE INDEX idx_process_presets_engineer_list
  ON process_presets(kind, process_type, name);
CREATE UNIQUE INDEX uq_process_presets_uuid ON process_presets(uuid);
```

### 5.3 数据类型收敛

旧 Android `dataType` 迁移为新 `kind`：

| 旧值 | 新值 | 处理 |
|---|---|---|
| `0` 快速模式 | `quick` | 内置库可替换 |
| `1` 工程师常用 | `engineer_preset` | 内置库可替换 |
| `2` 工程师自定义（废弃） | `user` | 仅在历史迁移时接受 |
| `3` 视频工艺（废弃） | 不迁移为主表行 | 视频保存参数快照 |

## 6. 参数与 HAL 映射

数据模型使用业务单位，例如毫米、毫秒、Hz、百分比；寄存器编码由 HAL 配置负责。不得把 Modbus 地址、缩放系数或字节序复制进 UI/SQLite 代码。

首期映射以 `app/lws_hmi/assets/hal/modbus.json` 为准，包含以下类别：

| 类别 | HAL 属性示例 |
|---|---|
| 激光/穿孔 | `process.laser_power`、`process.laser_duty_cycle`、`process.laser_frequency`、`process.piercing_*` |
| 摆动 | `process.swing_frequency`、`process.swing_width` |
| 送丝/回抽 | `process.wire_feeding_speed`、`process.back_draw_length`、`process.back_draw_speed`、`process.wire_filling_*` |
| 时序 | `process.*_delay`、`process.power_ramp_*_duration`、`process.spot_welding_*`、`process.piercing_duration` |

应用流程：

1. Repository 返回已选预设的领域对象。
2. Use Case 根据工艺类型和产品能力过滤无效/不适用字段。
3. `ProcessParameterValidator` 按产品约束与 HAL 范围校验。
4. `ProcessParameterApplier` 将非空字段编码成一次批量写入。
5. 写入成功后更新当前会话；部分失败必须读回/报告，禁止静默显示“已应用”。

`control.process_type` 的切换与参数写入应由同一应用用例编排，并在设备工作中或存在激光使能风险时拒绝执行。具体互锁复用既有 `LaserWorkGuard`，不由页面自行判断。

## 7. 内置库导入与版本策略

### 7.1 格式选择

工艺人员维护的源文件继续采用现有 Excel 表头和枚举语义，例如“参数名称、材料、材质名称、厚度、激光功率、摆动频率、工艺类型、数据类型、档位”。

设备运行时使用 JSON，而不是解析 `.xlsx`：

1. 构建工具读取 `.xlsx`，检查表头、必填字段、枚举、单位、数值范围和重复组合。
2. 工具生成规范化 JSON、`manifest.json` 和 SHA-256。
3. Flutter 将 JSON 作为 asset 打包；设备启动时读取清单比较 `library_version` 与 hash。
4. 新版本完整校验成功后，在一个 transaction 中替换可替换的内置行，再更新 `process_library_meta`。

这样保留 Excel 维护流程，同时避免 Linux Flutter 端引入 Excel 解析依赖及其运行时失败面。

### 7.2 原子替换与用户数据保护

- `bundled`/`ota` 导入只删除本来源的 `quick` 与 `engineer_preset` 行。
- `user` 行永不被内置库导入删除、覆盖或重命名。
- 同一内置预设若需被用户修改，UI 先“复制为用户工艺”，随后编辑副本。
- 导入前保存数据库在线备份或 SQLite savepoint；校验、插入、索引建立任一步失败即 rollback。
- `process_library_meta` 仅在 transaction 成功提交后更新。

### 7.3 工程师预设的迁移策略

**当前状态：已实施。** `EngineerPresetDeriver` 在导入时按 lws-ui 中位数规则从 quick 行派生 `engineer_preset`；显式 JSON 工程师行优先，其余材料组补齐。同一 transaction 内重建该来源的内置 `engineer_preset`。同版本同 hash 若发现派生缺失会再次导入补齐（兼容先推 quick、后上线派生逻辑的设备）。

算法要点（与 §2.1 / lws-ui `EngineerCommonParamsBootstrap` 对齐，golden test 覆盖）：

- 每个「工艺类型 × 非 Custom 材料」至多一条派生工程师预设。
- 先取档位下中位数，再在该档取厚度（清洗则取摆宽）下中位数。
- 名称形如 `Stainless Steel-2mm`（Title Case 英文材料名）。

存储语义相对旧 Android「只补缺不刷新」的修正：

- 每次成功导入内置库时，在同一 transaction 中重建该来源的 `engineer_preset` 行；它们与快速模式行一起更新。
- 用户创建/复制得到的 `user` 行永远不参与上述删除和重建。
- 内置库包含显式工程师预设时，以显式行优先；无显式行时才按中位数规则派生。
- 后续云端下发、USB/OTA 与内置 asset 均进入同一导入器和同一套派生规则，禁止像旧 Android 实现一样按渠道产生不同的快速/工程师数据。

### 7.4 型号适配

导入包/清单必须包含 `supported_models`。选择逻辑沿用 `lws-ui` “型号专属优先、通用库兜底”的原则；找不到适配库时保持旧库并给出可诊断错误，不能用不明工艺覆盖已有数据。

## 8. UI 与交互边界

### 8.1 快速模式

- 从 Home 的 Quick Mode 入口进入。
- 依次选择工艺类型、材料、厚度/摆宽及档位；展示即将写入的参数摘要。
- 点击应用后进行安全检查、参数校验、Modbus 批量写入和读回确认。
- 当前选择只属于运行会话；库中的内置预设不可直接修改。

### 8.2 工程师模式

- 按工艺类型列出内置预设和用户工艺，明确来源标记。
- 支持加载、复制为用户工艺、新建、编辑、重命名、删除用户工艺。
- 内置预设只读；删除/编辑入口不对内置项显示。
- 任何保存均先写 SQLite；“应用到设备”是单独、显式的动作。

### 8.3 录像快照

当 P4.1/P4.6 的工艺视频功能接入时，录像记录保存当时的 `ProcessParametersSnapshot` JSON 与库版本/预设 UUID。不得只保存外键，否则预设被更新或删除后历史视频会改变含义。

## 9. 分期实施与验收

| 状态 | 阶段 | 交付 | 验收重点 |
|---|---|---|---|
| [x] | A：领域与 SQLite | 模型、schema、Repository、迁移、内存 DB 测试 | CRUD、索引查询、重启后持久化、失败软处理 |
| [x] | B：资产管线 | Excel 校验/转换、JSON manifest、内置导入器 | 表头/枚举错误拒绝；相同版本不重复导入；升级原子替换 |
| [x] | C：快速模式 | 筛选页面、摘要、应用 Use Case | 每类工艺正确筛选；HAL 参数映射；设备空闲互锁 |
| [x] | D：工程师模式 | 页面、用户工艺管理、内置预设中位数派生 | 内置项只读；派生/显式优先；用户工艺 CRUD；升级后用户项保留 |
| [~] | E：离线更新与恢复 | 备份恢复底层接口已完成；导入包 UI/审计待完成 | 损坏包不影响旧库；回滚；备份可恢复 |
| [ ] | F：云与视频（后续） | WebSocket 下发、视频参数快照 | 协议兼容、冲突策略、历史快照不变 |

每一阶段均应至少包含：SQLite transaction 回滚测试、数据模型/映射单测、UI widget test（若有页面）、以及 ynh960 真机 Modbus smoke test。Dart 变更完成前运行 `flutter analyze` 与相关测试。

## 10. Android 存量数据迁移

Android Room 文件不能作为 Linux HMI 的直接升级源：路径、权限、数据库版本和运行环境不同。若产品要求保留现场用户自定义工艺，应另设一次性迁移流程：

1. 在旧 Android 环境导出受控 JSON（仅用户工艺，附版本和 hash）。
2. 新系统通过 U 盘、OTA staging 或受控网络通道导入该 JSON。
3. HMI 校验字段、归并旧 `dataType=2` 为 `user`、生成 UUID，并写入 transaction。
4. 输出导入报告；任何非法记录单独报告，不得影响其余有效行或内置库。

若产品不要求保留现场自定义数据，则新系统只导入内置库，简化首发路径。

## 11. 风险与约束

| 风险 | 控制方式 |
|---|---|
| Excel 列名/单位漂移 | 构建时严格校验；列映射与样例作为回归测试 |
| 库升级误删用户数据 | `kind/source` 隔离，替换只针对内置行，transaction 测试 |
| UI 与设备参数不一致 | 唯一 `ProcessParameterApplier`；成功后读回/明确失败状态 |
| 控制中切换工艺 | 复用激光工作互锁；设备繁忙时拒绝应用 |
| SQLite 损坏或掉电 | WAL、原子 transaction、导入前备份、保留上个成功库 |
| 多产品型号差异 | manifest 指定型号；以 HAL profile 约束可用字段 |

## 12. 待确认决策

1. **已决：**首期同时提供 Quick 与 Engineer UI；内置 `engineer_preset` 已由 quick 中位数派生落地。
2. 新系统上线是否必须迁移 Android 设备上已有的用户自定义工艺？
3. 首期工艺库更新渠道是随固件内置、USB 离线导入，还是必须同步支持云端 WebSocket 下发？
4. 哪些型号共享一份库，哪些需型号专属库？型号标识以何处为准？
5. 各 `process.*` 参数的正式范围、空值语义和工艺类型适用矩阵由谁签收？

下一实施优先级：由工艺负责人签收 `L1 Pro` 参数并完成 ynh960 Modbus smoke；随后完成 USB/OTA 外部导入 UI 与审计。

## 13. 实施记录

2026-07-23 已在 `app/lws_hmi/` 落地阶段 A–D（含 `EngineerPresetDeriver` 与 golden test），以及阶段 E 的备份恢复底层接口：领域模型、SQLite Repository、版本化 JSON 导入、quick→engineer_preset 派生、Quick/Engineer 页面、用户工艺 CRUD、HAL 批量应用/读回、备份恢复和自动化测试。USB/OTA 外部导入包 UI 与审计报告仍按后续切片处理。

仓库已包含 `app/lws_hmi/assets/process-library/L1 Pro.xlsx`，并已转换出 `l1-pro.1.0.4-beta.json` 与 manifest（366 行 `quick`）。导入后还会按材料组派生 `engineer_preset`。该 asset 仅缺少工艺负责人正式签收，不能据此宣称已完成生产参数验收。取得更新的签收 Excel 后执行：

```bash
python3 scripts/convert-process-library.py /path/to/工艺库_V1.4.xlsx --version 1.4.0 --models "PRODUCT_MODEL"
```

`--models` 必须填写设备 `/var/lib/hal/product.ini` 中的 `MODEL` 值（多个值用逗号分隔），不是板卡 `board_id`。转换器会严格校验表头、枚举、范围和快速模式重复组合，并生成版本化 JSON、manifest、行数和 SHA-256。生成结果仍须由工艺负责人签收，并在 ynh960 上完成 Modbus smoke test 后才能作为生产内置库发布。
