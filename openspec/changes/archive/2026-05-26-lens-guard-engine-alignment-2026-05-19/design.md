## Context

- **引擎现状**（`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`）：默认 `models.cls.enabled: false`；污点 det 使用中心 640×640 裁剪；新增 `nativeInferImageToJson`；激光 ON 不再触发 `MONITORING(1)`。
- **App 现状**（本仓库）：
  - `NativeBridge` 已声明 `nativeInferImageToJson`；`LensGuardManager.inferJpgToJson` 已实现 RKNN 单线程封装。
  - `AiVisionFragment` 含完整离线抽帧/时间轴/`fromNativeJson` 逻辑，但 `SKIP_OFFLINE_INFERENCE_FOR_UPLOAD = true` 跳过推理 MP4。
  - `AiVisionFragment.onLensGuardStateChanged` 仍把 `state == 1` 映射为「监控中」；`onLensClsSnapshot` 在 `valid:false` 时显示「等待」文案，易被误判为故障。
  - `LensGuardManager` 已有 `nativePreviewClassificationSupported` 与 legacy preview cls 激光覆盖兼容路径。
- **产品约束**：分类模型**暂时**关闭，后续会开启并可能新增其它检测模型；App 方案须 **config-driven + 运行时探测**，禁止删除 cls/MONITORING 相关代码路径。

## Goals / Non-Goals

**Goals:**

- 与 2026-05-19 引擎契约对齐：离线 JSON 推理、det-only 行为、污点/预览 det 不变。
- 提供统一的 **Capability Profile**，供 UI/流程在 cls/det/离线 JNI 可用性变化时自动分支。
- 恢复离线推理 MP4 生成与上传门禁（在 so 具备符号时）。
- MONITORING / cls 相关 UI **降级**而非移除；cls 重新启用时无需大规模返工。

**Non-Goals:**

- 不在 App 内实现或切换 RKNN 模型文件（仍由 ai-library zip + `config.yaml` 决定）。
- 不恢复异常辅助、`clean_ref` 等已从对接文档移除的必接项。
- 不在本变更中实现焊中自动聚焦算法（仅 UI/状态依赖解耦）。
- 不热更新 `config.yaml`（仍须 `nativeDestroy` → `nativeCreate`）。

## Decisions

### 1. Capability Profile 作为唯一「能力真相源」

**决策**：在 `LensGuardManager`（或同包 `LensGuardCapabilities`）在 `nativeCreate` 成功后构建 `LensGuardCapabilityProfile`，字段示例：

| 字段 | 来源 | 用途 |
|------|------|------|
| `classificationEnabled` | 解析 `files/lens_guard/config.yaml` 中 `models.cls.enabled` | cls UI、是否期待 MONITORING |
| `detectionEnabled` | `models.det.enabled` | 污点/预览 det 提示 |
| `offlineInferJsonAvailable` | 启动时一次 `guardedInferImageToJson` 探针或 `UnsatisfiedLinkError` 捕获 | 是否走离线时间轴 |
| `focusMonitoringExpected` | `classificationEnabled && sessionRunning` | 是否订阅/展示 MONITORING |

**理由**：避免 scattered `if (det-only)`；未来新增模型时在 profile 增字段即可。

**备选**：仅靠引擎 `onStateChanged` 反推能力 —— 拒绝，det-only 下永远收不到 MONITORING，无法区分「关闭」与「故障」。

### 2. config.yaml 解析：轻量 YAML 子集 vs 复用现有部署路径

**决策**：读取 `AssetDeployer` 已解压的 `files/lens_guard/config.yaml`，用有限键路径解析（`models.cls.enabled` / `models.det.enabled`），解析失败时 **保守默认**：`cls=false`, `det=true`（与引擎默认一致），并打 WARN 日志。

**理由**：与引擎默认对齐文档 §4、§7；不引入完整 YAML 依赖若项目尚无。

**备选**：要求 native 暴露 `nativeGetCapabilities` —— 留作 Open Question，首版不阻塞。

### 3. 离线推理：按能力开关而非编译期常量

**决策**：将 `AiVisionFragment.SKIP_OFFLINE_INFERENCE_FOR_UPLOAD` 改为运行时判断 `LensGuardManager.getCapabilities().isOfflineInferJsonAvailable()`（或等价方法）。探针可在引擎 start 后对临时 JPG 调用一次并缓存，避免每帧 `UnsatisfiedLinkError`。

**理由**：对齐 §2「版本号 ≠ 能力」；同一 APK 在不同 so 上行为正确。

**备选**：永远 `false` —— 在旧 so 设备上会阻断上传，需保留明确错误提示（见 spec）。

### 4. UI：三级 cls 展示

| Profile 状态 | `tvAiCls` / 分类区 |
|--------------|-------------------|
| `!classificationEnabled` | 「分类未启用」（新 string） |
| `classificationEnabled && !snapshot.valid` | 「等待分类…」（保留） |
| `valid` | 现有 className + score |

**`tvAiState`**：若 `!focusMonitoringExpected`，激光 ON 时 **不** 等待 `state==1`；可显示「污点检测」或保持 IDLE 文案，并注明非聚焦模式（产品文案待定）。

### 5. 保留 cls / MONITORING 代码路径

**决策**：不删除 `LensGuardStateEvent`、`publishLastClsSnapshot`、`setAiVisionPreviewClassificationEnabled`；仅在 profile 表明 cls 关闭时 **停止** 无意义的轮询或降低频率（若存在）。

**理由**：用户明确后续会重新开启 cls 及新模型。

### 6. JNI 与打包

- `NativeBridge` 声明与 lensinspector `NativeBridge.java` 保持同步（已具备 `nativeInferImageToJson`）。
- `make build` / Workers manifest 须指向含符号的 zip；发布前 `nm -D libai.so | grep nativeInferImageToJson`（文档 §8.1）。

### 7. 坐标与 JSON 契约

- 离线 `boxes` 为 **当前 JPG 像素**（中心 640 裁剪后全图坐标，见对齐文档 §1-C）。
- `status` 使用 `CLEAN` / `MILD` / `HEAVY`（非 `STAIN_*`）；`AiVisionFrameInference.fromNativeJson` 已按 `code==0` 处理，保持不变。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| bundled zip 版本新但 so 无离线符号 | Profile 运行时探针 + 上传前校验 MP4；日志指向更换 ai-library |
| config 与 so 能力不一致 | 以运行时 JNI + yaml 双源；不一致时 WARN，优先 yaml 控制 UI 期望 |
| cls 恢复后 UI 仍显示「未启用」 | `nativeCreate` 后重建 profile；工程师模式可提供「重启 Lens Guard」入口（可选，非本变更必须） |
| 探针调用增加启动耗时 | 单次临时图或 link-time 检测；仅 start 时执行 |

## Migration Plan

1. 合并 App 变更（profile + UI + 离线开关）。
2. 更新 Workers `ai-library` manifest 至含 `nativeInferImageToJson` 的 zip；`make build` 拉取。
3. 台架：按 `LENS_GUARD_APP_ALIGNMENT_2026-05-19.md` §8 六项验收。
4. 现场 OTA：更新 `files/bundled-libraries/ai-library/`；必要时清数据重导 bundled 库。
5. 回滚：App 上一版 + 恢复 `SKIP` 或旧 manifest；引擎 config 恢复 `cls.enabled: true` 需 destroy/create。

## Open Questions

- 是否在首版增加 `nativeGetEngineInfo` JSON（引擎能力上报），以减少 yaml 解析重复？
- 焊中聚焦 UI 在 det-only 下是 **隐藏** 还是 **置灰并说明**？（产品确认后补 string）
- 新检测模型接入时 capability 键名是否由引擎统一 schema 提供？（预留 `models.<name>.enabled` 解析扩展点）
