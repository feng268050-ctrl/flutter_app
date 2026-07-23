## Context

LWS Android 应用当前通过既有 OTA 流程处理 App、固件以及（历史上）AI/工艺库等资源。目标是将 **AI 库**、**工艺库** 的版本描述与二进制在 **构建期** 打入 APK `assets`，在 **启动期** 与 app data 中已安装版本做 **semver** 比较并按需导入；**App/固件 OTA** 改为单独端点与 zip 载荷，版本比较统一为 semver，且 **不再** 经 OTA 下发两类库。

已确认约束：**API 基址** 统一为 `https://api-prod.lasercyber.workers.dev`；**staging.json / release.json** 由 **Makefile 或环境变量** 显式选择（默认测试/staging）。

**清单 JSON（已与参考 `staging.json` 对齐）** — `process-library` / `ai-library` 每条描述对象包含：

| 字段 | 用途 |
|------|------|
| `version` | 语义化版本字符串（例：`v1.0.0-beta`）；含或不含前导 `v` 在 **同一 SemVer 规范库** 下解析后应对应同一语义版本；比较 **一律** 走该库，**禁止** 手写序关系。 |
| `filename` | 落盘文件名；与 `url` 指向对象一致（工艺库 xlsx、AI 库 zip）。 |
| `sha512` | 下载文件字节的 SHA-512，**小写十六进制** 字符串（64 字节 → 128 hex 字符）。 |
| `url` | 实际下载地址（可为 CDN/R2 等）。 |
| `published_at` | ISO 8601 时间戳；**可选**，构建与启动导入 **可忽略**。 |

## Goals / Non-Goals

**Goals:**

- 构建时可靠拉取 `ai-library`、`process-library` 的版本 JSON，下载 `url` 指向的文件，校验 `sha512`，落盘到 `assets/<artifact>/` 并按 JSON `filename` 命名。
- 将 `assets/ai-library`、`assets/process-library` 排除出版本控制，同时保证 release 打包仍包含这些文件。
- 启动时从 assets 文件名取出版本子串，用 **标准 SemVer 库** 与 `t_device_info`（`processLibVersion` / `AIVersion`）比较；若需升级则执行导入；工艺库导入 **复用改造前 OTA 中工艺库分支的同一套业务逻辑**（调用现有导入管线，而非重写解析规则）。
- OTA 从 `view/lws-app/:json_file` 拉描述，用 **同一 SemVer 库** 与本地 App `versionName` 比较；有更新则下载 zip，解压出 APK 与下位机 bin，**沿用现有** 固件与 APK 安装流程。
- 从 OTA 流程中 **移除** 对 AI 库、工艺库的处理。

**Non-Goals:**

- 重新定义工艺库 xlsx 列语义（仍受 `process-lib-xlsx-import` 约束）。
- 修改下位机通讯协议或固件刷写底层协议（仅可能调整触发条件与文件来源）。
- 在本变更中规定云端 JSON 的完整 schema（库清单形状已按参考 `staging.json` 固定上述字段；`lws-app` 若多字段则在实现中按需取值，缺失必填字段仍 fail-fast）。
- 自行实现 SemVer 解析或版本序比较（须使用规范库）。

## Decisions

1. **构建触发点**  
   - **选择**：在 `make build` 调用的 Gradle 任务链中增加前置步骤（或独立 shell/Gradle task），由 Makefile 传入 `LIBRARY_CHANNEL=staging|release`（或等价变量）决定 `json_file`。  
   - **理由**：与用户选择的「Makefile/环境变量显式指定」一致；CI 与本地可通过同一入口复现。  
   - **备选**：仅用 Gradle `buildTypes` 映射 — 已排除（用户未选）。

2. **JSON 与下载失败策略**  
   - **选择**：构建时若 fetch JSON、下载文件或 SHA512 不匹配，**失败并中止打包**（fail-fast）。  
   - **理由**：避免静默打入错误或过期的库。  
   - **备选**：允许跳过并使用缓存 — 不利于可复现 release。

3. **SHA512 校验**  
   - **选择**：对下载文件的原始字节计算 SHA-512，与清单中 `sha512` 比较；参考数据为 **小写 hex**（128 字符），实现时对 manifest 与本地计算结果做 **大小写不敏感** 比较亦可。  
   - **理由**：满足防篡改并与已发布清单一致。

4. **SemVer 依赖与比较（强制）**  
   - **选择**：引入 **符合 SemVer 2.0 语义** 的 JVM/Android 依赖（在实现阶段于 Gradle 中选定并固定坐标，例如 `semver4j`、`com.github.zafarkhaja:java-semver` 等成熟库之一）。启动时 assets vs data 的比较、OTA 中 manifest `version` vs 本地 `versionName` 的比较，**全部** 通过「parse → 库提供的 compare / satisfies」完成。  
   - **理由**：`v` 前缀、预发布段等由库按规范处理；含 `v` 与不含对 **语义** 一致，无需应用层手写 strip 或分段比较。  
   - **禁止**：为版本序关系自写比较逻辑。

5. **文件名与版本子串**  
   - **选择**：以清单 `filename` 为准；用命名约定从 assets 文件名中 **截取** semver 子串（例：`工艺库_v1.0.0-beta.xlsx`），再与 `t_device_info` 中已安装版本比较。仅允许自定义 **提取规则**（正则/模板），不允许自定义 **序关系**。  
   - **理由**：比较基线集中在 `DeviceInfo`，避免依赖 data 目录残留文件。  
   - **备选**：扫描 app data 中 xlsx/zip 文件名作为 installed 版本来源 — 未采用。

6. **导入落盘与清理策略**  
   - **选择**：process-library/ai-library 的 `xlsx/zip` 仅作导入中间产物，放在 `cache` 临时路径并在导入后删除；更新时清理旧版本目录，仅保留当前生效数据。  
   - **理由**：降低存储占用并避免历史残留文件影响诊断。  
   - **备选**：长期保留旧版本 xlsx/zip 供比较 — 未采用（比较基线已统一到 `DeviceInfo`）。

7. **DeviceInfo 版本持久化格式**  
   - **选择**：写入 `t_device_info.processLibVersion` / `AIVersion` 时使用核心 SemVer（`MAJOR.MINOR.PATCH`），去除 `-beta/-alpha` 等预发布后缀与 build metadata。  
   - **理由**：预发布后缀用于发布轨道标记，不用于设备端展示；UI 与设备信息展示保持稳定简洁。  
   - **备选**：原样写入带后缀版本 — 未采用。

8. **AI 解压目录版本命名**  
   - **选择**：`ai-library` 解压目录名与 `t_device_info.AIVersion` 一致，统一使用核心 SemVer（`MAJOR.MINOR.PATCH`），不保留 `-beta/-alpha` 后缀。  
   - **理由**：JNI 动态库路径拼接直接依赖目录名，必须与设备信息中的版本字段一致，避免运行时路径不匹配。  
   - **备选**：目录保留后缀、DeviceInfo 去后缀 — 未采用（会造成路径与版本字段不一致）。

9. **启动导入与工艺库**  
   - **选择**：定位当前 OTA 中「工艺库」升级所调用的方法/服务，抽成可复用入口（若尚未抽取），由启动引导在「assets 版本大于 data 版本」时调用 **同一路径**。  
   - **理由**：减少行为差异与回归面。

10. **lws-app zip 布局**  
   - **选择**：实现阶段以 **当前/约定 zip 内路径** 定位 APK 与 bin（若仓库已有约定则照抄；否则在实现任务中增加「与发布方确认 zip 内文件名」一步）。  
   - **理由**：提案未固定 zip 内结构，设计层保留与发布契约对齐的挂钩点。

## Risks / Trade-offs

- **[Risk] 构建依赖外网** → 离线构建失败；可通过文档说明、可选本地覆盖路径（非本提案必须）或 CI 缓存缓解。  
- **[Risk] 文件名 semver 与 JSON version 不一致** → 以文件名作为启动比较源时可能与云端语义漂移；缓解：构建链使用 JSON `filename` 落盘，启动只认文件系统事实。  
- **[Risk] OTA 与库启动导入竞态** → OTA 不再触库后竞态消失；需注意老版本 App 仍走旧 OTA 时的服务端兼容（运维/版本窗口，非本客户端单仓必解）。  
- **[Trade-off] assets 增大 APK** → 换取启动可离线导入与简化 OTA；接受。

## Migration Plan

1. 实现构建下载与校验；本地与 CI 验证 `make build`（staging/release 各一次）。  
2. 合并 `.gitignore` 后，贡献者需执行构建以生成本地 assets（在 README 或开发者文档中 **一行说明** 即可，除非用户另有要求）。  
3. 发布一版包含 bundled 库的 App；服务端可同时保留旧 OTA 库字段一段时间供旧客户端使用（运营决策）。  
4. 新 OTA 上线后，监控升级成功率与 semver 边界版本。

## Open Questions

- `lws-app` zip 包内 APK、bin 的 **确切相对路径与命名**（需在实现前与发布仓库或 API 文档对齐）。  
- AI 库导入的 **精确现有入口**（代码库内类名/流程）在 `tasks.md` 中通过「搜索 OTA / ai-library」类任务落地。  
- `staging.json` / `release.json` 在 Makefile 中的 **具体变量名**（例如 `RELEASE=1` → `release.json`）可在实现时与现有 `make` 目标统一命名。
