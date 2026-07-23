# det-only 模式 — Android App 对接说明

本文说明 native 引擎（`libai.so`）在 **仅启用污点检测、关闭分类模型**（det-only）时，**lws-ui** 需要知晓的行为变化与建议改法。  
Native 实现与配置见 `lensinspector` 仓库变更 **`det-only-disable-cls`**；引擎侧总览见 [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) §10.0。

---

## 1. 背景

| 模型 | 配置键 | det-only 默认 | App 侧用途 |
|------|--------|---------------|------------|
| 分类（聚焦/材料） | `models.cls.enabled` | **false** | `nativeGetLastClsResult`、激光 ON 聚焦状态机 |
| 污点检测 | `models.det.enabled` | **true** | `onCheckResult`、preview det、离线 `inferJpgToJson` |

det-only 下 native **不加载、不推理** cls RKNN，但 **JNI 方法签名不变**，旧 App 仍可运行；若 UI/逻辑依赖「焊中 MONITORING」或「有效分类」，需按本文适配。

---

## 2. 交付与配置（必做）

### 2.1 同步 `config.yaml`

引擎从 App 传入的 **`configPath`**（`files/lens_guard/config.yaml`）读取开关。合并 `lens_guard_engine_*.zip` 或从 `lensinspector/config.yaml` 拷贝时，须包含：

```yaml
models:
  cls:
    enabled: false
  det:
    enabled: true
```

- 路径：`app/src/main/assets/config.yaml`（随 `AssetDeployer` 首次部署到 `files/lens_guard/`）。
- **修改 config 后须重启 native 会话**：`LensGuardManager.stop()` → `start()`（或进程重启），无热重载。
- 若设备上已存在旧版 `config.yaml` 且无 `models` 段：解析逻辑默认 **cls=false、det=true**（与 det-only 一致）；仍建议在 assets 中显式写入，避免歧义。

### 2.2 升级 `libai.so`

与往常一样替换 `jniLibs/arm64-v8a/libai.so`（及匹配的 `librknnrt.so`）。**无需**改 `NativeBridge` 方法签名。

启动后可在 logcat 过滤 `LensGuard` / `LensGuardModel` 确认：

```text
[VER] models.cls.enabled=0 models.det.enabled=1
cls model slot disabled (models.cls.enabled=false)
```

---

## 3. Native 行为变化（App 必读）

### 3.1 不变（无需改代码即可继续工作）

| 能力 | 接口 / 事件 | 说明 |
|------|-------------|------|
| 推帧 | `nativePushFrame` / `LensGuardManager.onBitmapFrame` | 不变 |
| 激光 | `nativeSetLaserOn`（真实激光） | 不变 |
| 污点结果 | `onCheckResult` → `LensCheckResultEvent` | 周期/焊后/预览 det 仍推送 |
| 预览污点 | `setAiVisionPreviewDetectionEnabled(true)` | `message` 含 `"source":"preview_det"` |
| 离线时间轴 | `inferFromI420`（抽帧→I420）；磁盘 JPG 仍可用 `inferFromJpg` | 仍走 det + 污点后处理 |
| 脏污等级 / LOCKED | `nativeGetStainLevel`、`nativeIsLensDirty`、`state==2` | Level2 安全门控保留 |
| 预览过滤 | `LensGuardManager.isPreviewDetMessage` | 生产告警应继续忽略 preview JSON |

### 3.2 BREAKING：激光 ON 时不再进入 MONITORING

| 以前（cls 开启） | det-only |
|------------------|----------|
| 激光 ON → `onStateChanged(1)`（MONITORING） | 激光 ON → **通常保持** `onStateChanged(0)`（IDLE） |
| 焊中跑 `infer_focus_prob` + 聚焦状态机 | **不跑** cls，**不跑** AF 后处理 |

**影响示例**（当前工程）：

- `AiVisionFragment#onLensGuardStateChanged`：`state == 1` 时显示「监控中」——焊中实况 **可能不再出现** 该文案（除非因 LOCKED 等其它原因）。
- 任何依赖 `LensGuardStateEvent` 且假定「激光 ON ⇒ state==1」的界面或联锁，需改为不依赖 MONITORING，或等产品重新定义焊中 AI 状态。

`state == 2`（LOCKED，重度脏污阻断）**仍会**在 native 判定 Level2 时出现，与 cls 无关。

### 3.3 分类 JNI：长期 `valid:false`

| 接口 | det-only 行为 |
|------|----------------|
| `nativeGetLastClsResult` | 合法 JSON，`"valid":false`，`"source":"focus_cls"` |
| `nativeSetAiVisionPreviewClassificationEnabled(true)` | 可调用，**不触发** cls 推理 |

`LensGuardManager#publishLastClsSnapshot` / 推帧后节流拉取仍会执行，但 `LensClsSnapshotEvent#isValid()` 恒为 false。

**当前 UI**（`AiVisionFragment#onLensClsSnapshot`）会走：

```java
binding.tvAiCls.setText(R.string.ai_overlay_cls_waiting);  // 「分类：等待中…」
```

在 det-only 下该文案 **易误导**（并非「未推流」，而是「分类未启用」）——见 §4.2 建议修改。

### 3.4 Legacy「假激光 ON」预览分类

`LensGuardManager` 在 **旧 so 无** `nativeSetAiVisionPreviewClassificationEnabled` 时，会用 `effectiveLaserOn = actualLaserOn || legacyPreviewCls` 骗 native 进焊中路径。

**新 lib + det-only**：preview cls 开关仍存在，但 native 不推理；**不应再依赖** legacy 假激光 ON 驱动分类。保持 `nativeSetLaserOn` 反映 **真实** `DeviceStatus.isLaserOn()` 即可。

---

## 4. 建议 App 修改（按优先级）

### 4.1 必做：认知与配置

1. 合并带 `models` 段的 `config.yaml`（§2.1）。
2. 发布说明中注明：**焊中自动聚焦/材料分类暂不可用**；污点检测与 AI Vision 预览 det **可用**。
3. QA 用例去掉「激光 ON 必收到 state=1」的断言。

### 4.2 强烈建议：分类 UI 文案

在 `AiVisionFragment`（或统一 cls 展示处）区分「等待首次推理」与「分类已关闭」：

| 条件 | 建议展示 |
|------|----------|
| det-only / `valid:false` 且引擎配置 cls 关闭 | 「分类：未启用（仅检测模式）」等新 string |
| cls 开启但尚未推流 | 保留 `ai_overlay_cls_waiting` |

实现方式任选其一：

- 读取部署后的 `config.yaml` 中 `models.cls.enabled`（解析一次缓存）；或
- 约定：连续 N 次 `valid:false` 且 `timestampMs==0` 且 preview cls 已开 → 显示「未启用」；或
- 产品直接 **隐藏** `tvAiCls` / 分类行（det-only 版本最简单）。

涉及文件示例：

- `app/src/main/java/.../AiVisionFragment.java` — `onLensClsSnapshot`
- `app/src/main/res/values/strings.xml`、`values-zh/strings.xml` — 新增文案

### 4.3 可选：减少无效调用

| 项 | 说明 |
|----|------|
| 进入 AI Vision 仍调 `setAiVisionPreviewClassificationEnabled(true)` | 无害，可保留以便将来开 cls；也可改为 `false` 减少误导 |
| `publishLastClsSnapshotIfDue` 每帧拉取 | cls 关闭时可降频或跳过，减轻 JNI 与 EventBus 开销 |
| 隐藏「AI 状态：监控中」依赖 | 焊中 overlay 可固定为 Idle 或改为「检测运行中」等与 det 对齐的文案 |

### 4.4 不必改（除非有专项需求）

- `NativeBridge` / `guarded*` 签名
- `LensCheckResultEvent`、`LensDirtyAlertDialogCoordinator`（注意继续用 `isPreviewDetMessage` 过滤）
- `inferFromI420` 离线/工艺录像时间轴主流程（无临时 JPEG）
- `LensHeavyContaminationAlarmController` 对 preview det 的过滤逻辑

---

## 5. 代码索引

| 模块 | 路径 |
|------|------|
| JNI 封装 | `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java` |
| 引擎生命周期 / EventBus | `app/src/main/java/com/lasercyber/lws/ai/LensGuardManager.java` |
| config 部署 | `app/src/main/java/com/lasercyber/lws/ai/AssetDeployer.java` |
| AI Vision UI | `app/src/main/java/.../AiVisionFragment.java` |
| 分类事件 DTO | `app/src/main/java/.../LensClsSnapshotEvent.java` |
| 状态事件 | `app/src/main/java/.../LensGuardStateEvent.java` |
| 生产脏污告警 | `app/src/main/java/.../LensHeavyContaminationAlarmController.java` |
|  bundled 配置 | `app/src/main/assets/config.yaml` |

---

## 6. 联调与验收清单

在真机安装 **det-only** `libai.so` + 新 `config.yaml` 后：

| # | 步骤 | 预期 |
|---|------|------|
| 1 | 启动 App，打开引擎 | logcat：`models.cls.enabled=0` |
| 2 | 激光 OFF，等待周期检测 | `onCheckResult` 有污点文案；`isLensDirty` / level 合理 |
| 3 | AI Vision 开 preview det | `message` 含 `preview_det`，overlay 有框；**不**弹生产阻断脏污弹窗 |
| 4 | 拉取分类 | `guardedGetLastClsResult` → `valid:false` |
| 5 | 激光 ON 焊接（实况） | **无** `onStateChanged(1)`（除非 LOCKED）；污点中断逻辑仍可用 |
| 6 | Level2 脏污后激光 ON | 仍可 `onStateChanged(2)` LOCKED |
| 7 | 离线录像 `inferFromI420` | 时间轴 `success` 与 boxes 正常 |

---

## 7. 恢复分类（cls）

1. 将 `config.yaml` 中 `models.cls.enabled` 改为 `true`（或换回 cls 开启的引擎默认包）。
2. 重启 `LensGuardManager` native 会话。
3. 验证：激光 ON 时出现 `onStateChanged(1)`；`getLastClsResult` 在推流后出现 `valid:true`。

---

## 8. 相关文档

| 文档 | 位置 |
|------|------|
| Lens Guard App 总览 | [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) |
| AI Vision 离线 JSON 契约 | `lensinspector/AI_VISION_NATIVE_OFFLINE_INFERENCE_CONTRACT.md` |
| Native det-only 设计 | `lensinspector/openspec/changes/det-only-disable-cls/design.md` |

---

**文档版本**：与 native `det-only-disable-cls` 实现同步；若引擎默认开关变更，以 `lensinspector/config.yaml` 为准。
