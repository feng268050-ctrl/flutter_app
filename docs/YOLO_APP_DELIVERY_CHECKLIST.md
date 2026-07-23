# YOLO 端交付物清单（面向 lws-ui）

**文档日期**：2026-05-22  
**引擎仓库**：lensinspector  
**App 仓库**：lws-ui（本文件）

> 本文只列 **需要 YOLO / 引擎侧提供** 的交付物。App 已实现的部分（推帧、overlay、离线时间轴、能力探测）见 [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md)、[`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../LENS_GUARD_APP_ALIGNMENT_2026-05-19.md)。

---

## 先看结论（三条）

| # | YOLO 必须交付 | 否则 App 现象 |
|---|----------------|---------------|
| **1** | **新 `libai.so` 三件套** + 内嵌 **`det_raw_head`**（700 ROI→640 后处理） | 框偏移/无框/推理行为与训练不一致 |
| **2** | 配套 **`config.yaml`**（`logits`、mask **885/430**、阈值 0.65/0.55） | 等级/灵敏度与文档不符 |
| **3** | **`nativeInferImageToJson`** 符号（离线 AI Vision） | 离线分析跳过、上传「推理视频尚未准备好」 |

**版本号 ≠ 能力**：`libai_v1.1.8-beta` 等旧 zip **不能**假设已含离线 JNI 或 700 ROI 逻辑；以设备上 `nm -D libai.so` 为准。

---

## P0 — 必交（阻塞联调 / 上线）

### 1. Native 安装包（ai-library zip）

| 项 | 要求 |
|----|------|
| **产物名** | `libai_<version>.zip`（或 Workers manifest 指向的等价包） |
| **目录结构** | `jniLibs/arm64-v8a/libai.so` + `libc++_shared.so` + `librknnrt.so` + `config.yaml`（或 zip 内 `assets/config.yaml`，由 App 解压到 `files/lens_guard/`） |
| **三件套同包** | `libai.so`、`librknnrt.so`、`libc++_shared.so` **必须同一构建矩阵**；`librknnrt` 须与设备 **BSP NPU 驱动** 匹配 |
| **模型** | 内嵌 **`det_raw_head.rknn`**（raw P2/P3/P4，`stain_score_mode: logits`） |
| **几何** | 污点 det：**700×700 ROI @(565,110)** → resize **640×640**；回调框为 **全图 xyxy**（非 App 再换算） |
| **发布说明** | 标明构建号、与旧「中心裁 640」包的差异、推荐 App 最低版本 |

**禁止**只交 `libai.so` 不交 `config.yaml`，或混用不同版本的 `librknnrt` 与 `libai.so`。

### 2. `config.yaml`（与 zip 同步）

产线默认值须与引擎仓库 [`config.yaml`](../../lensinspector/config.yaml) 一致（2026-05-22）：

| 键 | 产线值 | 说明 |
|----|--------|------|
| `models.cls.enabled` | `false` | det-only；激光 ON **无** `MONITORING(1)` |
| `models.det.enabled` | `true` | |
| `algorithm.stain_score_mode` | **`logits`** | raw head **必填**；`probabilities` 仅旧 decoded 模型 |
| `algorithm.stain_conf_thresh` | **0.65** | 训练对比可用 0.25 |
| `algorithm.stain_nms_thresh` | **0.55** | 训练对比可用 0.35 |
| `algorithm.stain_max_det` | **100** | 回调/JSON 最大框数（0=不截断） |
| `stain_detection.mask_center_x` | **885** | @1920×1080，**非**画面中心 |
| `stain_detection.mask_center_y` | **430** | |
| `stain_detection.mask_radius_px` | **280** | 圆内→L2 候选，圆外→L1 |
| `stain_detection.mask_ref_width` | **1920** | 其它分辨率同比缩放 mask |
| `stain_detection.mask_ref_height` | **1080** | |

修改 yaml 后须 **`nativeDestroy` → `nativeCreate`**（App OTA 解压后同样需重启会话）。

### 3. JNI 符号（须在 `libai.so` 导出）

**阻塞离线 / 上传（P0）**

```bash
nm -D libai.so | grep nativeInferImageToJson
# 必须有输出
```

| JNI | App 用途 |
|-----|----------|
| **`nativeInferImageToJson`** | AI Vision 离线：每 ~500ms 抽帧 JPG → JSON 时间轴 → 推理 MP4 上传 |

**实时污点 + 预览（P0，与历史包一致）**

| JNI | App 用途 |
|-----|----------|
| `nativeCreate` / `nativeStart` / `nativeStop` / `nativeDestroy` | 引擎生命周期 |
| `nativePushFrame` | I420 全帧推流 |
| `nativeSetLaserOn` | 激光状态 |
| `nativeSetListener` → `onCheckResult` | 生产污点 + 等级 |
| `nativeGetState` / `nativeGetStainLevel` / `nativeIsLensDirty` | 状态查询 |

**AI Vision 预览（P0，新 so 须含符号）**

| JNI | App 用途 |
|-----|----------|
| `nativeSetAiVisionPreviewDetectionEnabled` | Tab 内 `preview_det` + 全图框 |
| `nativeSetAiVisionPreviewClassificationEnabled` | 预览分类缓存（det-only 下可开但常 `valid:false`） |
| `nativeGetLastClsResult` | 只读分类 JSON |

**诊断单图（P0）**

| JNI | App 用途 |
|-----|----------|
| `nativeInferImageAndSave` | 工程师/台架单图写标注 JPG |

> **`Engine started` + 实时 `nativePushFrame` 不能证明离线 JNI 已交付。**

### 4. 发布与分发通道

| 项 | 负责方 | 说明 |
|----|--------|------|
| **Workers `ai-library` manifest** | YOLO + 发布 | `staging.json` / `release.json` 中 `url`、`filename`、`version` 指向 **含上述能力的 zip** |
| **构建脚本产出** | lensinspector | `build_android.sh` / `release_local.sh` 等，附 changelog |
| **真机验收报告**（建议） | YOLO | 至少：`nm` 三项 JNI、1920×1080 overlay、离线 MP4 一条链路 |

---

## P1 — 强烈建议（不阻塞推流，影响体验/性能）

### 1. `nativeInferVideoAndSave`

```bash
nm -D libai.so | grep nativeInferVideoAndSave
```

| 项 | 说明 |
|----|------|
| **作用** | native 一次读完视频并写出带框 MP4 |
| **无符号时** | App **已 fallback**：逐帧 `nativeInferImageToJson` + App 侧 `MediaCodec` 合成 MP4（功能可通，更慢） |
| **已知风险** | 部分构建曾返回 code=-2/-4；交付时需注明修复状态 |
| **完善说明** | [`NATIVE_INFER_VIDEO_AND_SAVE_IMPROVEMENT.md`](NATIVE_INFER_VIDEO_AND_SAVE_IMPROVEMENT.md)（fourcc 回退、500ms 推理、全帧写出） |

### 2. `nativeInferRgbToJson`（引擎已可提供，App 尚未接 JNI）

| 项 | 说明 |
|----|------|
| **作用** | 离线推理直接用 RGBA buffer，免写临时 JPG |
| **当前 App** | 仍走 `inferJpgToJson` + 磁盘 JPG；**非阻塞** |
| **建议** | YOLO 可在 release note 中标注「已导出，App 下一版可切换」 |

### 3. 预览 det 的 `preview_det` JSON 约定

| 字段 | 要求 |
|------|------|
| `message` 含 `"source":"preview_det"` | App 识别预览路径 |
| `boxes[]` | **当前推流分辨率**全图像素；`classId=0` 建议 `label` 为 `contamination` 或 App 显示 `cls=cont` |
| 脏污等级 | 仍由 native mask+窗口 计算；App **不重算** |

---

## P2 — 可选 / 非 App 门禁（勿当作 lws-ui 缺交付）

以下在引擎文档或历史方案中出现，**lws-ui 当前不要求 YOLO 为 App 单独交付**：

| 项 | 说明 |
|----|------|
| `nativeSetDeviceContext` / `nativePushCameraParams` / `nativePushFrameMeta` / `nativeNotifyModelSwitched` | 异常辅助/追溯；引擎有 JNI，**App 未声明** |
| `clean_ref` / `clean_candidate` / `hardcase` 目录规范 | 引擎可写；App **不维护** |
| 异常辅助 `anomaly_assist` 全量联调 | 文档已收敛，非发布门禁 |
| 性能基准包 `frames/*.i420bin` | 明确 **Not Supported** |
| **cls 聚焦模型启用** | 需 `models.cls.enabled: true` + 重启会话；默认 **det-only 不交 MONITORING 行为** |

---

## 行为交付（写在 release note，不是单独 zip）

YOLO 须在说明中写清，便于 App 台架验收：

| 行为 | 约定 |
|------|------|
| **推流** | App 推 **全帧 I420**；产线 **1920×1080**；宽×高建议 **≥1265×810**（覆盖 ROI） |
| **预处理** | **禁止**要求 App 做 letterbox/中心裁 640；均在 native |
| **框坐标** | `onCheckResult` / `preview_det` / 离线 JSON 的 `boxes` = **该帧或该 JPG 的全图像素** |
| **Mask** | 圆心 **(885,430)**，r=**280**；logcat 应有 `Stain mask center (...)` |
| **det-only** | 激光 ON 无 `onStateChanged(1)`；`getLastClsResult` 长期 `valid:false` 为预期 |
| **离线 JSON** | 仅 `code==0` 成功；`boxes` 为 **JPG 像素** |

---

## 验收清单（YOLO 出厂前勾选）

复制给 YOLO 联调同学，**全部 P0 通过**再更新 Workers manifest：

- [ ] zip 内三件套版本一致，且与目标 RK3566 BSP 矩阵联编说明齐全  
- [ ] `nm -D libai.so | grep nativeInferImageToJson` **有输出**  
- [ ] `config.yaml` 含 `stain_score_mode: logits`、`mask_center_x/y: 885/430`、`mask_ref: 1920/1080`  
- [ ] 1920×1080 推流：`preview_det` / `onCheckResult` 框在**全图**对准污点（非整体偏移）  
- [ ] 圆心附近污点易 **level 2**，仅边缘污点多为 **level 1**（mask r=280）  
- [ ] 离线：对样例 MP4 跑通 `nativeInferImageToJson` 时间轴（或说明 `nativeInferVideoAndSave` 可用）  
- [ ] 冷启动 logcat 无 `UnsatisfiedLinkError: nativeInferImageToJson`  
- [ ] （可选）`nm ... nativeInferVideoAndSave`、`nativeSetAiVisionPreviewDetectionEnabled`  

---

## App 侧引用文档（给 YOLO 交叉阅读）

| 文档 | 位置 |
|------|------|
| 引擎简版（预处理/mask） | lensinspector [`docs/APP_ALIGNMENT_BRIEF.md`](../../lensinspector/docs/APP_ALIGNMENT_BRIEF.md) |
| 引擎变更总览 | lensinspector [`docs/LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../../lensinspector/docs/LENS_GUARD_APP_ALIGNMENT_2026-05-19.md) |
| App 对齐摘要 | [`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../LENS_GUARD_APP_ALIGNMENT_2026-05-19.md) |
| 离线 JNI 验收 | [`AI_VISION_LIBAI_JNI_ALIGNMENT.md`](../AI_VISION_LIBAI_JNI_ALIGNMENT.md) |
| 几何/推帧 | [`LENS_GUARD_ROI640_ALIGNMENT.md`](LENS_GUARD_ROI640_ALIGNMENT.md) |
| 离线问题归档 | [`AI_VISION_INFERENCE_TROUBLESHOOTING_ARCHIVE.md`](AI_VISION_INFERENCE_TROUBLESHOOTING_ARCHIVE.md) |

---

## 联络接口（建议）

| 事项 | 建议对接人 |
|------|------------|
| `libai_*` 构建与 changelog | lensinspector / YOLO 构建负责人 |
| Workers `ai-library` manifest 更新 | 发布 / DevOps |
| 台架 1920×1080 + 离线 MP4 | App + YOLO 联调 |
