## Why

AI 库与工艺库目前与 App OTA 流程耦合，版本来源分散且与 App 包体不同步。将两类库在打包阶段写入 APK assets，并在启动时用 semver 与本地数据对比后导入，可以把库更新与 App/固件 OTA 解耦、减少运行时对旧 OTA 分支的依赖，同时让 OTA 只负责 App APK 与下位机固件。

## What Changes

- **构建集成**：`make build`（及/或 Gradle 打包链路）在构建时从 `https://api-prod.lasercyber.workers.dev/view/:artifact/:json_file` 拉取版本描述（`artifact` 为 `ai-library`、`process-library`）；`json_file` 由 **Makefile/环境变量** 显式选择测试/正式：`staging.json`（默认）或 `release.json`。
- **下载与校验**：根据 JSON 中的 `url` 下载库文件到 `app/src/main/assets/<artifact>/`，按 JSON 中的 `filename` 保存；下载后校验 JSON 中的 `sha512`；将 `assets/ai-library` 与 `assets/process-library` 加入 `.gitignore`；assets 随 APK 打包。
- **启动引导**：App 启动时从 `assets/<artifact>/` 文件名取出版本子串，用 **SemVer 规范库** 与 app data 中对应文件比较（与清单命名一致，例如 `工艺库_v1.0.0-beta.xlsx`、AI 库 zip）；若 data 中无对应文件或版本更低，则执行导入；工艺库导入行为 **对齐改造前 OTA 中工艺库分支的现有逻辑**（解析与落库路径复用）。
- **OTA 改造**：版本描述改为从 `https://api-prod.lasercyber.workers.dev/view/lws-app/:json_file` 获取（`staging.json` / `release.json` 选择规则与构建一致，由 Makefile/环境变量驱动）；将 JSON 的 `version` 与本地 App 版本用 **同一 SemVer 规范库** 比较，有更新则按 `url` 下载 zip；解压得到 App APK 与下位机 bin，**沿用现有** 固件更新与 APK 升级流程（**禁止** 手写版本序）。
- **OTA 范围收窄**：新 OTA **不再** 下载或处理 AI 库、工艺库（该职责迁至启动时 assets → data 流程）。

## Capabilities

### New Capabilities

- `build-bundled-libraries`: 构建时拉取版本描述、下载库文件、SHA512 校验、写入 assets 目录与 gitignore，并与现有 Android 打包衔接。
- `startup-bundled-library-import`: 启动时从 assets 与 app data 比较 semver，触发 AI/工艺库导入；工艺库侧复用既有 OTA 工艺库处理逻辑。
- `lws-app-ota-semver`: 从新 `lws-app` 端点获取描述、semver 判更新、下载 zip、解压 APK/bin，复用现有安装与固件升级路径，且不再包含库类资源。

### Modified Capabilities

- `process-lib-xlsx-import`: 工艺库仍通过同一套 xlsx 解析与列绑定规则导入，但 **交付路径** 从「OTA 升级路径」扩展/迁移为「bundled assets / app data 引导路径」；规范文案需与 OTA 解耦后的实际触发方式一致（不要求通过 OTA 下发工艺库 xlsx）。

## Impact

- **构建**：`Makefile`、Gradle（`app/build.gradle.kts` 或任务脚本）、可能新增的下载/校验脚本或 Gradle task。
- **运行时**：Application 或现有启动链路、工艺库/AI 库现有导入与存储代码（需定位当前 OTA 中工艺库分支）。
- **OTA 模块**：版本检查 URL、版本比较语义、zip 内容与后续步骤；删除或禁用对 AI/工艺库的 OTA 处理。
- **仓库**：`.gitignore`、首次克隆后本地需经构建生成 assets 下库文件（或文档说明）。
- **后端契约**：`ai-library` / `process-library`（及预期中结构一致的 `lws-app`）清单 JSON 至少包含：`version`（如 `v1.0.0-beta`；有无 `v` 由 **SemVer 规范库** 解析，应用内 **禁止** 手写版本序）、`filename`、`sha512`（小写十六进制摘要）、`url`；另可有 **`published_at`**（ISO 8601，供展示或审计），构建与启动导入逻辑 **不要求** 读取该字段。AI 库条目与工艺库字段相同，仅 `filename` / 下载物为 zip。
